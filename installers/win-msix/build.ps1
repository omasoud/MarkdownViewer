# build.ps1 - MSIX packaging script for Markdown Viewer
# Stages Host EXE, bundled pwsh, and engine payload, then creates MSIX package.
# Supports x64 and ARM64 architectures, and can create MSIX bundles.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture = 'x64',
    
    [string]$Version = '1.0.0.0',
    
    [string]$PwshZipPath = '',  # Optional: path to PowerShell zip for bundling
    
    [switch]$SkipBuild,
    
    [switch]$SkipPwsh,  # Skip bundling pwsh (for dev testing with system pwsh)
    
    [switch]$BuildAll,  # Build both x64 and arm64
    
    [switch]$Bundle,    # Create MSIX bundle from x64 and arm64 packages
    
    [switch]$Sign,      # Sign the MSIX package(s) using sign.ps1
    
    [switch]$DownloadPwsh,  # Download pinned PowerShell version instead of using system pwsh
    
    [switch]$RegenerateAssets  # Force regeneration of MSIX PNG assets from ICO
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$HostProjectDir = Join-Path $RepoRoot 'src\host\MarkdownViewerHost'
$CoreDir = Join-Path $RepoRoot 'src\core'
$WinDir = Join-Path $RepoRoot 'src\win'
$ManifestPath = Join-Path $ScriptRoot 'Package.appxmanifest'
$OutputDir = Join-Path $ScriptRoot 'output'

# Find makeappx.exe
function Find-MakeAppx {
    $makeAppxCmd = Get-Command makeappx.exe -ErrorAction SilentlyContinue
    if ($makeAppxCmd) {
        return $makeAppxCmd.Source
    }
    
    # Try to find in Windows SDK
    $sdkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\makeappx.exe"
    )
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Get pinned PowerShell runtime for bundling
# Downloads from GitHub releases, verifies SHA256, and caches locally
function Get-PwshRuntime {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('x64', 'arm64')]
        [string]$Arch
    )
    
    $configPath = Join-Path $ScriptRoot 'build\pwsh-versions.json'
    if (-not (Test-Path $configPath)) {
        Write-Warning "pwsh-versions.json not found at: $configPath"
        return $null
    }
    
    # Read pinned version configuration
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $version = $config.version
    $archConfig = $config.archives.$Arch
    
    if (-not $archConfig) {
        Write-Warning "No configuration found for architecture: $Arch"
        return $null
    }
    
    $url = $archConfig.url
    $expectedHash = $archConfig.sha256
    
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $expectedHash -match '^0+$') {
        Write-Warning "SHA256 hash not configured for $Arch. Update pwsh-versions.json with correct hash."
        Write-Warning "To get the hash, download manually and run: Get-FileHash -Algorithm SHA256 <file>"
        return $null
    }
    
    # Cache directory
    $cacheDir = Join-Path $env:TEMP 'MarkdownViewer-BuildCache'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    $zipName = "PowerShell-$version-win-$Arch.zip"
    $cachedZip = Join-Path $cacheDir $zipName
    
    # Check if already cached and valid
    if (Test-Path $cachedZip) {
        Write-Host "  Verifying cached PowerShell $version ($Arch)..." -ForegroundColor Yellow
        $actualHash = (Get-FileHash -Path $cachedZip -Algorithm SHA256).Hash
        if ($actualHash -eq $expectedHash) {
            Write-Host "  Using cached: $cachedZip" -ForegroundColor Green
            return $cachedZip
        }
        else {
            Write-Warning "  Cached file hash mismatch. Re-downloading."
            Remove-Item $cachedZip -Force
        }
    }
    
    # Download
    Write-Host "  Downloading PowerShell $version ($Arch)..." -ForegroundColor Yellow
    Write-Host "  URL: $url"
    
    try {
        $progressPreference = 'SilentlyContinue'  # Faster downloads
        Invoke-WebRequest -Uri $url -OutFile $cachedZip -UseBasicParsing
        $progressPreference = 'Continue'
    }
    catch {
        Write-Warning "  Download failed: $_"
        if (Test-Path $cachedZip) { Remove-Item $cachedZip -Force }
        return $null
    }
    
    # Verify hash
    Write-Host "  Verifying integrity..." -ForegroundColor Yellow
    $actualHash = (Get-FileHash -Path $cachedZip -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        Write-Error "SHA256 hash mismatch!`n  Expected: $expectedHash`n  Actual:   $actualHash"
        Remove-Item $cachedZip -Force
        return $null
    }
    
    Write-Host "  Downloaded and verified: $cachedZip" -ForegroundColor Green
    return $cachedZip
}

