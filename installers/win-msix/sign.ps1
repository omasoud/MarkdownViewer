# sign.ps1 - MSIX signing script for Markdown Viewer
# Automates self-signed certificate creation and MSIX package signing for dev/sideload testing.

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$MsixPath = '',      # Path to MSIX or MSIXBUNDLE to sign
    
    [switch]$CreateCert,         # Create/refresh dev certificate
    
    [switch]$Sign,               # Sign the specified MSIX
    
    [switch]$TrustCert,          # Add cert to TrustedPeople store (enables sideload)
    
    [string]$CertSubject = 'CN=MarkdownViewer',  # Must match manifest Publisher
    
    [string]$CertFriendlyName = 'Markdown Viewer Dev Certificate',
    
    [int]$CertValidityDays = 365
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot

# Find signtool.exe
function Find-SignTool {
    $signtoolCmd = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($signtoolCmd) {
        return $signtoolCmd.Source
    }
    
    # Try to find in Windows SDK
    $sdkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\signtool.exe"
    )
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Get existing dev certificate or return $null
function Get-DevCertificate {
    param([string]$Subject)
    
    $certs = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { 
        $_.Subject -eq $Subject -and 
        $_.NotAfter -gt (Get-Date) -and
        ($_.EnhancedKeyUsageList | Where-Object { $_.FriendlyName -eq 'Code Signing' })
    }
    
    if ($certs) {
        return $certs | Sort-Object NotAfter -Descending | Select-Object -First 1
    }
    return $null
}

# Create a new self-signed code signing certificate
function New-DevCertificate {
    param(
        [string]$Subject,
        [string]$FriendlyName,
        [int]$ValidityDays
    )
    
    Write-Host "Creating self-signed code signing certificate..." -ForegroundColor Yellow
    Write-Host "  Subject: $Subject"
    Write-Host "  Valid for: $ValidityDays days"
    
    # Remove any existing certs with the same subject
    $existingCerts = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $Subject }
    foreach ($cert in $existingCerts) {
        Write-Host "  Removing existing certificate: $($cert.Thumbprint)"
        Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    }
    
    # Create new certificate
    $cert = New-SelfSignedCertificate `
        -Type Custom `
        -Subject $Subject `
        -KeyUsage DigitalSignature `
        -FriendlyName $FriendlyName `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
        -NotAfter (Get-Date).AddDays($ValidityDays)
    
    Write-Host "Certificate created: $($cert.Thumbprint)" -ForegroundColor Green
    return $cert
}

# Add certificate to TrustedPeople store for sideloading
function Add-CertToTrustedPeople {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    
    Write-Host "Adding certificate to TrustedPeople store..." -ForegroundColor Yellow
    
    # Check if already in TrustedPeople
    $existingCert = Get-ChildItem -Path Cert:\CurrentUser\TrustedPeople | Where-Object { $_.Thumbprint -eq $Certificate.Thumbprint }
    
    if ($existingCert) {
        Write-Host "  Certificate already trusted" -ForegroundColor Green
        return
    }
    
    # Export cert (public key only) and import to TrustedPeople
    $certBytes = $Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    $trustedPeople = New-Object System.Security.Cryptography.X509Certificates.X509Store('TrustedPeople', 'CurrentUser')
    $trustedPeople.Open('ReadWrite')
    try {
        $certToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 @(,$certBytes)
        $trustedPeople.Add($certToImport)
        Write-Host "  Certificate added to TrustedPeople store" -ForegroundColor Green
    }
    finally {
        $trustedPeople.Close()
    }
}

# Sign an MSIX package
function Sign-MsixPackage {
    param(
        [string]$PackagePath,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )
    
    $signtool = Find-SignTool
    if (-not $signtool) {
        throw "signtool.exe not found. Install Windows SDK."
    }
    
    Write-Host "Signing package: $PackagePath" -ForegroundColor Yellow
    Write-Host "  Using certificate: $($Certificate.Thumbprint)"
    Write-Host "  Using signtool: $signtool"
    
    # Sign with SHA256
    Write-Host "  Signing with SHA256..." -ForegroundColor Yellow
    Write-Host "  File: $PackagePath" -ForegroundColor Yellow
    Write-Host "  Certificate Thumbprint: $($Certificate.Thumbprint)" -ForegroundColor Yellow
    Write-Host "  Signing tool: $signtool" -ForegroundColor Yellow
    Write-Host "  Command: & $signtool sign /fd SHA256 /sha1 $($Certificate.Thumbprint) /td SHA256 $PackagePath" -ForegroundColor Yellow
    Write-Host "  Executing command..." -ForegroundColor Yellow
    & $signtool sign /fd SHA256 /sha1 $Certificate.Thumbprint /td SHA256 $PackagePath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Package signed successfully" -ForegroundColor Green
    }
    else {
        throw "Signing failed with exit code $LASTEXITCODE"
    }
}

# Main execution
Write-Host "Markdown Viewer MSIX Signing Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

if (-not $CreateCert -and -not $Sign -and -not $TrustCert) {
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  Create certificate:  .\sign.ps1 -CreateCert"
    Write-Host "  Trust certificate:   .\sign.ps1 -TrustCert"
    Write-Host "  Sign MSIX:           .\sign.ps1 -Sign -MsixPath <path>"
    Write-Host "  All in one:          .\sign.ps1 -CreateCert -TrustCert -Sign -MsixPath <path>"
    Write-Host ""
    Write-Host "The certificate subject must match the Publisher in AppxManifest.xml"
    Write-Host "Current subject: $CertSubject"
    exit 0
}

$cert = $null

# Create certificate if requested or needed
if ($CreateCert) {
    $cert = New-DevCertificate -Subject $CertSubject -FriendlyName $CertFriendlyName -ValidityDays $CertValidityDays
}
else {
    # Try to find existing certificate
    $cert = Get-DevCertificate -Subject $CertSubject
    if (-not $cert -and ($Sign -or $TrustCert)) {
        Write-Host "No valid certificate found. Creating one..." -ForegroundColor Yellow
        $cert = New-DevCertificate -Subject $CertSubject -FriendlyName $CertFriendlyName -ValidityDays $CertValidityDays
    }
}

# Trust certificate if requested
if ($TrustCert -and $cert) {
    Add-CertToTrustedPeople -Certificate $cert
}

# Sign package if requested
if ($Sign) {
    if (-not $MsixPath) {
        # Try to find the most recent MSIX in output directory
        $outputDir = Join-Path $ScriptRoot 'output'
        $msixFiles = Get-ChildItem -Path $outputDir -Filter '*.msix*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($msixFiles) {
            $MsixPath = $msixFiles[0].FullName
            Write-Host "Using most recent package: $MsixPath" -ForegroundColor Yellow
        }
        else {
            throw "No MSIX path specified and no packages found in $outputDir"
        }
    }
    
    if (-not (Test-Path $MsixPath)) {
        throw "MSIX file not found: $MsixPath"
    }
    
    if (-not $cert) {
        throw "No certificate available for signing"
    }
    
    Sign-MsixPackage -PackagePath $MsixPath -Certificate $cert
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Cyan

if ($cert) {
    Write-Host ""
    Write-Host "Certificate details:" -ForegroundColor Yellow
    Write-Host "  Thumbprint: $($cert.Thumbprint)"
    Write-Host "  Subject:    $($cert.Subject)"
    Write-Host "  Expires:    $($cert.NotAfter)"
}
