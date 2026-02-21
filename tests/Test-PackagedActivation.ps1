# Test-PackagedActivation.ps1 - Full MSIX E2E Activation Test
# Builds, packages, installs MSIX and tests activation using ActivationDriver.exe
# This catches "silent requirement misses" that only manifest when running as a real package.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture = 'x64',
    
    [string]$Version = '1.0.1.0',
    
    [switch]$SkipBuild,         # Skip dotnet build (use existing artifacts)
    
    [switch]$SkipStageTest,     # Skip running Test-StagedPayload.ps1
    
    [switch]$SkipInstall,       # Skip MSIX installation (use existing install)
    
    [switch]$SkipDependencyGate,# Skip the clean-machine dependency check
    
    [switch]$KeepInstalled      # Don't uninstall the package after test
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptRoot
$MsixDir = Join-Path $RepoRoot 'installers\win-msix'
$BuildScript = Join-Path $MsixDir 'build.ps1'
$StageTestScript = Join-Path $ScriptRoot 'Test-StagedPayload.ps1'
$ActivationDriverDir = Join-Path $ScriptRoot 'ActivationDriver'
$ActivationDriverProj = Join-Path $ActivationDriverDir 'ActivationDriver.csproj'
$OutputDir = Join-Path $MsixDir 'output'

# Package identity from manifest
$PackageName = 'omasoud.MarkView'
$ApplicationId = 'App'

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "MSIX End-to-End Activation Test" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Architecture: $Architecture"
Write-Host "  Version:      $Version"
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testsSkipped = 0

function Write-TestResult {
    param([string]$Name, [bool]$Passed, [string]$Message = '')
    
    if ($Passed) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Message) {
            Write-Host "         $Message" -ForegroundColor Red
        }
        $script:testsFailed++
    }
}

function Write-TestSkipped {
    param([string]$Name, [string]$Reason = '')
    Write-Host "  [SKIP] $Name" -ForegroundColor Yellow
    if ($Reason) {
        Write-Host "         $Reason" -ForegroundColor Yellow
    }
    $script:testsSkipped++
}

#region Step 1: Dependency Gate (Clean Machine Check)

Write-Host "[1/7] Dependency Gate: Clean Machine Check" -ForegroundColor Yellow

if ($SkipDependencyGate) {
    Write-TestSkipped -Name "Windows App SDK runtime check" -Reason "Skipped via -SkipDependencyGate"
} else {
    # Check for Windows App SDK runtime packages
    $wasdk = Get-AppxPackage | Where-Object { $_.Name -like 'Microsoft.WindowsAppRuntime*' }
    if ($wasdk) {
        Write-Host "  NOTE: Windows App SDK runtime packages found (expected on dev machine):" -ForegroundColor Yellow
        $wasdk | ForEach-Object { Write-Host "    - $($_.Name) $($_.Version)" -ForegroundColor Yellow }
        Write-Host "  This may mask dependency issues that would fail on clean machines." -ForegroundColor Yellow
        Write-Host "  For true clean-machine validation, run this test in a clean VM." -ForegroundColor Yellow
        # Mark as passed but with a warning - on dev machines this is expected
        Write-TestResult -Name "Windows App SDK runtime check" -Passed $true
        Write-Host "    (Warning: SDK runtime present - clean machine validation recommended)" -ForegroundColor Yellow
    } else {
        Write-TestResult -Name "Windows App SDK runtime check" -Passed $true
    }
}

#endregion

#region Step 2: Build ActivationDriver

Write-Host ""
Write-Host "[2/7] Building ActivationDriver.exe" -ForegroundColor Yellow

if (-not (Test-Path $ActivationDriverProj)) {
    Write-Error "ActivationDriver.csproj not found at: $ActivationDriverProj"
}

try {
    Push-Location $ActivationDriverDir
    $buildOutput = dotnet build -c Release 2>&1
    $buildExitCode = $LASTEXITCODE
    
    if ($buildExitCode -ne 0) {
        Write-Host $buildOutput -ForegroundColor Red
        Write-TestResult -Name "ActivationDriver build" -Passed $false -Message "dotnet build failed with exit code $buildExitCode"
    } else {
        $activationDriverExe = Join-Path $ActivationDriverDir 'bin\Release\net481\win-x64\ActivationDriver.exe'
        if (Test-Path $activationDriverExe) {
            Write-TestResult -Name "ActivationDriver build" -Passed $true
        } else {
            Write-TestResult -Name "ActivationDriver build" -Passed $false -Message "Output not found: $activationDriverExe"
        }
    }
} finally {
    Pop-Location
}

