# Verify-MarkViewPwsh-macOS.ps1
# Verifies that a staged macOS PowerShell bundle has everything MarkView needs.

[CmdletBinding()]
param(
    [string]$ScriptPath = './staged/MarkView.app/Contents/Resources/app/Open-Markdown.ps1',
    [string]$ModulePath = './staged/MarkView.app/Contents/Resources/app/MarkdownViewer.psm1',
    [string]$SharedModulePath = './staged/MarkView.app/Contents/Resources/app/MarkdownViewer.Shared.psm1',
    [string]$PwshDir = './staged/MarkView.app/Contents/Resources/pwsh'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-SingleQuotedLiteral {
    param([Parameter(Mandatory)][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

$errors = 0

Write-Host '=== Environment ==='
[pscustomobject]@{
    PSVersion    = $PSVersionTable.PSVersion.ToString()
    PSEdition    = $PSVersionTable.PSEdition
    PSHome       = $PSHOME
    Platform     = $PSVersionTable.Platform
    OS           = $PSVersionTable.OS
    CurrentDir   = (Get-Location).Path
    ScriptPath   = $ScriptPath
    ModulePath   = $ModulePath
    SharedModule = $SharedModulePath
    PwshDir      = $PwshDir
} | Format-List

if (-not (Test-Path $ScriptPath)) { Write-Error "Open-Markdown.ps1 not found: $ScriptPath"; $errors++ }
if (-not (Test-Path $ModulePath)) { Write-Error "MarkdownViewer.psm1 not found: $ModulePath"; $errors++ }
if (-not (Test-Path $SharedModulePath)) { Write-Error "MarkdownViewer.Shared.psm1 not found: $SharedModulePath"; $errors++ }

$pwshBin = Join-Path $PwshDir 'pwsh'
if (-not (Test-Path $pwshBin)) {
    Write-Error "Bundled pwsh not found: $pwshBin"
    $errors++
}

if ($errors -gt 0) {
    exit 1
}

$scriptLiteral = ConvertTo-SingleQuotedLiteral ((Resolve-Path $ScriptPath).Path)
$moduleLiteral = ConvertTo-SingleQuotedLiteral ((Resolve-Path $ModulePath).Path)
$sharedLiteral = ConvertTo-SingleQuotedLiteral ((Resolve-Path $SharedModulePath).Path)

$verify = @"
`$ErrorActionPreference = 'Stop'

`$required = @(
    'Add-Type', 'ConvertFrom-Markdown', 'ConvertTo-Json', 'Copy-Item',
    'Get-Content', 'Import-Module', 'Join-Path', 'New-Item', 'New-Object',
    'Move-Item', 'Out-Null', 'Remove-Item', 'Resolve-Path', 'Split-Path',
    'Start-Process', 'Test-Path'
)
foreach (`$cmd in `$required) {
    Get-Command `$cmd -ErrorAction Stop | Out-Null
}

Import-Module $sharedLiteral -Force
Import-Module $moduleLiteral -Force

`$requiredExports = @(
    'Invoke-HtmlSanitization', 'Test-RemoteImages', 'Repair-MarkdownLinks',
    'Repair-HtmlLinks', 'Get-FileBaseHref', 'Test-Motw', 'Clear-FileTrustMarker',
    'Get-MarkViewOutputDirectory', 'Start-DefaultBrowser', 'Initialize-PlatformUI',
    'Show-MotwWarning', 'Show-FileNotFound', 'Show-ErrorDialog'
)
`$exportedNames = @(Get-Command -Module MarkdownViewer | ForEach-Object { `$_.Name })
foreach (`$fn in `$requiredExports) {
    if (`$fn -notin `$exportedNames) {
        throw "Required export missing: `$fn"
    }
}

`$markdown = [string]::Join([Environment]::NewLine, @(
    '# Test',
    '',
    '| A | B |',
    '|---|---|',
    '| **x** | y |',
    '',
    '~~~powershell',
    'Get-ChildItem',
    '~~~'
))
`$result = ConvertFrom-Markdown -InputObject `$markdown
if (`$result.Html -notmatch '<h1' -or `$result.Html -notmatch '<table' -or `$result.Html -notmatch '<strong>x</strong>') {
    throw "ConvertFrom-Markdown produced unexpected output: `$(`$result.Html)"
}

`$sanitized = Invoke-HtmlSanitization -Html '<h1>Test</h1><script>bad</script>'
if (`$sanitized -match '<script') {
    throw 'Sanitization did not strip script tag.'
}

if (-not (Test-Path $scriptLiteral)) {
    throw 'Engine script missing during bundled verification.'
}

'VERIFICATION PASSED'
"@

Write-Host '=== Bundled PowerShell verification ==='
& $pwshBin -NoProfile -NonInteractive -Command $verify
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bundled PowerShell verification failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