# Build a single architecture MSIX
function Build-SingleArchMsix {
    param(
        [string]$Arch,
        [string]$Config,
        [string]$Ver,
        [string]$PwshZip,
        [switch]$NoBuild,
        [switch]$NoPwsh,
        [switch]$UsePinnedPwsh,
        [switch]$ForceRegenAssets
    )
    
    $archStageDir = Join-Path $OutputDir "stage-$Arch"
    $appDir = Join-Path $archStageDir 'app'
    $pwshDir = Join-Path $archStageDir 'pwsh'
    $assetsDir = Join-Path $archStageDir 'Assets'
    
    Write-Host ""
    Write-Host "Building $Arch MSIX..." -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    # Clean and create output directories
    Write-Host "Preparing directories for $Arch..." -ForegroundColor Yellow
    if (Test-Path $archStageDir) {
        Remove-Item $archStageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $archStageDir -Force | Out-Null
    New-Item -ItemType Directory -Path $appDir -Force | Out-Null
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    
    if (-not $NoPwsh) {
        New-Item -ItemType Directory -Path $pwshDir -Force | Out-Null
    }
    
    # Build Host EXE
    if (-not $NoBuild) {
        Write-Host "Building Host EXE for $Arch..." -ForegroundColor Yellow
        $rid = "win-$Arch"
        $hostTempDir = Join-Path $archStageDir 'host-temp'
        
        Push-Location $HostProjectDir
        try {
            dotnet publish -c $Config -r $rid --self-contained false -o $hostTempDir
            if ($LASTEXITCODE -ne 0) {
                throw "dotnet publish failed for $Arch with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
        
        # Copy Host EXE to stage root
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.exe') $archStageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.dll') $archStageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.runtimeconfig.json') $archStageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.deps.json') $archStageDir
        
        # Clean up temp
        Remove-Item $hostTempDir -Recurse -Force
        
        Write-Host "Host EXE built for $Arch" -ForegroundColor Green
    }
    
    # Copy engine files
    Write-Host "Staging engine files..." -ForegroundColor Yellow
    Copy-Item (Join-Path $CoreDir 'Open-Markdown.ps1') $appDir
    Copy-Item (Join-Path $CoreDir 'script.js') $appDir
    Copy-Item (Join-Path $CoreDir 'style.css') $appDir
    Copy-Item (Join-Path $CoreDir 'highlight.min.js') $appDir
    Copy-Item (Join-Path $CoreDir 'highlight-theme.css') $appDir
    Copy-Item (Join-Path $CoreDir 'icons\markdown.ico') $appDir
    Copy-Item (Join-Path $WinDir 'MarkdownViewer.psm1') $appDir
    Write-Host "Engine files staged" -ForegroundColor Green
    
    # Bundle PowerShell
    if (-not $NoPwsh) {
        Write-Host "Bundling PowerShell runtime for $Arch..." -ForegroundColor Yellow
        
        # Determine which PowerShell zip to use
        $archPwshZip = $null
        
        # Priority 1: Explicit path provided
        if ($PwshZip -and (Test-Path $PwshZip)) {
            $archPwshZip = $PwshZip
            Write-Host "  Using provided PowerShell: $archPwshZip"
        }
        # Priority 2: Download pinned version
        elseif ($UsePinnedPwsh) {
            $archPwshZip = Get-PwshRuntime -Arch $Arch
            if (-not $archPwshZip) {
                Write-Warning "  Failed to get pinned PowerShell. Falling back to system pwsh."
            }
        }
        
        if ($archPwshZip -and (Test-Path $archPwshZip)) {
            Expand-Archive -Path $archPwshZip -DestinationPath $pwshDir -Force
        }
        else {
            # Fallback: Copy from system pwsh (only works for matching architecture)
            $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($systemPwsh) {
                $pwshInstallDir = Split-Path -Parent $systemPwsh.Source
                Write-Host "  Copying from system pwsh: $pwshInstallDir"
                Write-Host "  Note: System pwsh may not match target architecture ($Arch)" -ForegroundColor Yellow
                Copy-Item "$pwshInstallDir\*" $pwshDir -Recurse -Force
            }
            else {
                Write-Warning "PowerShell 7 not found. Package will require system pwsh."
            }
        }
        
        if (Test-Path (Join-Path $pwshDir 'pwsh.exe')) {
            Write-Host "PowerShell runtime bundled" -ForegroundColor Green
        }
    }
    
    # Copy/generate assets
    Write-Host "Preparing MSIX assets..." -ForegroundColor Yellow
    # Assets are generated from ICO on-demand; no pre-made source assets folder needed
    $requiredAssets = @(
        @{ Name = 'StoreLogo.png'; Width = 50; Height = 50 },
        @{ Name = 'Square44x44Logo.png'; Width = 44; Height = 44 },
        @{ Name = 'Square150x150Logo.png'; Width = 150; Height = 150 },
        @{ Name = 'Wide310x150Logo.png'; Width = 310; Height = 150 }
    )
    
    # Determine which assets need to be generated
    $assetsToGenerate = @()
    foreach ($asset in $requiredAssets) {
        $destPath = Join-Path $assetsDir $asset.Name
        
        if ($ForceRegenAssets) {
            # Force regeneration
            $assetsToGenerate += $asset
        }
        elseif (-not (Test-Path $destPath)) {
            # Asset missing in staging directory
            $assetsToGenerate += $asset
        }
        # else: asset already exists in staging, skip
    }
    
    # Generate assets (missing or forced)
    if ($assetsToGenerate.Count -gt 0) {
        $magick = Get-Command magick -ErrorAction SilentlyContinue
        $icoPath = Join-Path $CoreDir 'icons\markdown.ico'
        
        if ($magick -and (Test-Path $icoPath)) {
            $action = if ($ForceRegenAssets) { "Regenerating" } else { "Creating missing" }
            Write-Host "  $action assets from ICO using ImageMagick..." -ForegroundColor Yellow
            foreach ($asset in $assetsToGenerate) {
                $destPath = Join-Path $assetsDir $asset.Name
                $size = "$($asset.Width)x$($asset.Height)"
                & magick $icoPath -resize $size -background transparent -gravity center -extent $size $destPath 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Generated: $($asset.Name)" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Warning "ImageMagick not found. Creating placeholder assets."
            $minimalPng = [Convert]::FromBase64String(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
            )
            foreach ($asset in $assetsToGenerate) {
                $destPath = Join-Path $assetsDir $asset.Name
                [System.IO.File]::WriteAllBytes($destPath, $minimalPng)
            }
        }
    }
    Write-Host "Assets prepared" -ForegroundColor Green
    
    # Prepare manifest
    Write-Host "Preparing AppxManifest.xml..." -ForegroundColor Yellow
    $manifestSource = $ManifestPath
    $manifestDest = Join-Path $archStageDir 'AppxManifest.xml'
    
    $manifest = Get-Content $manifestSource -Raw
    $manifest = $manifest -replace '(<Identity[^>]*Version=")[\d\.]+(")', "`${1}$Ver`$2"
    $manifest = $manifest -replace 'ProcessorArchitecture="\w+"', "ProcessorArchitecture=`"$Arch`""
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($manifestDest, $manifest, $utf8NoBom)
    Write-Host "Manifest prepared" -ForegroundColor Green
    
    # Create MSIX
    $msixPath = Join-Path $OutputDir "MarkdownViewer_${Ver}_$Arch.msix"
    $makeAppxPath = Find-MakeAppx
    
    if ($makeAppxPath) {
        Write-Host "Creating MSIX package..." -ForegroundColor Yellow
        Write-Host "  Using makeappx: $makeAppxPath"
        & $makeAppxPath pack /d $archStageDir /p $msixPath /o
        if ($LASTEXITCODE -eq 0) {
            Write-Host "MSIX package created: $msixPath" -ForegroundColor Green
            return $msixPath
        }
        else {
            throw "makeappx.exe failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Warning "makeappx.exe not found. Staged files at: $archStageDir"
        return $null
    }
}

# Create MSIX bundle from multiple architecture packages
function New-MsixBundle {
    param(
        [string[]]$MsixPaths,
        [string]$Ver
    )
    
    $makeAppxPath = Find-MakeAppx
    if (-not $makeAppxPath) {
        Write-Warning "makeappx.exe not found. Cannot create bundle."
        return $null
    }
    
    Write-Host ""
    Write-Host "Creating MSIX Bundle..." -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    
    $bundlePath = Join-Path $OutputDir "MarkdownViewer_$Ver.msixbundle"
    
    # Create a mapping file for the bundle
    $bundleDir = Join-Path $OutputDir 'bundle-temp'
    if (Test-Path $bundleDir) {
        Remove-Item $bundleDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
    
    # Copy MSIX files to bundle directory
    foreach ($msix in $MsixPaths) {
        if ($msix -and (Test-Path $msix)) {
            Copy-Item $msix $bundleDir
        }
    }
    
    Write-Host "  Bundling packages: $($MsixPaths -join ', ')"
    & $makeAppxPath bundle /d $bundleDir /p $bundlePath /o
    
    # Clean up
    Remove-Item $bundleDir -Recurse -Force
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MSIX bundle created: $bundlePath" -ForegroundColor Green
        return $bundlePath
    }
    else {
        Write-Warning "Bundle creation failed with exit code $LASTEXITCODE"
        return $null
    }
}

# Main execution
Write-Host "Markdown Viewer MSIX Build Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration"
Write-Host "Version:       $Version"
if ($BuildAll -or $Bundle) {
    Write-Host "Architectures: x64, arm64"
}
else {
    Write-Host "Architecture:  $Architecture"
}
Write-Host ""

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$createdPackages = @()

if ($BuildAll -or $Bundle) {
    # Build both architectures
    $x64Msix = Build-SingleArchMsix -Arch 'x64' -Config $Configuration -Ver $Version -PwshZip $PwshZipPath -NoBuild:$SkipBuild -NoPwsh:$SkipPwsh -UsePinnedPwsh:$DownloadPwsh -ForceRegenAssets:$RegenerateAssets
    $arm64Msix = Build-SingleArchMsix -Arch 'arm64' -Config $Configuration -Ver $Version -PwshZip $PwshZipPath -NoBuild:$SkipBuild -NoPwsh:$SkipPwsh -UsePinnedPwsh:$DownloadPwsh -ForceRegenAssets:$RegenerateAssets
    
    if ($x64Msix) { $createdPackages += $x64Msix }
    if ($arm64Msix) { $createdPackages += $arm64Msix }
    
    if ($Bundle -and $x64Msix -and $arm64Msix) {
        $bundlePath = New-MsixBundle -MsixPaths @($x64Msix, $arm64Msix) -Ver $Version
        if ($bundlePath) { $createdPackages += $bundlePath }
    }
}
else {
    # Build single architecture (legacy behavior for backward compatibility)
    # Use the old stage directory location for single arch builds
    $StageDir = Join-Path $OutputDir 'stage'
    $AppDir = Join-Path $StageDir 'app'
    $PwshDir = Join-Path $StageDir 'pwsh'
    $AssetsDir = Join-Path $StageDir 'Assets'
    
    # Clean and create output directories
    Write-Host "Preparing output directories..." -ForegroundColor Yellow
    if (Test-Path $StageDir) {
        Remove-Item $StageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $StageDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
    
    if (-not $SkipPwsh) {
        New-Item -ItemType Directory -Path $PwshDir -Force | Out-Null
    }
    
    # Build Host EXE
    if (-not $SkipBuild) {
        Write-Host "Building Host EXE..." -ForegroundColor Yellow
        $rid = "win-$Architecture"
        
        Push-Location $HostProjectDir
        try {
            dotnet publish -c $Configuration -r $rid --self-contained false -o (Join-Path $StageDir 'host-temp')
            if ($LASTEXITCODE -ne 0) {
                throw "dotnet publish failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
        
        # Copy Host EXE to stage root
        $hostTempDir = Join-Path $StageDir 'host-temp'
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.exe') $StageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.dll') $StageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.runtimeconfig.json') $StageDir
        Copy-Item (Join-Path $hostTempDir 'MarkdownViewerHost.deps.json') $StageDir
        
        # Clean up temp
        Remove-Item $hostTempDir -Recurse -Force
        
        Write-Host "Host EXE built successfully" -ForegroundColor Green
    }
    
    # Copy engine files to app directory
    Write-Host "Staging engine files..." -ForegroundColor Yellow
    Copy-Item (Join-Path $CoreDir 'Open-Markdown.ps1') $AppDir
    Copy-Item (Join-Path $CoreDir 'script.js') $AppDir
    Copy-Item (Join-Path $CoreDir 'style.css') $AppDir
    Copy-Item (Join-Path $CoreDir 'highlight.min.js') $AppDir
    Copy-Item (Join-Path $CoreDir 'highlight-theme.css') $AppDir
    Copy-Item (Join-Path $CoreDir 'icons\markdown.ico') $AppDir
    Copy-Item (Join-Path $WinDir 'MarkdownViewer.psm1') $AppDir
    Write-Host "Engine files staged" -ForegroundColor Green
    
    # Bundle PowerShell (if not skipped)
    if (-not $SkipPwsh) {
        Write-Host "Bundling PowerShell runtime..." -ForegroundColor Yellow
        
        # Determine which PowerShell zip to use
        $pwshZipToUse = $null
        
        # Priority 1: Explicit path provided
        if ($PwshZipPath -and (Test-Path $PwshZipPath)) {
            $pwshZipToUse = $PwshZipPath
            Write-Host "  Using provided PowerShell: $pwshZipToUse"
        }
        # Priority 2: Download pinned version
        elseif ($DownloadPwsh) {
            $pwshZipToUse = Get-PwshRuntime -Arch $Architecture
            if (-not $pwshZipToUse) {
                Write-Warning "  Failed to get pinned PowerShell. Falling back to system pwsh."
            }
        }
        
        if ($pwshZipToUse -and (Test-Path $pwshZipToUse)) {
            Expand-Archive -Path $pwshZipToUse -DestinationPath $PwshDir -Force
        }
        else {
            # Fallback: Copy from system pwsh
            $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($systemPwsh) {
                $pwshInstallDir = Split-Path -Parent $systemPwsh.Source
                Write-Host "  Copying from system pwsh: $pwshInstallDir"
                Copy-Item "$pwshInstallDir\*" $PwshDir -Recurse -Force
            }
            else {
                Write-Warning "PowerShell 7 not found. Package will require system pwsh."
            }
        }
        
        if (Test-Path (Join-Path $PwshDir 'pwsh.exe')) {
            Write-Host "PowerShell runtime bundled" -ForegroundColor Green
        }
    }
    
    # Copy MSIX assets
    Write-Host "Copying MSIX assets..." -ForegroundColor Yellow
    $sourceAssets = Join-Path $PackageDir 'Assets'
    $requiredAssets = @(
        @{ Name = 'StoreLogo.png'; Width = 50; Height = 50 },
        @{ Name = 'Square44x44Logo.png'; Width = 44; Height = 44 },
        @{ Name = 'Square150x150Logo.png'; Width = 150; Height = 150 },
        @{ Name = 'Wide310x150Logo.png'; Width = 310; Height = 150 }
    )
    
    $assetsToGenerate = @()
    foreach ($asset in $requiredAssets) {
        $sourcePath = Join-Path $sourceAssets $asset.Name
        $destPath = Join-Path $AssetsDir $asset.Name
        
        if ($RegenerateAssets) {
            # Force regeneration
            $assetsToGenerate += $asset
        }
        elseif (Test-Path $sourcePath) {
            Copy-Item $sourcePath $destPath -Force
        }
        else {
            $assetsToGenerate += $asset
        }
    }
    
    if ($assetsToGenerate.Count -gt 0) {
        $magick = Get-Command magick -ErrorAction SilentlyContinue
        $icoPath = Join-Path $CoreDir 'icons\markdown.ico'
        
        if ($magick -and (Test-Path $icoPath)) {
            $action = if ($RegenerateAssets) { "Regenerating" } else { "Creating missing" }
            Write-Host "  $action assets from ICO using ImageMagick..." -ForegroundColor Yellow
            foreach ($asset in $assetsToGenerate) {
                $destPath = Join-Path $AssetsDir $asset.Name
                $size = "$($asset.Width)x$($asset.Height)"
                & magick $icoPath -resize $size -background transparent -gravity center -extent $size $destPath 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Generated: $($asset.Name)" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Warning "ImageMagick not found. Creating placeholder assets."
            $minimalPng = [Convert]::FromBase64String(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
            )
            foreach ($asset in $assetsToGenerate) {
                $destPath = Join-Path $AssetsDir $asset.Name
                [System.IO.File]::WriteAllBytes($destPath, $minimalPng)
            }
        }
    }
    Write-Host "Assets prepared" -ForegroundColor Green
    
    # Copy and update AppxManifest.xml
    Write-Host "Preparing AppxManifest.xml..." -ForegroundColor Yellow
    $manifestSource = Join-Path $PackageDir 'AppxManifest.xml'
    $manifestDest = Join-Path $StageDir 'AppxManifest.xml'
    
    $manifest = Get-Content $manifestSource -Raw
    $manifest = $manifest -replace '(<Identity[^>]*Version=")[\d\.]+(")', "`${1}$Version`$2"
    $manifest = $manifest -replace 'ProcessorArchitecture="\w+"', "ProcessorArchitecture=`"$Architecture`""
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($manifestDest, $manifest, $utf8NoBom)
    Write-Host "Manifest prepared" -ForegroundColor Green
    
    # Create MSIX package
    Write-Host "Creating MSIX package..." -ForegroundColor Yellow
    $msixPath = Join-Path $OutputDir "MarkdownViewer_${Version}_$Architecture.msix"
    $makeAppxPath = Find-MakeAppx
    
    if ($makeAppxPath) {
        Write-Host "  Using makeappx: $makeAppxPath"
        & $makeAppxPath pack /d $StageDir /p $msixPath /o
        if ($LASTEXITCODE -eq 0) {
            Write-Host "MSIX package created: $msixPath" -ForegroundColor Green
            $createdPackages += $msixPath
        }
        else {
            Write-Error "makeappx.exe failed with exit code $LASTEXITCODE"
        }
    }
    else {
        Write-Warning "makeappx.exe not found. Install Windows SDK to create MSIX packages."
        Write-Host "Staged files are available at: $StageDir"
    }
}

# Sign packages if requested
if ($Sign -and $createdPackages.Count -gt 0) {
    $signScript = Join-Path $ScriptRoot 'sign.ps1'
    if (Test-Path $signScript) {
        Write-Host ""
        Write-Host "Signing packages..." -ForegroundColor Yellow
        foreach ($pkg in $createdPackages) {
            if ($pkg -and (Test-Path $pkg)) {
                & $signScript -MsixPath $pkg -Sign
            }
        }
    }
    else {
        Write-Warning "sign.ps1 not found. Skipping signing."
    }
}

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDir"
if ($createdPackages.Count -gt 0) {
    Write-Host "Created packages:" -ForegroundColor Green
    foreach ($pkg in $createdPackages) {
        Write-Host "  - $pkg"
    }
}