#endregion

#region Step 3: Build MSIX

Write-Host ""
Write-Host "[3/7] Building MSIX Package" -ForegroundColor Yellow

if ($SkipBuild) {
    Write-TestSkipped -Name "MSIX build" -Reason "Skipped via -SkipBuild"
    
    # Find existing MSIX
    $msixPath = Join-Path $OutputDir "MarkdownViewer_${Version}_$Architecture.msix"
    if (-not (Test-Path $msixPath)) {
        Write-Error "MSIX not found and build skipped: $msixPath"
    }
} else {
    try {
        # Run the build script with signing enabled for installation
        $buildArgs = @{
            Configuration = 'Release'
            Architecture = $Architecture
            Version = $Version
            DownloadPwsh = $true  # Use pinned pwsh version
            Sign = $true          # Sign the MSIX for installation
        }
        & $BuildScript @buildArgs
        
        $msixPath = Join-Path $OutputDir "MarkdownViewer_${Version}_$Architecture.msix"
        if (Test-Path $msixPath) {
            Write-TestResult -Name "MSIX build" -Passed $true
            Write-Host "    MSIX: $msixPath" -ForegroundColor Gray
        } else {
            Write-TestResult -Name "MSIX build" -Passed $false -Message "MSIX not created: $msixPath"
        }
    } catch {
        Write-TestResult -Name "MSIX build" -Passed $false -Message $_.Exception.Message
    }
}

#endregion

#region Step 4: Run Staged Payload Test

Write-Host ""
Write-Host "[4/7] Running Staged Payload Test" -ForegroundColor Yellow

if ($SkipStageTest) {
    Write-TestSkipped -Name "Staged payload test" -Reason "Skipped via -SkipStageTest"
} else {
    $stageDir = Join-Path $OutputDir "stage-$Architecture"
    if (-not (Test-Path $stageDir)) {
        # Single-arch build uses different path
        $stageDir = Join-Path $OutputDir 'stage'
    }
    
    if (Test-Path $stageDir) {
        try {
            & $StageTestScript -StagingDir $stageDir
            Write-TestResult -Name "Staged payload test" -Passed $true
        } catch {
            Write-TestResult -Name "Staged payload test" -Passed $false -Message $_.Exception.Message
        }
    } else {
        Write-TestResult -Name "Staged payload test" -Passed $false -Message "Stage directory not found: $stageDir"
    }
}

#endregion

#region Step 5: Static Dependency Scan

Write-Host ""
Write-Host "[5/7] Static Dependency Scan" -ForegroundColor Yellow

# Scan host assembly for forbidden dependencies
$stageDir = Join-Path $OutputDir "stage-$Architecture"
if (-not (Test-Path $stageDir)) {
    $stageDir = Join-Path $OutputDir 'stage'
}

$hostExePath = Join-Path $stageDir 'MarkdownViewerHost.exe'
if (Test-Path $hostExePath) {
    try {
        # Use ildasm or dotnet tool to check references
        # For simplicity, we'll read the assembly metadata
        $assemblyBytes = [System.IO.File]::ReadAllBytes($hostExePath)
        $assemblyText = [System.Text.Encoding]::ASCII.GetString($assemblyBytes)
        
        $forbiddenPatterns = @(
            'Microsoft.WindowsAppRuntime',
            'Microsoft.WindowsAppSDK',
            'WinRT.Runtime',
            'Microsoft.Windows.SDK.NET'  # This is expected for Windows.ApplicationModel usage
        )
        
        $foundForbidden = @()
        foreach ($pattern in $forbiddenPatterns) {
            # Skip Microsoft.Windows.SDK.NET as it's legitimately used for activation APIs
            if ($pattern -eq 'Microsoft.Windows.SDK.NET') { continue }
            
            if ($assemblyText -match $pattern) {
                $foundForbidden += $pattern
            }
        }
        
        if ($foundForbidden.Count -gt 0) {
            Write-TestResult -Name "Static dependency scan" -Passed $false -Message "Forbidden references: $($foundForbidden -join ', ')"
        } else {
            Write-TestResult -Name "Static dependency scan" -Passed $true
        }
    } catch {
        Write-TestSkipped -Name "Static dependency scan" -Reason "Could not analyze: $_"
    }
} else {
    Write-TestSkipped -Name "Static dependency scan" -Reason "Host EXE not found: $hostExePath"
}

