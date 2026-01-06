<#
.SYNOPSIS
    Cleans all build outputs from the MarkdownViewer repository.

.DESCRIPTION
    Removes build artifacts from all projects:
    - C# projects: bin/ and obj/ directories
    - MSIX packaging: output/, obj/, bin/, AppPackages/, BundleArtifacts/
    - VS solution: .vs/ directory

    Does NOT remove:
    - PowerShell bundle cache (%TEMP%\MarkdownViewer-BuildCache)
    - Source files, scripts, or configuration

.PARAMETER WhatIf
    Shows what would be deleted without actually deleting.

.PARAMETER IncludeVsCache
    Also removes the .vs/ solution cache directory (causes VS reload).

.EXAMPLE
    .\Clean-Build.ps1
    Cleans all build outputs.

.EXAMPLE
    .\Clean-Build.ps1 -WhatIf
    Shows what would be cleaned without deleting.

.EXAMPLE
    .\Clean-Build.ps1 -IncludeVsCache
    Cleans build outputs plus Visual Studio cache.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludeVsCache
)

$ErrorActionPreference = 'Stop'

# Find repository root (script is in dev/scripts/)
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "Cleaning build outputs from: $repoRoot" -ForegroundColor Cyan
Write-Host ""

# Define directories to clean (relative to repo root)
$dirsToClean = @(
    # C# Host project
    'src\host\MarkdownViewerHost\bin',
    'src\host\MarkdownViewerHost\obj',
    
    # C# xUnit tests
    'tests\MarkdownViewerHost.Tests\bin',
    'tests\MarkdownViewerHost.Tests\obj',
    
    # ActivationDriver (E2E test helper)
    'tests\ActivationDriver\bin',
    'tests\ActivationDriver\obj',
    
    # MSIX packaging (WAP project)
    'installers\win-msix\bin',
    'installers\win-msix\obj',
    'installers\win-msix\output',
    'installers\win-msix\AppPackages',
    'installers\win-msix\BundleArtifacts'
)

# Optionally include VS cache
if ($IncludeVsCache) {
    $dirsToClean += '.vs'
}

$cleaned = 0
$skipped = 0

foreach ($relPath in $dirsToClean) {
    $fullPath = Join-Path $repoRoot $relPath
    
    if (Test-Path -LiteralPath $fullPath) {
        if ($PSCmdlet.ShouldProcess($fullPath, "Remove directory")) {
            try {
                Remove-Item -LiteralPath $fullPath -Recurse -Force
                Write-Host "  Removed: $relPath" -ForegroundColor Green
                $cleaned++
            }
            catch {
                Write-Warning "  Failed to remove: $relPath - $_"
            }
        }
        else {
            Write-Host "  Would remove: $relPath" -ForegroundColor Yellow
            $cleaned++
        }
    }
    else {
        $skipped++
    }
}

Write-Host ""
if ($WhatIfPreference) {
    Write-Host "Would clean $cleaned directories ($skipped already clean)" -ForegroundColor Cyan
}
else {
    Write-Host "Cleaned $cleaned directories ($skipped already clean)" -ForegroundColor Cyan
}

# Note about pwsh cache
Write-Host ""
Write-Host "Note: PowerShell bundle cache is preserved at:" -ForegroundColor DarkGray
Write-Host "  $env:TEMP\MarkdownViewer-BuildCache" -ForegroundColor DarkGray
