<#
.SYNOPSIS
    Deploys the local-file-normalization test files for manual link-click testing.

.DESCRIPTION
    Copies markdown test files from tests\local-file-normalization to:
      - C:\repo\           (manual-test.md + spec1-4)
      - C:\                (spec5, spec7, spec11, spec15)
      - C:\My Docs\        (spec6, spec8, spec12, spec16, spec17)
      - \\<Share>\         (spec9, spec13, spec18)        [if -UncShare provided]
      - \\<Share>\My Docs\ (spec10, spec14, spec19, spec20) [if -UncShare provided]

    After deployment, open C:\repo\subdir\manual-test.md with MarkView and click
    each link to verify local-file normalization works correctly.

.PARAMETER UncShare
    Optional UNC path to a writable network share (e.g. \\server\share).
    If omitted, UNC test cases (9-10, 13-14, 18-20) are skipped.

.PARAMETER Clean
    Remove all previously deployed test files instead of deploying.

.EXAMPLE
    # Deploy local files only (skip UNC tests)
    .\dev\scripts\test\Deploy-LinkTests.ps1

.EXAMPLE
    # Deploy all files including UNC share
    .\dev\scripts\test\Deploy-LinkTests.ps1 -UncShare '\\myserver\testshare'

.EXAMPLE
    # Clean up deployed files
    .\dev\scripts\test\Deploy-LinkTests.ps1 -Clean

.EXAMPLE
    # Clean UNC files too
    .\dev\scripts\test\Deploy-LinkTests.ps1 -Clean -UncShare '\\myserver\testshare'
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string] $UncShare,
    [switch] $Clean
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$SourceDir = Join-Path $RepoRoot 'tests\local-file-normalization'

# Validate source exists
if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

