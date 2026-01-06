# Invoke-AllTests.ps1 - Run all tests in the Markdown Viewer project
# This script runs both PowerShell (Pester) and C# (xUnit) tests in one command.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Minimal', 'Normal', 'Detailed')]
    [string]$Output = 'Minimal',
    
    [switch]$NoBuild,           # Skip building before running tests
    
    [switch]$SkipPester,        # Skip PowerShell tests
    
    [switch]$SkipDotnet,        # Skip C# tests
    
    [switch]$IncludeE2E         # Include E2E MSIX activation tests (interactive, requires user clicks)
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptRoot

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Markdown Viewer - Run All Tests" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
$results = @()

#region Build

if (-not $NoBuild) {
    Write-Host "[Build] Building solution..." -ForegroundColor Yellow
    Push-Location $RepoRoot
    try {
        $buildOutput = dotnet build MarkdownViewer.slnx -c Debug 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[Build] FAILED" -ForegroundColor Red
            $buildOutput | Where-Object { $_ -match 'error' } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            $allPassed = $false
            $results += [PSCustomObject]@{ Suite = 'Build'; Passed = 0; Failed = 1; Skipped = 0; Status = 'FAILED' }
        } else {
            Write-Host "[Build] OK" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
    Write-Host ""
}

#endregion

#region PowerShell Tests (Pester)

if (-not $SkipPester) {
    Write-Host "[Pester] Running PowerShell tests..." -ForegroundColor Yellow
    
    # Ensure Pester 5.x is loaded
    $pester = Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0.0' | Select-Object -First 1
    if (-not $pester) {
        Write-Host "[Pester] ERROR: Pester 5.x not installed. Run: Install-Module Pester -Force -SkipPublisherCheck" -ForegroundColor Red
        $allPassed = $false
        $results += [PSCustomObject]@{ Suite = 'Pester'; Passed = 0; Failed = 1; Skipped = 0; Status = 'ERROR' }
    } else {
        Import-Module Pester -RequiredVersion $pester.Version -Force
        
        $pesterConfig = [PesterConfiguration]::Default
        $pesterConfig.Run.Path = Join-Path $ScriptRoot '*'
        $pesterConfig.Run.Exit = $false
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = $Output
        # Exclude E2E test (interactive) and helper scripts
        $pesterConfig.Run.ExcludePath = @(
            (Join-Path $ScriptRoot 'Test-PackagedActivation.ps1'),
            (Join-Path $ScriptRoot 'Test-StagedPayload.ps1')
        )
        
        $pesterResult = Invoke-Pester -Configuration $pesterConfig
        
        $pesterPassed = $pesterResult.PassedCount
        $pesterFailed = $pesterResult.FailedCount
        $pesterSkipped = $pesterResult.SkippedCount
        
        $results += [PSCustomObject]@{
            Suite = 'Pester'
            Passed = $pesterPassed
            Failed = $pesterFailed
            Skipped = $pesterSkipped
            Status = if ($pesterFailed -eq 0) { 'PASSED' } else { 'FAILED' }
        }
        
        if ($pesterFailed -gt 0) {
            $allPassed = $false
        }
    }
    Write-Host ""
}

#endregion

#region C# Tests (xUnit via dotnet test)

if (-not $SkipDotnet) {
    Write-Host "[xUnit] Running C# tests..." -ForegroundColor Yellow
    
    Push-Location $RepoRoot
    try {
        # Run dotnet test on the specific test project (avoid WAP project error)
        $testProject = Join-Path $RepoRoot 'tests\MarkdownViewerHost.Tests\MarkdownViewerHost.Tests.csproj'
        $testOutput = dotnet test $testProject --no-build -v quiet 2>&1
        $testExitCode = $LASTEXITCODE
        
        # Parse the results line
        $resultLine = $testOutput | Where-Object { $_ -match 'Passed:\s+\d+' } | Select-Object -Last 1
        if ($resultLine -match 'Failed:\s*(\d+).*Passed:\s*(\d+).*Skipped:\s*(\d+)') {
            $failed = [int]$Matches[1]
            $passed = [int]$Matches[2]
            $skipped = [int]$Matches[3]
        } elseif ($resultLine -match 'Passed:\s*(\d+)') {
            $passed = [int]$Matches[1]
            $failed = 0
            $skipped = 0
        } else {
            # Fallback: try to parse from different format
            $passed = 0; $failed = 0; $skipped = 0
            if ($testExitCode -ne 0) { $failed = 1 }
        }
        
        $results += [PSCustomObject]@{
            Suite = 'xUnit'
            Passed = $passed
            Failed = $failed
            Skipped = $skipped
            Status = if ($testExitCode -eq 0) { 'PASSED' } else { 'FAILED' }
        }
        
        if ($testExitCode -ne 0) {
            $allPassed = $false
            Write-Host "[xUnit] Some tests failed:" -ForegroundColor Red
            $testOutput | Where-Object { $_ -match 'Failed|Error' } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        } else {
            Write-Host "[xUnit] $passed tests passed" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
    Write-Host ""
}

#endregion

#region E2E MSIX Activation Tests (Optional)

if ($IncludeE2E) {
    Write-Host "[E2E] Running MSIX activation tests (interactive)..." -ForegroundColor Yellow
    Write-Host "[E2E] NOTE: This test requires user interaction (clicking Install in App Installer)" -ForegroundColor Cyan
    
    $e2eScript = Join-Path $ScriptRoot 'Test-PackagedActivation.ps1'
    if (Test-Path $e2eScript) {
        try {
            & $e2eScript
            $e2eExitCode = $LASTEXITCODE
            
            $results += [PSCustomObject]@{
                Suite = 'E2E'
                Passed = if ($e2eExitCode -eq 0) { 1 } else { 0 }
                Failed = if ($e2eExitCode -ne 0) { 1 } else { 0 }
                Skipped = 0
                Status = if ($e2eExitCode -eq 0) { 'PASSED' } else { 'FAILED' }
            }
            
            if ($e2eExitCode -ne 0) {
                $allPassed = $false
            }
        } catch {
            Write-Host "[E2E] ERROR: $_" -ForegroundColor Red
            $allPassed = $false
            $results += [PSCustomObject]@{ Suite = 'E2E'; Passed = 0; Failed = 1; Skipped = 0; Status = 'ERROR' }
        }
    } else {
        Write-Host "[E2E] Script not found: $e2eScript" -ForegroundColor Yellow
    }
    Write-Host ""
}

#endregion

#region Summary

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$totalPassed = ($results | Measure-Object -Property Passed -Sum).Sum
$totalFailed = ($results | Measure-Object -Property Failed -Sum).Sum
$totalSkipped = ($results | Measure-Object -Property Skipped -Sum).Sum

$results | ForEach-Object {
    $color = switch ($_.Status) {
        'PASSED' { 'Green' }
        'FAILED' { 'Red' }
        'ERROR'  { 'Red' }
        default  { 'Yellow' }
    }
    Write-Host ("  {0,-10} {1,4} passed, {2,2} failed, {3,2} skipped  [{4}]" -f $_.Suite, $_.Passed, $_.Failed, $_.Skipped, $_.Status) -ForegroundColor $color
}

Write-Host ""
Write-Host ("  Total:     {0,4} passed, {1,2} failed, {2,2} skipped" -f $totalPassed, $totalFailed, $totalSkipped)
Write-Host ""

if ($allPassed) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}

#endregion