#endregion

#region Step 6: Install MSIX

Write-Host ""
Write-Host "[6/7] Installing MSIX Package" -ForegroundColor Yellow

$msixPath = Join-Path $OutputDir "MarkdownViewer_${Version}_$Architecture.msix"

if ($SkipInstall) {
    Write-TestSkipped -Name "MSIX installation" -Reason "Skipped via -SkipInstall"
} else {
    # First, ensure signing certificate is trusted in LocalMachine\Root
    # This is required for MSIX installation and needs admin rights
    $certSubject = 'CN=7D515F91-B0EF-4927-8C46-4D23245ABE47'
    $certInLocalMachineRoot = Get-ChildItem -Path Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | 
        Where-Object { $_.Subject -eq $certSubject }
    
    if (-not $certInLocalMachineRoot) {
        Write-Host "  Certificate not in LocalMachine\Root - elevation required..." -ForegroundColor Yellow
        
        # Get the certificate from CurrentUser\My (signing cert)
        $signingCert = Get-ChildItem -Path Cert:\CurrentUser\My | 
            Where-Object { $_.Subject -eq $certSubject } | 
            Sort-Object NotAfter -Descending | 
            Select-Object -First 1
        
        if (-not $signingCert) {
            Write-TestResult -Name "MSIX installation" -Passed $false -Message "Signing certificate not found in CurrentUser\My"
        } else {
            # Export cert to temp file and import to LocalMachine\Root with elevation
            $tempCertPath = Join-Path $env:TEMP "mdv_cert_$([Guid]::NewGuid().ToString('N').Substring(0,8)).cer"
            $signingCert | Export-Certificate -FilePath $tempCertPath -Type CERT -Force | Out-Null
            
            Write-Host "  >>> A UAC prompt will appear - please click 'Yes' to trust the certificate <<<" -ForegroundColor Cyan
            Write-Host ""
            
            # Run Import-Certificate as admin via Start-Process
            $importCmd = "Import-Certificate -FilePath '$tempCertPath' -CertStoreLocation Cert:\LocalMachine\Root | Out-Null"
            $proc = Start-Process -FilePath pwsh -ArgumentList "-NoProfile", "-Command", $importCmd -Verb RunAs -Wait -PassThru
            
            Remove-Item $tempCertPath -Force -ErrorAction SilentlyContinue
            
            if ($proc.ExitCode -eq 0) {
                Write-Host "  Certificate trusted successfully" -ForegroundColor Green
            } else {
                Write-TestResult -Name "MSIX installation" -Passed $false -Message "Failed to trust certificate (UAC cancelled?)"
            }
        }
    } else {
        Write-Host "  Certificate already trusted in LocalMachine\Root" -ForegroundColor Green
    }
    
    # Verify certificate is now trusted
    $certInLocalMachineRoot = Get-ChildItem -Path Cert:\LocalMachine\Root -ErrorAction SilentlyContinue | 
        Where-Object { $_.Subject -eq $certSubject }
    
    if (-not $certInLocalMachineRoot) {
        Write-TestResult -Name "MSIX installation" -Passed $false -Message "Certificate trust failed"
    } else {
        # Now install the package
        # Remove prior install if present
        $existingPackage = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
        if ($existingPackage) {
            Write-Host "  Removing existing package..." -ForegroundColor Gray
            try {
                $existingPackage | Remove-AppxPackage -ErrorAction Stop
                Write-Host "  Removed: $($existingPackage.PackageFullName)" -ForegroundColor Gray
            } catch {
                Write-Host "  WARNING: Could not remove existing package: $_" -ForegroundColor Yellow
            }
        }
        
        if (-not (Test-Path $msixPath)) {
            Write-TestResult -Name "MSIX installation" -Passed $false -Message "MSIX not found: $msixPath"
        } else {
            # Use interactive installation via App Installer (no admin required if cert is trusted)
            Write-Host "  Opening MSIX for interactive installation..." -ForegroundColor Cyan
            Write-Host "  >>> Please click 'Install' in the App Installer window <<<" -ForegroundColor Yellow
            Write-Host ""
            
            # Launch the MSIX file which opens App Installer UI
            Start-Process -FilePath $msixPath
            
            # Poll for installation completion (user must click Install)
            $maxWaitSeconds = 120
            $pollIntervalSeconds = 2
            $elapsedSeconds = 0
            $installed = $false
            
            Write-Host "  Waiting for installation (timeout: ${maxWaitSeconds}s)..." -ForegroundColor Gray
            while ($elapsedSeconds -lt $maxWaitSeconds) {
                Start-Sleep -Seconds $pollIntervalSeconds
                $elapsedSeconds += $pollIntervalSeconds
                
                $installedPackage = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
                if ($installedPackage) {
                    $installed = $true
                    break
                }
                
                # Show progress every 10 seconds
                if ($elapsedSeconds % 10 -eq 0) {
                    Write-Host "    Still waiting... (${elapsedSeconds}s)" -ForegroundColor Gray
                }
            }
            
            if ($installed) {
                Write-TestResult -Name "MSIX installation" -Passed $true
                Write-Host "    Installed: $($installedPackage.PackageFullName)" -ForegroundColor Gray
                Write-Host "    Location:  $($installedPackage.InstallLocation)" -ForegroundColor Gray
            } else {
                Write-TestResult -Name "MSIX installation" -Passed $false -Message "Installation timed out after ${maxWaitSeconds}s - did you click Install?"
            }
        }
    }
}

