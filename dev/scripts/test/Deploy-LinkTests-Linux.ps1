<#
.SYNOPSIS
    Deploys the local-file-normalization test files for manual link-click testing on Linux.

.DESCRIPTION
    Copies markdown test files to ~/markview-test/:
      - repo/subdir/          (manual-test.md + spec1)
      - repo/docs/            (spec3)
      - /                     (spec5, spec7)
      - My Docs/              (spec6, spec8, spec9)

    The Windows version tests both backslash and forward-slash variants of
    relative/parent paths (spec1 vs spec2, spec3 vs spec4). On Linux, backslash
    is not a path separator, so only the forward-slash variants are deployed.

    After deployment, open ~/markview-test/repo/subdir/manual-test.md with
    MarkView and click each link to verify local-file normalization works correctly.

    Uses $HOME rather than /tmp because snap strict confinement restricts
    file access to the user's home directory.

    Irrelevant Windows-only test cases are omitted:
      - Windows absolute paths (C:\, C:/)
      - UNC paths (\\server, \\localhost)
      - UNC-like forward-slash paths (//server)
      - file:// UNC-form URLs (file://server/share)

.PARAMETER Clean
    Remove all previously deployed test files instead of deploying.

.EXAMPLE
    # Deploy test files
    ./dev/scripts/test/Deploy-LinkTests-Linux.ps1

.EXAMPLE
    # Clean up deployed files
    ./dev/scripts/test/Deploy-LinkTests-Linux.ps1 -Clean
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch] $Clean
)

$ErrorActionPreference = 'Stop'

$DeployDir = Join-Path $HOME 'markview-test'

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$WinSourceDir  = Join-Path $RepoRoot 'tests/local-file-normalization'
$LinuxSourceDir = Join-Path $RepoRoot 'tests/local-file-normalization-linux'

# Validate sources exist
if (-not (Test-Path $WinSourceDir)) {
    throw "Source directory not found: $WinSourceDir"
}
if (-not (Test-Path $LinuxSourceDir)) {
    throw "Source directory not found: $LinuxSourceDir"
}

# --- Define deployment mappings ---
# Relative/parent-traversal specs reuse cross-platform sources from tests/local-file-normalization/
# Absolute/file-URL specs use Linux-specific sources from tests/local-file-normalization-linux/
# Template = $true means the file contains placeholder paths that need replacement
$mappings = @(
    # manual test page (Linux-specific, needs path templating)
    @{ Src = "$LinuxSourceDir/manual-test.md";        Dst = "$DeployDir/repo/subdir/manual-test.md"; Template = $true }
    # relative path — forward-slash only (backslash is not a path separator on Linux)
    @{ Src = "$WinSourceDir/repo/subdir/docs/spec1.md"; Dst = "$DeployDir/repo/subdir/docs/spec1.md" }
    # parent traversal — forward-slash only
    @{ Src = "$WinSourceDir/repo/docs/spec3.md";       Dst = "$DeployDir/repo/docs/spec3.md" }
    # Linux absolute paths (Linux-specific specs, need path templating)
    @{ Src = "$LinuxSourceDir/spec5.md";               Dst = "$DeployDir/spec5.md";           Template = $true }
    @{ Src = "$LinuxSourceDir/spec6.md";               Dst = "$DeployDir/My Docs/spec6.md";   Template = $true }
    # file:/// URLs (Linux-specific specs, need path templating)
    @{ Src = "$LinuxSourceDir/spec7.md";               Dst = "$DeployDir/spec7.md";           Template = $true }
    @{ Src = "$LinuxSourceDir/spec8.md";               Dst = "$DeployDir/My Docs/spec8.md";   Template = $true }
    @{ Src = "$LinuxSourceDir/spec9.md";               Dst = "$DeployDir/My Docs/spec9.md";   Template = $true }
)

# Source files use a placeholder path that gets replaced with the real $DeployDir
# at deploy time, since $HOME varies per user.
$Placeholder = '/tmp/markview-test'

function Deploy-File([string]$Source, [string]$Destination, [switch]$Template) {
    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    try {
        if ($Template) {
            # Replace placeholder paths with actual deploy directory
            $content = Get-Content -LiteralPath $Source -Raw
            $content = $content.Replace($Placeholder, $DeployDir)
            Set-Content -LiteralPath $Destination -Value $content -NoNewline
        } else {
            Copy-Item -LiteralPath $Source -Destination $Destination -Force
        }
        Write-Host "  Deployed: $Destination" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  FAILED:   $Destination  ($($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

function Remove-DeployedFile([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        try {
            Remove-Item -LiteralPath $Path -Force
            Write-Host "  Removed: $Path" -ForegroundColor Yellow
        } catch {
            Write-Host "  FAILED to remove: $Path  ($($_.Exception.Message))" -ForegroundColor Red
            $script:cleanFailed = $true
        }
    }
}

# --- CLEAN MODE ---
if ($Clean) {
    Write-Host "Cleaning deployed test files..." -ForegroundColor Cyan
    $script:cleanFailed = $false

    foreach ($m in $mappings) {
        Remove-DeployedFile $m.Dst
    }

    # Clean up empty directories (deepest first)
    $dirsToClean = @(
        "$DeployDir/repo/subdir/docs"
        "$DeployDir/repo/subdir"
        "$DeployDir/repo/docs"
        "$DeployDir/repo"
        "$DeployDir/My Docs"
        "$DeployDir"
    )
    foreach ($dir in $dirsToClean) {
        if ((Test-Path $dir) -and @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $dir -Force
            Write-Host "  Removed empty dir: $dir" -ForegroundColor Yellow
        }
    }

    if ($script:cleanFailed) {
        Write-Host ""
        Write-Host "Some files could not be removed." -ForegroundColor Yellow
    }
    Write-Host "Clean complete." -ForegroundColor Cyan
    return
}

# --- DEPLOY MODE ---
Write-Host "Deploying local-file-normalization test files (Linux)..." -ForegroundColor Cyan
Write-Host ""

$deployCount = 0
$failCount = 0
foreach ($m in $mappings) {
    if (-not (Test-Path -LiteralPath $m.Src)) {
        Write-Warning "Source file missing: $($m.Src)"
        continue
    }
    $useTemplate = [bool]$m.Template
    if (Deploy-File -Source $m.Src -Destination $m.Dst -Template:$useTemplate) {
        $deployCount++
    } else {
        $failCount++
    }
}
Write-Host ""
Write-Host "  $deployCount deployed, $failCount failed." -ForegroundColor Gray

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Deployment complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open $DeployDir/repo/subdir/manual-test.md with MarkView" -ForegroundColor Gray
Write-Host "  2. Click each link in the test table" -ForegroundColor Gray
Write-Host "  3. Verify the correct spec file opens" -ForegroundColor Gray
Write-Host "  4. Verify fragment links scroll to the right section" -ForegroundColor Gray
Write-Host ""
Write-Host "To open with MarkView:" -ForegroundColor White
Write-Host "  pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path `"$DeployDir/repo/subdir/manual-test.md`"" -ForegroundColor Gray
Write-Host ""
Write-Host "To clean up:" -ForegroundColor White
Write-Host "  ./dev/scripts/test/Deploy-LinkTests-Linux.ps1 -Clean" -ForegroundColor Gray