# Normalize UNC share path (remove trailing backslash)
if ($UncShare) {
    $UncShare = $UncShare.TrimEnd('\', '/')
}

# --- Define deployment mappings ---
# Each entry: Source (relative to $SourceDir) -> Destination
$localMappings = @(
    # repo tree
    @{ Src = 'repo\subdir\manual-test.md';     Dst = 'C:\repo\subdir\manual-test.md' }
    @{ Src = 'repo\subdir\docs\spec1.md';      Dst = 'C:\repo\subdir\docs\spec1.md' }
    @{ Src = 'repo\subdir\docs\spec2.md';      Dst = 'C:\repo\subdir\docs\spec2.md' }
    @{ Src = 'repo\docs\spec3.md';             Dst = 'C:\repo\docs\spec3.md' }
    @{ Src = 'repo\docs\spec4.md';             Dst = 'C:\repo\docs\spec4.md' }
    # C:\ root
    @{ Src = 'root-specs\spec5.md';            Dst = 'C:\spec5.md' }
    @{ Src = 'root-specs\spec7.md';            Dst = 'C:\spec7.md' }
    @{ Src = 'root-specs\spec11.md';           Dst = 'C:\spec11.md' }
    @{ Src = 'root-specs\spec15.md';           Dst = 'C:\spec15.md' }
    # C:\My Docs
    @{ Src = 'root-specs\My Docs\spec6.md';    Dst = 'C:\My Docs\spec6.md' }
    @{ Src = 'root-specs\My Docs\spec8.md';    Dst = 'C:\My Docs\spec8.md' }
    @{ Src = 'root-specs\My Docs\spec12.md';   Dst = 'C:\My Docs\spec12.md' }
    @{ Src = 'root-specs\My Docs\spec16.md';   Dst = 'C:\My Docs\spec16.md' }
    @{ Src = 'root-specs\My Docs\spec17.md';   Dst = 'C:\My Docs\spec17.md' }
)

# UNC mappings use $UncShare as the base
$uncMappings = @(
    @{ Src = 'share-specs\spec9.md';               RelDst = 'spec9.md' }
    @{ Src = 'share-specs\spec13.md';              RelDst = 'spec13.md' }
    @{ Src = 'share-specs\spec18.md';              RelDst = 'spec18.md' }
    @{ Src = 'share-specs\My Docs\spec10.md';      RelDst = 'My Docs\spec10.md' }
    @{ Src = 'share-specs\My Docs\spec14.md';      RelDst = 'My Docs\spec14.md' }
    @{ Src = 'share-specs\My Docs\spec19.md';      RelDst = 'My Docs\spec19.md' }
    @{ Src = 'share-specs\My Docs\spec20.md';      RelDst = 'My Docs\spec20.md' }
)

function Deploy-File([string]$Source, [string]$Destination) {
    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    try {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
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

function Remove-EmptyParents([string]$Path) {
    # Walk up and remove empty directories (stop at drive root or UNC root)
    $dir = Split-Path -Parent $Path
    while ($dir -and (Test-Path $dir)) {
        $children = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        if ($children.Count -eq 0) {
            Remove-Item -LiteralPath $dir -Force
            Write-Host "  Removed empty dir: $dir" -ForegroundColor Yellow
            $dir = Split-Path -Parent $dir
        } else {
            break
        }
    }
}

# --- CLEAN MODE ---
if ($Clean) {
    Write-Host "Cleaning deployed test files..." -ForegroundColor Cyan
    $script:cleanFailed = $false

    # Remove local files
    foreach ($m in $localMappings) {
        Remove-DeployedFile $m.Dst
    }

    # Remove UNC files
    if ($UncShare) {
        foreach ($m in $uncMappings) {
            Remove-DeployedFile (Join-Path $UncShare $m.RelDst)
        }
    }

    # Clean up empty directories (in reverse specificity order)
    foreach ($dir in @('C:\repo\subdir\docs', 'C:\repo\subdir', 'C:\repo\docs', 'C:\repo', 'C:\My Docs')) {
        if ((Test-Path $dir) -and @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $dir -Force
            Write-Host "  Removed empty dir: $dir" -ForegroundColor Yellow
        }
    }
    if ($UncShare) {
        $uncMyDocs = Join-Path $UncShare 'My Docs'
        if ((Test-Path $uncMyDocs) -and @(Get-ChildItem -LiteralPath $uncMyDocs -Force -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item -LiteralPath $uncMyDocs -Force
            Write-Host "  Removed empty dir: $uncMyDocs" -ForegroundColor Yellow
        }
    }

    if ($script:cleanFailed) {
        Write-Host ""
        Write-Host "Some files could not be removed. Run from an elevated PowerShell." -ForegroundColor Yellow
    }
    Write-Host "Clean complete." -ForegroundColor Cyan
    return
}

# --- DEPLOY MODE ---
Write-Host "Deploying local-file-normalization test files..." -ForegroundColor Cyan
Write-Host ""

# Deploy local files
Write-Host "Local files:" -ForegroundColor White
$localCount = 0
$failCount = 0
foreach ($m in $localMappings) {
    $src = Join-Path $SourceDir $m.Src
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "Source file missing: $src"
        continue
    }
    if (Deploy-File -Source $src -Destination $m.Dst) {
        $localCount++
    } else {
        $failCount++
    }
}
Write-Host "  $localCount deployed, $failCount failed." -ForegroundColor Gray

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "  Some files could not be deployed (access denied)." -ForegroundColor Yellow
    Write-Host "  Run from an elevated (Administrator) PowerShell to deploy to C:\ root." -ForegroundColor Yellow
}
Write-Host ""

# Deploy UNC files
if ($UncShare) {
    Write-Host "UNC share ($UncShare):" -ForegroundColor White
    if (-not (Test-Path $UncShare)) {
        Write-Warning "UNC share not accessible: $UncShare"
        Write-Warning "Skipping UNC test files."
    } else {
        $uncCount = 0
        $uncFail = 0
        foreach ($m in $uncMappings) {
            $src = Join-Path $SourceDir $m.Src
            $dst = Join-Path $UncShare $m.RelDst
            if (-not (Test-Path -LiteralPath $src)) {
                Write-Warning "Source file missing: $src"
                continue
            }
            if (Deploy-File -Source $src -Destination $dst) {
                $uncCount++
            } else {
                $uncFail++
            }
        }
        Write-Host "  $uncCount deployed, $uncFail failed." -ForegroundColor Gray
    }
} else {
    Write-Host "UNC share: SKIPPED (use -UncShare to deploy)" -ForegroundColor Yellow
    Write-Host "  Test cases 9-10, 13-14, 18-20 require a network share." -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Deployment complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open C:\repo\subdir\manual-test.md with MarkView" -ForegroundColor Gray
Write-Host "  2. Click each link in the test table" -ForegroundColor Gray
Write-Host "  3. Verify the correct spec file opens" -ForegroundColor Gray
Write-Host "  4. Verify fragment links scroll to the right section" -ForegroundColor Gray
Write-Host ""
Write-Host "To open with MarkView:" -ForegroundColor White
Write-Host '  pwsh -NoProfile -File "src\core\Open-Markdown.ps1" -Path "C:\repo\subdir\manual-test.md"' -ForegroundColor Gray
Write-Host ""
Write-Host "To clean up:" -ForegroundColor White
if ($UncShare) {
    Write-Host "  .\dev\scripts\test\Deploy-LinkTests.ps1 -Clean -UncShare '$UncShare'" -ForegroundColor Gray
} else {
    Write-Host "  .\dev\scripts\test\Deploy-LinkTests.ps1 -Clean" -ForegroundColor Gray
}
