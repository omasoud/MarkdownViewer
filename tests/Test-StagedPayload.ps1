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

# Convert to absolute path for consistency
$StagingDir = [System.IO.Path]::GetFullPath($StagingDir)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Staged Payload Integration Test" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Staging directory: $StagingDir"

#region Validation: Directory Structure

Write-Host ""
Write-Host "[1/5] Validating directory structure..." -ForegroundColor Yellow

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
    'MarkdownViewer.psm1',
    'MarkdownViewer.Shared.psm1',
    'vendor/katex/katex.min.js',
    'vendor/katex/katex.min.css',
    'vendor/katex/fonts/KaTeX_Main-Regular.woff2',
    'vendor/katex/README.md',
    'vendor/katex/LICENSE',
    'THIRD-PARTY-LICENSES.md'
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
Write-Host "[2/5] Simulating host path resolution..." -ForegroundColor Yellow

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
Write-Host "[3/5] Testing engine module import..." -ForegroundColor Yellow

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
Write-Host "[4/5] Testing engine invocation (dry run)..." -ForegroundColor Yellow

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
        `$tokens = `$null
        `$parseErrors = `$null
        `$ast = [System.Management.Automation.Language.Parser]::ParseFile('$resolvedEngine', [ref]`$tokens, [ref]`$parseErrors)
        if (`$parseErrors.Count -gt 0) {
            throw "Syntax errors: `$(`$parseErrors.Message -join '; ')"
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

#region Validation: Host-in-Subfolder Path Resolution (WAP Layout Simulation)

Write-Host ""
Write-Host "[5/5] Testing host-in-subfolder path resolution (WAP layout)..." -ForegroundColor Yellow

# This test simulates the WAP package layout where the host EXE ends up in a subfolder
# (e.g., PackageRoot\MarkdownViewerHost\MarkdownViewerHost.exe) while pwsh\ and app\ 
# are at the package root (PackageRoot\pwsh\, PackageRoot\app\).

$wapTestRoot = Join-Path $env:TEMP "mdv-wap-test-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
$wapTestFailed = $false

try {
    Write-Host "  Creating WAP layout simulation at: $wapTestRoot" -ForegroundColor Gray
    
    # Create the WAP-like structure:
    # $wapTestRoot\
    #   MarkdownViewerHost\
    #     MarkdownViewerHost.exe (and dependencies)
    #   pwsh\
    #     pwsh.exe (copy or stub)
    #   app\
    #     Open-Markdown.ps1 (and other files)
    
    $wapHostSubfolder = Join-Path $wapTestRoot 'MarkdownViewerHost'
    $wapPwshDir = Join-Path $wapTestRoot 'pwsh'
    $wapAppDir = Join-Path $wapTestRoot 'app'
    
    New-Item -ItemType Directory -Path $wapHostSubfolder -Force | Out-Null
    New-Item -ItemType Directory -Path $wapPwshDir -Force | Out-Null
    New-Item -ItemType Directory -Path $wapAppDir -Force | Out-Null
    
    # Copy the host executable and its dependencies to the subfolder
    $hostDir = Split-Path $hostExe -Parent
    $hostFiles = Get-ChildItem -Path $hostDir -File | Where-Object { 
        $_.Extension -in '.exe', '.dll', '.json', '.pdb'
    }
    foreach ($file in $hostFiles) {
        Copy-Item $file.FullName -Destination $wapHostSubfolder -Force
    }
    Write-Host "    Copied host files to subfolder" -ForegroundColor Gray
    
    # Copy pwsh if bundled, otherwise create a stub
    if ($hasBundledPwsh) {
        # Just copy pwsh.exe as a marker file (we won't actually run it)
        Copy-Item $bundledPwsh -Destination $wapPwshDir -Force
        Write-Host "    Copied bundled pwsh.exe" -ForegroundColor Gray
    } else {
        # Create a dummy pwsh.exe marker (host checks File.Exists)
        "dummy" | Set-Content -Path (Join-Path $wapPwshDir 'pwsh.exe') -Force
        Write-Host "    Created stub pwsh.exe marker" -ForegroundColor Gray
    }
    
    # Copy app content
    Copy-Item -Path (Join-Path $appDir '*') -Destination $wapAppDir -Recurse -Force
    Write-Host "    Copied app content" -ForegroundColor Gray
    
    # Create test signal file path
    $signalFile = Join-Path $wapTestRoot 'test-signal.json'
    
    # Create a test markdown file
    $testMdFile = Join-Path $wapTestRoot 'test.md'
    "# Test" | Set-Content -Path $testMdFile -Force
    
    # Set up the test environment variable
    $wapHostExe = Join-Path $wapHostSubfolder 'MarkdownViewerHost.exe'
    
    # Test 1: File path argument
    Write-Host "  Running host with file path argument..." -ForegroundColor Gray
    $env:MDV_TEST_SIGNAL_PATH = $signalFile
    try {
        $process = Start-Process -FilePath $wapHostExe -ArgumentList "`"$testMdFile`"" -PassThru -Wait -NoNewWindow
        if ($process.ExitCode -ne 0) {
            Write-Host "    WARNING: Host exited with code $($process.ExitCode)" -ForegroundColor Yellow
        }
    } finally {
        Remove-Item Env:\MDV_TEST_SIGNAL_PATH -ErrorAction SilentlyContinue
    }
    
    # Verify signal file was created
    if (-not (Test-Path $signalFile)) {
        Write-Host "  ERROR: Test signal file was not created" -ForegroundColor Red
        $wapTestFailed = $true
    } else {
        $signals = Get-Content $signalFile | ForEach-Object { $_ | ConvertFrom-Json }
        $fileSignal = $signals | Where-Object { $_.arg -eq $testMdFile }
        
        if (-not $fileSignal) {
            Write-Host "  ERROR: No signal found for file path test" -ForegroundColor Red
            $wapTestFailed = $true
        } else {
            Write-Host "    Signal received for file path test" -ForegroundColor Gray
            
            # Verify resolved paths point to parent (package root)
            $expectedPwsh = Join-Path $wapTestRoot 'pwsh' 'pwsh.exe'
            $expectedEngine = Join-Path $wapTestRoot 'app' 'Open-Markdown.ps1'
            
            # Normalize paths for comparison (handle trailing slashes)
            $resolvedRoot = $fileSignal.resolvedPackageRoot.TrimEnd('\', '/')
            $expectedRoot = $wapTestRoot.TrimEnd('\', '/')
            
            if ($resolvedRoot -ne $expectedRoot) {
                Write-Host "  ERROR: Package root not resolved correctly" -ForegroundColor Red
                Write-Host "    Expected: $expectedRoot" -ForegroundColor Red
                Write-Host "    Got:      $resolvedRoot" -ForegroundColor Red
                $wapTestFailed = $true
            }
            
            if ($fileSignal.resolvedPwsh -ne $expectedPwsh) {
                Write-Host "  ERROR: pwsh path not resolved correctly" -ForegroundColor Red
                Write-Host "    Expected: $expectedPwsh" -ForegroundColor Red
                Write-Host "    Got:      $($fileSignal.resolvedPwsh)" -ForegroundColor Red
                $wapTestFailed = $true
            }
            
            if ($fileSignal.resolvedEngine -ne $expectedEngine) {
                Write-Host "  ERROR: Engine path not resolved correctly" -ForegroundColor Red
                Write-Host "    Expected: $expectedEngine" -ForegroundColor Red
                Write-Host "    Got:      $($fileSignal.resolvedEngine)" -ForegroundColor Red
                $wapTestFailed = $true
            }
            
            if (-not $wapTestFailed) {
                Write-Host "    Resolved package root: $($fileSignal.resolvedPackageRoot)" -ForegroundColor Gray
                Write-Host "    Resolved pwsh: $($fileSignal.resolvedPwsh)" -ForegroundColor Gray
                Write-Host "    Resolved engine: $($fileSignal.resolvedEngine)" -ForegroundColor Gray
            }
        }
    }
    
    # Test 2: Protocol URI argument
    Remove-Item $signalFile -Force -ErrorAction SilentlyContinue
    $testUri = "mdview:file:///$($testMdFile -replace '\\','/')#section"
    
    Write-Host "  Running host with protocol URI argument..." -ForegroundColor Gray
    $env:MDV_TEST_SIGNAL_PATH = $signalFile
    try {
        $process = Start-Process -FilePath $wapHostExe -ArgumentList "`"$testUri`"" -PassThru -Wait -NoNewWindow
    } finally {
        Remove-Item Env:\MDV_TEST_SIGNAL_PATH -ErrorAction SilentlyContinue
    }
    
    if (Test-Path $signalFile) {
        $signals = Get-Content $signalFile | ForEach-Object { $_ | ConvertFrom-Json }
        $protocolSignal = $signals | Where-Object { $_.arg -eq $testUri }
        
        if ($protocolSignal) {
            Write-Host "    Signal received for protocol URI test" -ForegroundColor Gray
            Write-Host "    URI preserved: $($protocolSignal.arg)" -ForegroundColor Gray
            
            # Verify the fragment was preserved
            if ($protocolSignal.arg -notmatch '#section$') {
                Write-Host "  ERROR: URI fragment was not preserved" -ForegroundColor Red
                $wapTestFailed = $true
            }
        } else {
            Write-Host "  ERROR: No signal found for protocol URI test" -ForegroundColor Red
            $wapTestFailed = $true
        }
    } else {
        Write-Host "  ERROR: Test signal file was not created for protocol test" -ForegroundColor Red
        $wapTestFailed = $true
    }

} catch {
    Write-Host "  ERROR: WAP layout test failed: $_" -ForegroundColor Red
    $wapTestFailed = $true
} finally {
    # Cleanup
    if (Test-Path $wapTestRoot) {
        Remove-Item $wapTestRoot -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleaned up WAP test directory" -ForegroundColor Gray
    }
}

if ($wapTestFailed) {
    Write-Error "Host-in-subfolder path resolution test failed"
}

Write-Host "  Host-in-subfolder test: OK" -ForegroundColor Green

#endregion

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All integration tests passed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
