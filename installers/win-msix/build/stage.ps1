# stage.ps1 - Staging script for MSIX packaging
# Prepares the package layout: Host EXE, engine payload, bundled pwsh, and assets.
# Called by MSBuild before WAP project packages the content.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration,
    
    [Parameter(Mandatory)]
    [ValidateSet('x64', 'ARM64')]
    [string]$Platform,
    
    [Parameter(Mandatory)]
    [string]$HostOutputDir,  # Path to host build output (contains MarkdownViewerHost.exe)
    
    [Parameter(Mandatory)]
    [string]$CoreDir,        # Path to src/core (engine payload)
    
    [Parameter(Mandatory)]
    [string]$StagingDir,     # Output directory for staged files
    
    [string]$WinDir,         # Path to src/win (optional, for MarkdownViewer.psm1)
    
    [switch]$SkipPwsh,       # Skip bundling pwsh (for dev testing)
    
    [switch]$ForceRegenAssets  # Force regeneration of PNG assets
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot

#region Helper Functions

function Get-PwshRuntime {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('x64', 'ARM64')]
        [string]$Arch
    )
    
    $configPath = Join-Path $ScriptRoot 'pwsh-versions.json'
    if (-not (Test-Path $configPath)) {
        Write-Warning "pwsh-versions.json not found at: $configPath"
        return $null
    }
    
    # Read pinned version configuration
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $version = $config.version
    $archLower = $Arch.ToLower()
    $archConfig = $config.archives.$archLower
    
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
    
    $zipName = "PowerShell-$version-win-$archLower.zip"
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

function New-AssetFromIco {
    param(
        [string]$IcoPath,
        [string]$DestPath,
        [int]$Width,
        [int]$Height
    )
    
    $magick = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $magick) {
        return $false
    }
    
    $size = "${Width}x${Height}"
    # Use [0] to select only the first (largest) frame from the ICO to avoid multiple output files
    & magick "${IcoPath}[0]" -resize $size -background transparent -gravity center -extent $size $DestPath 2>$null
    return ($LASTEXITCODE -eq 0)
}

#endregion

#region Main Staging Logic

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "MSIX Staging: $Platform $Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$appDir = Join-Path $StagingDir 'app'
$pwshDir = Join-Path $StagingDir 'pwsh'
$assetsDir = Join-Path $StagingDir 'Assets'

# Step 1: Clean staging directory
Write-Host ""
Write-Host "[1/5] Cleaning staging directory..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
New-Item -ItemType Directory -Path $appDir -Force | Out-Null
New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
if (-not $SkipPwsh) {
    New-Item -ItemType Directory -Path $pwshDir -Force | Out-Null
}
Write-Host "  Staging directory prepared: $StagingDir" -ForegroundColor Green

# Step 2: Copy host output to staging root
Write-Host ""
Write-Host "[2/5] Copying host output..." -ForegroundColor Yellow
$hostFiles = @(
    'MarkdownViewerHost.exe',
    'MarkdownViewerHost.dll',
    'MarkdownViewerHost.runtimeconfig.json',
    'MarkdownViewerHost.deps.json'
)
foreach ($file in $hostFiles) {
    $srcPath = Join-Path $HostOutputDir $file
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $StagingDir
        Write-Host "  Copied: $file" -ForegroundColor Gray
    }
    else {
        Write-Warning "  Host file not found: $srcPath"
    }
}
Write-Host "  Host output copied" -ForegroundColor Green

# Step 3: Copy engine payload to app\
Write-Host ""
Write-Host "[3/5] Copying engine payload..." -ForegroundColor Yellow
$engineFiles = @(
    'Open-Markdown.ps1',
    'script.js',
    'style.css',
    'highlight.min.js',
    'highlight-theme.css'
)
foreach ($file in $engineFiles) {
    $srcPath = Join-Path $CoreDir $file
    if (Test-Path $srcPath) {
        Copy-Item $srcPath $appDir
        Write-Host "  Copied: $file" -ForegroundColor Gray
    }
    else {
        Write-Warning "  Engine file not found: $srcPath"
    }
}

# Copy icons directory
$iconsDir = Join-Path $CoreDir 'icons'
if (Test-Path $iconsDir) {
    Copy-Item $iconsDir (Join-Path $appDir 'icons') -Recurse
    Write-Host "  Copied: icons/" -ForegroundColor Gray
}

# Copy MarkdownViewer.psm1 from WinDir if provided
if ($WinDir -and (Test-Path (Join-Path $WinDir 'MarkdownViewer.psm1'))) {
    Copy-Item (Join-Path $WinDir 'MarkdownViewer.psm1') $appDir
    Write-Host "  Copied: MarkdownViewer.psm1" -ForegroundColor Gray
}

Write-Host "  Engine payload copied to app\" -ForegroundColor Green