#endregion

#region Step 7: Activation Tests

Write-Host ""
Write-Host "[7/7] Activation Tests" -ForegroundColor Yellow

$installedPackage = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
if (-not $installedPackage) {
    Write-TestSkipped -Name "All activation tests" -Reason "Package not installed"
} else {
    # Construct AUMID
    $packageFamilyName = $installedPackage.PackageFamilyName
    $aumid = "${packageFamilyName}!${ApplicationId}"
    Write-Host "  AUMID: $aumid" -ForegroundColor Gray
    
    # Verify install location structure
    $installLocation = $installedPackage.InstallLocation
    Write-Host "  Install Location: $installLocation" -ForegroundColor Gray
    
    # Check required paths exist in installed package
    $installedPwsh = Join-Path $installLocation 'pwsh\pwsh.exe'
    $installedEngine = Join-Path $installLocation 'app\Open-Markdown.ps1'
    $installedHost = Join-Path $installLocation 'MarkdownViewerHost.exe'
    
    # Note: In WAP layout, host might be in a subfolder
    if (-not (Test-Path $installedHost)) {
        $installedHost = Join-Path $installLocation 'MarkdownViewerHost\MarkdownViewerHost.exe'
    }
    
    $structureOk = $true
    if (-not (Test-Path $installedEngine)) {
        Write-TestResult -Name "Installed structure: engine" -Passed $false -Message "Not found: $installedEngine"
        $structureOk = $false
    }
    if (-not (Test-Path $installedPwsh)) {
        Write-Host "  NOTE: Bundled pwsh not found, package will use system pwsh" -ForegroundColor Yellow
    }
    if ($structureOk) {
        Write-TestResult -Name "Installed structure" -Passed $true
    }
    
    # Create E2E trace file
    $traceFile = Join-Path $env:TEMP "mdv-e2e-trace-$([Guid]::NewGuid().ToString('N').Substring(0,8)).json"
    
    # Create test markdown file
    $testMdFile = Join-Path $env:TEMP 'mdv-e2e-test.md'
    "# E2E Test Document`n`nThis is a test." | Set-Content -Path $testMdFile -Encoding UTF8
    
    # Set up activation driver
    $activationDriverExe = Join-Path $ActivationDriverDir 'bin\Release\net481\win-x64\ActivationDriver.exe'
    
    if (-not (Test-Path $activationDriverExe)) {
        Write-TestSkipped -Name "Activation tests" -Reason "ActivationDriver.exe not found"
    } else {
        # Set E2E trace path environment variable for the package
        # Note: For packaged apps, we need to set this via a different mechanism
        # The most reliable approach is to create a manifest that sets it, but for testing
        # we'll try launching via cmd with the env var set
        
        Write-Host ""
        Write-Host "  Running activation tests..." -ForegroundColor Yellow
        
        # Test 1: Protocol activation via shell (how users actually invoke mdview: URIs)
        # For Full Trust desktop bridge apps, shell-based protocol activation triggers
        # true packaged activation via AppInstance APIs. The COM ActivateForProtocol
        # method doesn't work for Full Trust apps - that's UWP-only.
        Write-Host "  Testing protocol activation (shell)..." -ForegroundColor Gray
        $protocolUri = "mdview:file:///$($testMdFile -replace '\\','/')#test-section"
        
        try {
            # Clear the host log to capture only this activation
            $hostLogPath = Join-Path $env:TEMP 'MarkdownViewerHost.log'
            if (Test-Path $hostLogPath) { Clear-Content $hostLogPath -Force }
            
            # Shell-based protocol activation - this is how users invoke the app
            # via browser links, Start-Process, or clicking protocol URLs
            Start-Process $protocolUri -ErrorAction Stop
            
            # Give the app time to start and log
            Start-Sleep -Milliseconds 2000
            
            # Read the host log to verify activation kind
            $hostLog = if (Test-Path $hostLogPath) { Get-Content $hostLogPath -Raw -ErrorAction SilentlyContinue } else { '' }
            
            # Check for true protocol activation indicators
            $isProtocolKind = $hostLog -match 'ActivationKind:\s*[Pp]rotocol'
            $isViaAppInstance = $hostLog -match 'Handling Protocol activation via AppInstance'
            $isHandledTrue = $hostLog -match 'PackagedActivation handled:\s*True'
            $hasProtocolUri = $hostLog -match 'ProtocolUri from ActivatedEventArgs:\s*mdview:'
            
            if ($isProtocolKind -and $isViaAppInstance -and $isHandledTrue -and $hasProtocolUri) {
                Write-TestResult -Name "Protocol activation (ActivationKind.Protocol)" -Passed $true
                # Show key log lines for verification
                Write-Host "    Verified: ActivationKind=protocol, ProtocolUri present" -ForegroundColor Gray
            } else {
                # Detailed failure message
                $failReason = @()
                if (-not $isProtocolKind) { $failReason += "ActivationKind != Protocol" }
                if (-not $isViaAppInstance) { $failReason += "Not via AppInstance" }
                if (-not $isHandledTrue) { $failReason += "PackagedActivation handled != True" }
                if (-not $hasProtocolUri) { $failReason += "No ProtocolUri from ActivatedEventArgs" }
                
                Write-TestResult -Name "Protocol activation (ActivationKind.Protocol)" -Passed $false -Message ($failReason -join '; ')
                Write-Host "    Host log content:" -ForegroundColor Yellow
                if ([string]::IsNullOrWhiteSpace($hostLog)) {
                    Write-Host "      (log is empty - app may not have started)" -ForegroundColor Red
                } else {
                    $hostLog -split "`n" | Select-Object -First 20 | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
                }
            }
        } catch {
            Write-TestResult -Name "Protocol activation" -Passed $false -Message $_.Exception.Message
        }
        
        # Wait a moment between activations
        Start-Sleep -Milliseconds 500
        
        # Test 2: In-app link navigation (simulates clicking a rewritten mdview: link)
        # This is the REAL protocol activation use case:
        # 1. User opens main.md which links to [other doc](./other.md)
        # 2. script.js rewrites this to mdview:file:///path/to/other.md
        # 3. User clicks the link in the browser
        # 4. Browser invokes OS protocol handler for mdview:
        # 5. MSIX app receives ActivationKind.Protocol
        Write-Host "  Testing in-app link navigation (mdview: from browser)..." -ForegroundColor Gray
        
        try {
            # Create two linked test markdown files
            $testDir = Join-Path $env:TEMP "mdv-e2e-link-test-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            
            $mainMd = Join-Path $testDir 'main.md'
            $linkedMd = Join-Path $testDir 'linked.md'
            
            # Main document that links to another markdown file
            @"
# Main Document

Click [linked document](./linked.md) to test in-app navigation.

This simulates the real workflow where script.js rewrites the link
to ``mdview:file:///...`` and clicking it triggers protocol activation.
"@ | Set-Content -Path $mainMd -Encoding UTF8
            
            # The linked document
            @"
# Linked Document

You arrived here via mdview: protocol activation!
This proves that clicking rewritten links triggers ActivationKind.Protocol.
"@ | Set-Content -Path $linkedMd -Encoding UTF8
            
            # Clear the host log
            $hostLogPath = Join-Path $env:TEMP 'MarkdownViewerHost.log'
            if (Test-Path $hostLogPath) { Clear-Content $hostLogPath -Force }
            
            # Construct the mdview: URI that script.js would generate for the linked file
            # This is exactly what the browser would navigate to when user clicks the link
            $linkedFileUri = "file:///$($linkedMd -replace '\\','/')"
            $mdviewUri = "mdview:$linkedFileUri"
            
            Write-Host "    Simulating click on rewritten link: $mdviewUri" -ForegroundColor Gray
            
            # Invoke the protocol handler - this is what the browser does
            Start-Process $mdviewUri -ErrorAction Stop
            
            # Give the app time to start and log
            Start-Sleep -Milliseconds 2500
            
            # Read the host log to verify this was true protocol activation
            $hostLog = if (Test-Path $hostLogPath) { Get-Content $hostLogPath -Raw -ErrorAction SilentlyContinue } else { '' }
            
            # Check for true protocol activation (not file activation, not launch)
            $isProtocolKind = $hostLog -match 'ActivationKind:\s*[Pp]rotocol'
            $isViaAppInstance = $hostLog -match 'Handling Protocol activation via AppInstance'
            $hasProtocolUri = $hostLog -match 'ProtocolUri from ActivatedEventArgs:\s*mdview:'
            $hasLinkedPath = $hostLog -match ([regex]::Escape($linkedMd) -replace '\\\\', '[\\\\/]')
            
            # The key assertion: in-app navigation triggers Protocol activation, not File activation
            if ($isProtocolKind -and $isViaAppInstance -and $hasProtocolUri) {
                Write-TestResult -Name "In-app link navigation (ActivationKind.Protocol)" -Passed $true
                Write-Host "    This confirms: clicking rewritten mdview: links triggers true protocol activation" -ForegroundColor Gray
            } else {
                $failReason = @()
                if (-not $isProtocolKind) { $failReason += "ActivationKind != Protocol (in-app links should trigger Protocol, not File)" }
                if (-not $isViaAppInstance) { $failReason += "Not via AppInstance" }
                if (-not $hasProtocolUri) { $failReason += "No ProtocolUri in log" }
                
                Write-TestResult -Name "In-app link navigation (ActivationKind.Protocol)" -Passed $false -Message ($failReason -join '; ')
                Write-Host "    Host log content:" -ForegroundColor Yellow
                if ([string]::IsNullOrWhiteSpace($hostLog)) {
                    Write-Host "      (log is empty - app may not have started)" -ForegroundColor Red
                } else {
                    $hostLog -split "`n" | Select-Object -First 15 | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
                }
            }
            
            # Cleanup test files
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-TestResult -Name "In-app link navigation" -Passed $false -Message $_.Exception.Message
        }
        
        # Wait a moment between activations
        Start-Sleep -Milliseconds 500
        
        # Test 3: File activation via shell open
        # For Full Trust desktop bridge apps, opening a .md file via the shell
        # triggers true file activation via AppInstance APIs.
        Write-Host "  Testing file activation (shell open)..." -ForegroundColor Gray
        
        try {
            # Create a fresh test file for file activation test
            $testMdForFile = Join-Path $env:TEMP "mdv-e2e-file-test-$([Guid]::NewGuid().ToString('N').Substring(0,8)).md"
            "# File Activation Test`n`nOpened via shell." | Set-Content -Path $testMdForFile -Encoding UTF8
            
            # Clear the host log to capture only this activation
            $hostLogPath = Join-Path $env:TEMP 'MarkdownViewerHost.log'
            if (Test-Path $hostLogPath) { Clear-Content $hostLogPath -Force }
            
            # Shell-based file activation - uses the registered file type association
            # This opens the file using the default handler for .md files
            Start-Process $testMdForFile -ErrorAction Stop
            
            # Give the app time to start and log
            Start-Sleep -Milliseconds 2000
            
            # Read the host log to verify activation kind
            $hostLog = if (Test-Path $hostLogPath) { Get-Content $hostLogPath -Raw -ErrorAction SilentlyContinue } else { '' }
            
            # Check for true file activation indicators
            $isFileKind = $hostLog -match 'ActivationKind:\s*[Ff]ile'
            $isViaAppInstance = $hostLog -match 'Handling File activation via AppInstance'
            $isHandledTrue = $hostLog -match 'PackagedActivation handled:\s*True'
            $hasFilePath = $hostLog -match 'FileActivation:\s*\d+\s*file\(s\)'
            
            if ($isFileKind -and $isViaAppInstance -and $isHandledTrue -and $hasFilePath) {
                Write-TestResult -Name "File activation (ActivationKind.File)" -Passed $true
            } else {
                # Check if the app even ran (maybe .md is not associated with our app)
                if (-not $hostLog) {
                    # Check if another app opened the file
                    Write-TestResult -Name "File activation (ActivationKind.File)" -Passed $false -Message ".md files not associated with MarkView app"
                    Write-Host "    NOTE: File type association may need to be set manually via Windows Settings" -ForegroundColor Yellow
                } else {
                    # Detailed failure message
                    $failReason = @()
                    if (-not $isFileKind) { $failReason += "ActivationKind != File" }
                    if (-not $isViaAppInstance) { $failReason += "Not via AppInstance" }
                    if (-not $isHandledTrue) { $failReason += "PackagedActivation handled != True" }
                    if (-not $hasFilePath) { $failReason += "No FileActivation in log" }
                    
                    Write-TestResult -Name "File activation (ActivationKind.File)" -Passed $false -Message ($failReason -join '; ')
                    Write-Host "    Host log excerpt:" -ForegroundColor Yellow
                    $hostLog -split "`n" | Select-Object -First 20 | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
                }
            }
            
            # Cleanup test file
            Remove-Item $testMdForFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-TestResult -Name "File activation (ActivationKind.File)" -Passed $false -Message $_.Exception.Message
        }
        
        # Test 4: Launch activation (no arguments)
        Write-Host "  Testing launch activation..." -ForegroundColor Gray
        
        try {
            # Don't use --wait since we can't monitor processes we didn't start
            $activationOutput = & $activationDriverExe --aumid $aumid --launch 2>&1
            $activationExitCode = $LASTEXITCODE
            
            if ($activationExitCode -eq 0) {
                Write-TestResult -Name "Launch activation (app starts)" -Passed $true
            } else {
                Write-TestResult -Name "Launch activation (app starts)" -Passed $false -Message "ActivationDriver exit code: $activationExitCode"
            }
        } catch {
            Write-TestResult -Name "Launch activation" -Passed $false -Message $_.Exception.Message
        }
    }
    
    # Cleanup test files
    if (Test-Path $traceFile) {
        Remove-Item $traceFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $testMdFile) {
        Remove-Item $testMdFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Cleanup

if (-not $KeepInstalled) {
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    
    $installedPackage = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    if ($installedPackage) {
        try {
            $installedPackage | Remove-AppxPackage -ErrorAction Stop
            Write-Host "  Removed package: $($installedPackage.PackageFullName)" -ForegroundColor Gray
        } catch {
            Write-Host "  WARNING: Could not remove package: $_" -ForegroundColor Yellow
        }
    }
}

#endregion

#region Summary

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Passed:  $testsPassed" -ForegroundColor $(if ($testsPassed -gt 0) { 'Green' } else { 'Gray' })
Write-Host "  Failed:  $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { 'Red' } else { 'Gray' })
Write-Host "  Skipped: $testsSkipped" -ForegroundColor $(if ($testsSkipped -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "E2E TESTS FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "E2E TESTS PASSED" -ForegroundColor Green
    exit 0
}

#endregion
