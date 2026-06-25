<#
.SYNOPSIS
    Checks that the MarkView version number is consistent across all files.

.DESCRIPTION
    Reads the canonical version from src\host\MarkdownViewerHost\MarkdownViewerHost.csproj
    (<Version> element) and verifies every other file that embeds the version matches.

    Exits with code 0 if all versions are consistent, 1 if mismatches are found.

    Run this script as part of the build process or before releasing.

.PARAMETER Fix
    Automatically update all files to match the canonical version in MarkdownViewerHost.csproj.

.EXAMPLE
    # Check consistency
    .\dev\scripts\Test-VersionConsistency.ps1

.EXAMPLE
    # Fix all files to match the canonical version
    .\dev\scripts\Test-VersionConsistency.ps1 -Fix
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch] $Fix
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# --- 1) Read canonical version from MarkdownViewerHost.csproj ---
$csprojPath = Join-Path $RepoRoot 'src\host\MarkdownViewerHost\MarkdownViewerHost.csproj'
if (-not (Test-Path $csprojPath)) {
    Write-Error "Canonical version source not found: $csprojPath"
}

[xml]$csproj = Get-Content $csprojPath -Raw
$canonicalVersion = $csproj.Project.PropertyGroup.Version  # e.g. "1.0.1"

if (-not $canonicalVersion -or $canonicalVersion -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Could not read valid 3-part version from <Version> in $csprojPath (got: '$canonicalVersion')"
}

# Derive the 4-part version (for MSIX, assembly, etc.)
$version4 = "$canonicalVersion.0"

Write-Host "Canonical version: $canonicalVersion ($version4)" -ForegroundColor Cyan
Write-Host ""

# --- 2) Define all version locations ---
# Each entry: file path (relative to repo root), a regex to extract the version,
# the expected value, and a replacement function for -Fix mode.

$checks = @(
    @{
        File     = 'src\host\MarkdownViewerHost\MarkdownViewerHost.csproj'
        Label    = 'csproj <FileVersion>'
        Pattern  = '<FileVersion>([\d\.]+)</FileVersion>'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace '<FileVersion>[\d\.]+</FileVersion>', "<FileVersion>$ver</FileVersion>" }
    }
    @{
        File     = 'src\host\MarkdownViewerHost\MarkdownViewerHost.csproj'
        Label    = 'csproj <AssemblyVersion>'
        Pattern  = '<AssemblyVersion>([\d\.]+)</AssemblyVersion>'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace '<AssemblyVersion>[\d\.]+</AssemblyVersion>', "<AssemblyVersion>$ver</AssemblyVersion>" }
    }
    @{
        File     = 'installers\win-msix\Package.appxmanifest'
        Label    = 'appxmanifest Identity Version'
        Pattern  = '<Identity[^>]*Version="([\d\.]+)"'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace '(<Identity[^>]*Version=")[\d\.]+(")', "`${1}$ver`$2" }
    }
    @{
        File     = 'installers\win-msix\MarkdownViewer.wapproj'
        Label    = 'wapproj <PackageVersion>'
        Pattern  = '<PackageVersion>([\d\.]+)</PackageVersion>'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace '<PackageVersion>[\d\.]+</PackageVersion>', "<PackageVersion>$ver</PackageVersion>" }
    }
    @{
        File     = 'installers\win-msix\build.ps1'
        Label    = 'build.ps1 -Version default'
        Pattern  = "\[string\]\`$Version\s*=\s*'([\d\.]+)'"
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace "(\[string\]\`$Version\s*=\s*')[^']+(')", "`${1}$ver`$2" }
    }
    @{
        File     = 'installers\linux-snap\snap\snapcraft.yaml'
        Label    = 'snapcraft.yaml version'
        Pattern  = "(?m)^version:\s*'([\d\.]+)'"
        Expected = $canonicalVersion
        Replace  = { param($content, $ver) $content -replace "(?m)^(version:\s*')[^']+(')", "`${1}$ver`$2" }
    }
    @{
        File     = 'tests\Test-PackagedActivation.ps1'
        Label    = 'Test-PackagedActivation -Version default'
        Pattern  = "\[string\]\`$Version\s*=\s*'([\d\.]+)'"
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace "(\[string\]\`$Version\s*=\s*')[^']+(')", "`${1}$ver`$2" }
    }
    @{
        File     = 'tests\Invoke-AllTests.ps1'
        Label    = 'Invoke-AllTests.ps1 MSIX path'
        Pattern  = 'MarkdownViewer_([\d\.]+)_x64\.msix'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace 'MarkdownViewer_[\d\.]+_x64\.msix', "MarkdownViewer_${ver}_x64.msix" }
    }
    @{
        File     = 'tests\MarkdownViewer.Tests.ps1'
        Label    = 'MarkdownViewer.Tests.ps1 MSIX path (x64)'
        Pattern  = 'MarkdownViewer_([\d\.]+)_x64\.msix'
        Expected = $version4
        Replace  = { param($content, $ver) $content -replace 'MarkdownViewer_[\d\.]+_(x64|ARM64)\.msix', "MarkdownViewer_${ver}_`$1.msix" }
    }
)

# --- 3) Check each location ---
$mismatches = @()
$passed = 0

foreach ($check in $checks) {
    $filePath = Join-Path $RepoRoot $check.File
    if (-not (Test-Path $filePath)) {
        Write-Host "  [SKIP] $($check.Label) - file not found: $($check.File)" -ForegroundColor Yellow
        continue
    }

    $content = Get-Content $filePath -Raw
    if ($content -match $check.Pattern) {
        $actual = $Matches[1]
        if ($actual -eq $check.Expected) {
            Write-Host "  [OK]   $($check.Label): $actual" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] $($check.Label): $actual (expected $($check.Expected))" -ForegroundColor Red
            $mismatches += @{
                Check   = $check
                Path    = $filePath
                Actual  = $actual
                Content = $content
            }
        }
    } else {
        Write-Host "  [WARN] $($check.Label) - pattern not found in $($check.File)" -ForegroundColor Yellow
    }
}

# --- 4) Summary ---
Write-Host ""
if ($mismatches.Count -eq 0) {
    Write-Host "All $passed version references are consistent." -ForegroundColor Green
    exit 0
}

Write-Host "$($mismatches.Count) mismatch(es) found." -ForegroundColor Red

# --- 5) Fix mode ---
if ($Fix) {
    Write-Host ""
    Write-Host "Fixing mismatches..." -ForegroundColor Cyan

    # Group by file path so we only write each file once
    $byFile = $mismatches | Group-Object -Property Path

    foreach ($group in $byFile) {
        $filePath = $group.Name
        $content = Get-Content $filePath -Raw

        foreach ($m in $group.Group) {
            $content = & $m.Check.Replace $content $m.Check.Expected
            Write-Host "  Fixed: $($m.Check.Label) -> $($m.Check.Expected)" -ForegroundColor Green
        }

        # Preserve original line ending style
        Set-Content -Path $filePath -Value $content -NoNewline
    }

    Write-Host ""
    Write-Host "All mismatches fixed. Run again to verify." -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "Run with -Fix to update all files automatically." -ForegroundColor Yellow
    exit 1
}
