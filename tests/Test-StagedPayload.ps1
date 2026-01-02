# Test-StagedPayload.ps1 - App-level integration test for MSIX staged content
# Validates that the staged payload structure is correct and the engine can be invoked.
# This catches structural issues (like engine not found) before packaging.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$StagingDir,     # Path to staged content (e.g., installers\win-msix\obj\Staging\x64\Release)
    
    [string]$TestFile        # Optional markdown file to test. If not provided, uses a temporary file.
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Staged Payload Integration Test" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Staging directory: $StagingDir"

#region Validation: Directory Structure

Write-Host ""
Write-Host "[1/4] Validating directory structure..." -ForegroundColor Yellow

# Required paths
$hostExe = Join-Path $StagingDir 'MarkdownViewerHost.exe'
$appDir = Join-Path $StagingDir 'app'
$engineScript = Join-Path $appDir 'Open-Markdown.ps1'
$pwshDir = Join-Path $StagingDir 'pwsh'
$bundledPwsh = Join-Path $pwshDir 'pwsh.exe'
$assetsDir = Join-Path $StagingDir 'Assets'

$errors = @()

if (-not (Test-Path $StagingDir)) {
    Write-Error "Staging directory does not exist: $StagingDir"
}

if (-not (Test-Path $hostExe)) {
    $errors += "Host executable not found: $hostExe"
}

if (-not (Test-Path $appDir)) {
    $errors += "App directory not found: $appDir"
}

if (-not (Test-Path $engineScript)) {
    $errors += "Engine script not found: $engineScript"
}

if (-not (Test-Path $assetsDir)) {
    $errors += "Assets directory not found: $assetsDir"
}

# Check for required engine files
$requiredEngineFiles = @(
    'Open-Markdown.ps1',
    'script.js', 
    'style.css',
    'highlight.min.js',
    'highlight-theme.css',
    'MarkdownViewer.psm1'
)
foreach ($file in $requiredEngineFiles) {
    $filePath = Join-Path $appDir $file
    if (-not (Test-Path $filePath)) {
        $errors += "Missing engine file: app\$file"
    }
}

# Check for required assets
$requiredAssets = @(
    'StoreLogo.png',
    'Square44x44Logo.png',
    'Square150x150Logo.png',
    'Wide310x150Logo.png'
)
foreach ($asset in $requiredAssets) {
    $assetPath = Join-Path $assetsDir $asset
    if (-not (Test-Path $assetPath)) {
        $errors += "Missing asset: Assets\$asset"
    }
}

# Check for bundled pwsh (optional but logged)
$hasBundledPwsh = Test-Path $bundledPwsh
if ($hasBundledPwsh) {
    Write-Host "  Bundled pwsh: Found" -ForegroundColor Green
} else {
    Write-Host "  Bundled pwsh: Not found (will use system pwsh)" -ForegroundColor Yellow
}

if ($errors.Count -gt 0) {
    Write-Host ""
    foreach ($err in $errors) {
        Write-Host "  ERROR: $err" -ForegroundColor Red
    }
    Write-Error "Directory structure validation failed with $($errors.Count) error(s)"
}

Write-Host "  Directory structure: OK" -ForegroundColor Green

#endregion

#region Validation: Simulate Host Path Resolution

Write-Host ""
Write-Host "[2/4] Simulating host path resolution..." -ForegroundColor Yellow

# This simulates what Program.cs does in LaunchEngine()
# The host runs from staging root, not a subfolder, so paths should work directly
$simulatedBaseDir = $StagingDir
$resolvedPwsh = Join-Path $simulatedBaseDir 'pwsh' 'pwsh.exe'
$resolvedEngine = Join-Path $simulatedBaseDir 'app' 'Open-Markdown.ps1'

$pathResolutionOk = $true

if (-not (Test-Path $resolvedEngine)) {
    Write-Host "  ERROR: Engine not found at resolved path: $resolvedEngine" -ForegroundColor Red
    $pathResolutionOk = $false
}

# Determine which pwsh will be used
$pwshToUse = $null
if (Test-Path $resolvedPwsh) {
    $pwshToUse = $resolvedPwsh
    Write-Host "  Resolved pwsh: $resolvedPwsh (bundled)" -ForegroundColor Gray
} else {
    $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($systemPwsh) {
        $pwshToUse = $systemPwsh.Source
        Write-Host "  Resolved pwsh: $pwshToUse (system)" -ForegroundColor Gray
    } else {
        Write-Host "  ERROR: No pwsh available (bundled or system)" -ForegroundColor Red
        $pathResolutionOk = $false
    }
}