# Step 4: Download and unpack pwsh
Write-Host ""
Write-Host "[4/5] Bundling PowerShell runtime..." -ForegroundColor Yellow
if ($SkipPwsh) {
    Write-Host "  Skipped (SkipPwsh specified)" -ForegroundColor Yellow
}
else {
    $pwshZip = Get-PwshRuntime -Arch $Platform
    if ($pwshZip -and (Test-Path $pwshZip)) {
        Write-Host "  Extracting to pwsh\..." -ForegroundColor Yellow
        Expand-Archive -Path $pwshZip -DestinationPath $pwshDir -Force
        Write-Host "  PowerShell runtime bundled" -ForegroundColor Green
    }
    else {
        # Fallback: Copy from system pwsh
        $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($systemPwsh) {
            $pwshInstallDir = Split-Path -Parent $systemPwsh.Source
            Write-Host "  Copying from system pwsh: $pwshInstallDir" -ForegroundColor Yellow
            Write-Host "  Note: System pwsh may not match target architecture ($Platform)" -ForegroundColor Yellow
            Copy-Item "$pwshInstallDir\*" $pwshDir -Recurse -Force
            Write-Host "  PowerShell runtime copied from system" -ForegroundColor Green
        }
        else {
            Write-Warning "  PowerShell 7 not found. Package will require system pwsh."
        }
    }
}

# Step 5: Generate MSIX assets
Write-Host ""
Write-Host "[5/5] Generating MSIX assets..." -ForegroundColor Yellow
$icoPath = Join-Path $CoreDir 'icons\markdown.ico'
$requiredAssets = @(
    @{ Name = 'StoreLogo.png'; Width = 50; Height = 50 },
    @{ Name = 'Square44x44Logo.png'; Width = 44; Height = 44 },
    @{ Name = 'Square150x150Logo.png'; Width = 150; Height = 150 },
    @{ Name = 'Wide310x150Logo.png'; Width = 310; Height = 150 }
)

$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    Write-Warning "  ImageMagick not found. Creating solid-color placeholder assets."
    Add-Type -AssemblyName System.Drawing
    foreach ($asset in $requiredAssets) {
        $destPath = Join-Path $assetsDir $asset.Name
        $bmp = New-Object System.Drawing.Bitmap($asset.Width, $asset.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        # Dark gray placeholder (45, 45, 45)
        $g.Clear([System.Drawing.Color]::FromArgb(45, 45, 45))
        $g.Dispose()
        $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Host "  Created placeholder: $($asset.Name) ($($asset.Width)x$($asset.Height))" -ForegroundColor Gray
    }
}
elseif (-not (Test-Path $icoPath)) {
    Write-Warning "  Source ICO not found: $icoPath"
}
else {
    foreach ($asset in $requiredAssets) {
        $destPath = Join-Path $assetsDir $asset.Name
        if ($ForceRegenAssets -or -not (Test-Path $destPath)) {
            if (New-AssetFromIco -IcoPath $icoPath -DestPath $destPath -Width $asset.Width -Height $asset.Height) {
                Write-Host "  Generated: $($asset.Name)" -ForegroundColor Gray
            }
            else {
                Write-Warning "  Failed to generate: $($asset.Name)"
            }
        }
        else {
            Write-Host "  Exists: $($asset.Name)" -ForegroundColor Gray
        }
    }
}
Write-Host "  Assets prepared" -ForegroundColor Green

#endregion

#region Validation

Write-Host ""
Write-Host "Validating staged content..." -ForegroundColor Yellow

$validationErrors = @()

# Required files at staging root
if (-not (Test-Path (Join-Path $StagingDir 'MarkdownViewerHost.exe'))) {
    $validationErrors += "MarkdownViewerHost.exe not found in staging root"
}

# Required files in app\
if (-not (Test-Path (Join-Path $appDir 'Open-Markdown.ps1'))) {
    $validationErrors += "app\Open-Markdown.ps1 not found"
}

# Required pwsh\pwsh.exe (unless skipped)
if (-not $SkipPwsh -and -not (Test-Path (Join-Path $pwshDir 'pwsh.exe'))) {
    $validationErrors += "pwsh\pwsh.exe not found (use -SkipPwsh to skip bundling)"
}

# Required assets
foreach ($asset in $requiredAssets) {
    if (-not (Test-Path (Join-Path $assetsDir $asset.Name))) {
        $validationErrors += "Assets\$($asset.Name) not found"
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host ""
    Write-Error "Staging validation failed:`n  - $($validationErrors -join "`n  - ")"
    exit 1
}

Write-Host "  All required files present" -ForegroundColor Green

#endregion

Write-Host ""
Write-Host "Staging complete: $StagingDir" -ForegroundColor Cyan
Write-Host ""
