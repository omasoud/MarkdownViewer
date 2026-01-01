# build.ps1 - MSIX packaging script for Markdown Viewer
# Stages Host EXE, bundled pwsh, and engine payload, then creates MSIX package.

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
    
    [switch]$SkipPwsh  # Skip bundling pwsh (for dev testing with system pwsh)
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$HostProjectDir = Join-Path $RepoRoot 'src\host\MarkdownViewerHost'
$CoreDir = Join-Path $RepoRoot 'src\core'
$WinDir = Join-Path $RepoRoot 'src\win'
$PackageDir = Join-Path $ScriptRoot 'Package'
$OutputDir = Join-Path $ScriptRoot 'output'

# Stage directories inside Package
$StageDir = Join-Path $OutputDir 'stage'
$AppDir = Join-Path $StageDir 'app'
$PwshDir = Join-Path $StageDir 'pwsh'
$AssetsDir = Join-Path $StageDir 'Assets'

Write-Host "Markdown Viewer MSIX Build Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration"
Write-Host "Architecture:  $Architecture"
Write-Host "Version:       $Version"
Write-Host ""

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

# Copy Windows-specific module
Copy-Item (Join-Path $WinDir 'MarkdownViewer.psm1') $AppDir

Write-Host "Engine files staged" -ForegroundColor Green

# Bundle PowerShell (if not skipped)
if (-not $SkipPwsh) {
    Write-Host "Bundling PowerShell runtime..." -ForegroundColor Yellow
    
    if ($PwshZipPath -and (Test-Path $PwshZipPath)) {
        # Use provided PowerShell zip
        Write-Host "  Using provided PowerShell: $PwshZipPath"
        Expand-Archive -Path $PwshZipPath -DestinationPath $PwshDir -Force
    }
    else {
        # Copy from system pwsh installation
        $systemPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($systemPwsh) {
            $pwshInstallDir = Split-Path -Parent $systemPwsh.Source
            Write-Host "  Copying from system pwsh: $pwshInstallDir"
            Copy-Item "$pwshInstallDir\*" $PwshDir -Recurse -Force
        }
        else {
            Write-Warning "PowerShell 7 not found. Package will require system pwsh."
            Write-Warning "For production MSIX, provide -PwshZipPath with PowerShell distribution."
        }
    }
    
    if (Test-Path (Join-Path $PwshDir 'pwsh.exe')) {
        Write-Host "PowerShell runtime bundled" -ForegroundColor Green
    }
}

# Copy MSIX assets
Write-Host "Copying MSIX assets..." -ForegroundColor Yellow
$sourceAssets = Join-Path $PackageDir 'Assets'

# Check if real assets exist, otherwise try to create from ICO or use external tool
$requiredAssets = @(
    @{ Name = 'StoreLogo.png'; Width = 50; Height = 50 },
    @{ Name = 'Square44x44Logo.png'; Width = 44; Height = 44 },
    @{ Name = 'Square150x150Logo.png'; Width = 150; Height = 150 },
    @{ Name = 'Wide310x150Logo.png'; Width = 310; Height = 150 }
)

$hasRealAssets = $false
$missingAssets = @()

foreach ($asset in $requiredAssets) {
    $sourcePath = Join-Path $sourceAssets $asset.Name
    $destPath = Join-Path $AssetsDir $asset.Name
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath -Force
        $hasRealAssets = $true
    }
    else {
        $missingAssets += $asset
    }
}

# If we have missing assets, try to create them using ImageMagick (if available)
if ($missingAssets.Count -gt 0) {
    $magick = Get-Command magick -ErrorAction SilentlyContinue
    $icoPath = Join-Path $CoreDir 'icons\markdown.ico'
    
    if ($magick -and (Test-Path $icoPath)) {
        Write-Host "  Creating assets from ICO using ImageMagick..." -ForegroundColor Yellow
        foreach ($asset in $missingAssets) {
            $destPath = Join-Path $AssetsDir $asset.Name
            $size = "$($asset.Width)x$($asset.Height)"
            & magick $icoPath -resize $size -background transparent -gravity center -extent $size $destPath 2>$null
            if (-not (Test-Path $destPath)) {
                Write-Warning "Failed to create $($asset.Name)"
            }
        }
    }
    else {
        # Create minimal valid PNGs as placeholders using pure PowerShell
        Write-Warning "ImageMagick not found. Creating minimal placeholder assets."
        Write-Warning "For production, install ImageMagick or manually create PNG assets."
        
        # Minimal valid 1x1 transparent PNG (smallest valid PNG)
        # This is a pre-computed valid PNG file
        $minimalPng = [Convert]::FromBase64String(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
        )
        
        foreach ($asset in $missingAssets) {
            $destPath = Join-Path $AssetsDir $asset.Name
            [System.IO.File]::WriteAllBytes($destPath, $minimalPng)
        }
    }
}

if ($hasRealAssets -and $missingAssets.Count -eq 0) {
    Write-Host "Assets copied" -ForegroundColor Green
}
elseif ($missingAssets.Count -gt 0) {
    Write-Host "Placeholder assets created (some assets were missing)" -ForegroundColor Yellow
}
else {
    Write-Host "Assets prepared" -ForegroundColor Green
}

# Copy and update AppxManifest.xml
Write-Host "Preparing AppxManifest.xml..." -ForegroundColor Yellow
$manifestSource = Join-Path $PackageDir 'AppxManifest.xml'
$manifestDest = Join-Path $StageDir 'AppxManifest.xml'

$manifest = Get-Content $manifestSource -Raw

# Update version in Identity element only (not the XML declaration)
# Match Version="x.x.x.x" pattern with 4 version parts
$manifest = $manifest -replace '(<Identity[^>]*Version=")[\d\.]+(")', "`${1}$Version`$2"

# Update architecture
$archMap = @{
    'x64' = 'x64'
    'arm64' = 'arm64'
}
$manifest = $manifest -replace 'ProcessorArchitecture="\w+"', "ProcessorArchitecture=`"$($archMap[$Architecture])`""

# Write without BOM (UTF8 without BOM is required for AppxManifest.xml)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestDest, $manifest, $utf8NoBom)
Write-Host "Manifest prepared" -ForegroundColor Green

# Create MSIX package
Write-Host "Creating MSIX package..." -ForegroundColor Yellow
$msixPath = Join-Path $OutputDir "MarkdownViewer_${Version}_$Architecture.msix"

# Check for makeappx.exe
$makeAppxPath = $null
$makeAppxCmd = Get-Command makeappx.exe -ErrorAction SilentlyContinue
if ($makeAppxCmd) {
    $makeAppxPath = $makeAppxCmd.Source
}
else {
    # Try to find in Windows SDK
    $sdkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\makeappx.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\makeappx.exe"
    )
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            $makeAppxPath = $path
            break
        }
    }
}

if ($makeAppxPath) {
    Write-Host "  Using makeappx: $makeAppxPath"
    & $makeAppxPath pack /d $StageDir /p $msixPath /o
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MSIX package created: $msixPath" -ForegroundColor Green
    }
    else {
        Write-Error "makeappx.exe failed with exit code $LASTEXITCODE"
    }
}
else {
    Write-Warning "makeappx.exe not found. Install Windows SDK to create MSIX packages."
    Write-Host "Staged files are available at: $StageDir"
}

Write-Host ""
Write-Host "Build complete!" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDir"