if (-not $pathResolutionOk) {
    Write-Error "Path resolution validation failed"
}

Write-Host "  Path resolution: OK" -ForegroundColor Green
Write-Host "  Resolved engine: $resolvedEngine" -ForegroundColor Gray

#endregion

#region Validation: Engine Module Import

Write-Host ""
Write-Host "[3/4] Testing engine module import..." -ForegroundColor Yellow

# Test that the MarkdownViewer.psm1 module can be imported
$modulePath = Join-Path $appDir 'MarkdownViewer.psm1'
if (Test-Path $modulePath) {
    try {
        # Import in a separate scope to avoid pollution
        $importResult = & $pwshToUse -NoProfile -ExecutionPolicy Bypass -Command @"
            `$ErrorActionPreference = 'Stop'
            try {
                Import-Module '$modulePath' -Force -ErrorAction Stop
                `$commands = Get-Command -Module MarkdownViewer
                if (`$commands.Count -eq 0) {
                    throw 'No commands exported from module'
                }
                Write-Output "OK:`$(`$commands.Count) commands"
            } catch {
                Write-Output "ERROR:`$_"
                exit 1
            }
"@
        if ($importResult -match '^OK:(\d+)') {
            $cmdCount = $matches[1]
            Write-Host "  Module import: OK ($cmdCount commands exported)" -ForegroundColor Green
        } else {
            Write-Host "  Module import: $importResult" -ForegroundColor Red
            Write-Error "Module import failed: $importResult"
        }
    } catch {
        Write-Host "  ERROR: Module import test failed: $_" -ForegroundColor Red
        Write-Error "Module import validation failed"
    }
} else {
    Write-Host "  WARNING: MarkdownViewer.psm1 not found, skipping module test" -ForegroundColor Yellow
}

#endregion

#region Validation: Engine Dry Run

Write-Host ""
Write-Host "[4/4] Testing engine invocation (dry run)..." -ForegroundColor Yellow

# Create a temporary test markdown file if none provided
$tempFile = $null
if (-not $TestFile -or -not (Test-Path $TestFile)) {
    $tempFile = Join-Path $env:TEMP "mdv-test-$([Guid]::NewGuid().ToString('N').Substring(0,8)).md"
    @"
# Test Document

This is a **test** markdown file generated for integration testing.

``````powershell
Write-Host "Hello from code block"
``````

- Item 1
- Item 2

> Quote block

[Link text](https://example.com)
"@ | Set-Content -Path $tempFile -Encoding UTF8
    $TestFile = $tempFile
    Write-Host "  Created temp test file: $tempFile" -ForegroundColor Gray
}

Write-Host "  Test file: $TestFile" -ForegroundColor Gray

# Run the engine with -NoLaunch to generate HTML without opening browser
# First, check if -NoLaunch parameter exists
$engineParams = & $pwshToUse -NoProfile -ExecutionPolicy Bypass -Command @"
    `$script = Get-Command '$resolvedEngine' -ErrorAction SilentlyContinue
    if (`$script) {
        (Get-Command '$resolvedEngine').Parameters.Keys -join ','
    }
"@

Write-Host "  Engine parameters: $engineParams" -ForegroundColor Gray

# The engine doesn't have -NoLaunch, so we'll just validate the command can be constructed
# and do a syntax check instead of a full run (which would open a browser)

$engineSyntax = & $pwshToUse -NoProfile -ExecutionPolicy Bypass -Command @"
    `$ErrorActionPreference = 'Stop'
    try {
        # Parse the script to check for syntax errors
        `$ast = [System.Management.Automation.Language.Parser]::ParseFile('$resolvedEngine', [ref]`$null, [ref]`$errors)
        if (`$errors.Count -gt 0) {
            throw "Syntax errors: `$(`$errors.Message -join '; ')"
        }
        
        # Check the script has expected param block
        if (`$ast.ParamBlock -eq `$null) {
            throw 'No param block found in engine script'
        }
        
        Write-Output 'OK:Script parsed successfully'
    } catch {
        Write-Output "ERROR:`$_"
        exit 1
    }
"@

if ($engineSyntax -match '^OK:') {
    Write-Host "  Engine syntax: OK" -ForegroundColor Green
} else {
    Write-Host "  ERROR: $engineSyntax" -ForegroundColor Red
    Write-Error "Engine syntax validation failed"
}

# Cleanup temp file
if ($tempFile -and (Test-Path $tempFile)) {
    Remove-Item $tempFile -Force
    Write-Host "  Cleaned up temp file" -ForegroundColor Gray
}

#endregion

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All integration tests passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
