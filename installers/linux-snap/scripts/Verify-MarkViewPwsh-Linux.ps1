# Verify-MarkViewPwsh-Linux.ps1
# Verifies that a trimmed PowerShell bundle has everything MarkView needs.
# Adapted from the Windows Verify-MarkViewPwsh.ps1.
#
# Usage:
#   pwsh -NoProfile -File Verify-MarkViewPwsh-Linux.ps1
#   pwsh -NoProfile -File Verify-MarkViewPwsh-Linux.ps1 -ScriptPath ./staged/app/Open-Markdown.ps1 -ModulePath ./staged/app/MarkdownViewer.psm1

[CmdletBinding()]
param(
    [string]$ScriptPath = './staged/app/Open-Markdown.ps1',
    [string]$ModulePath = './staged/app/MarkdownViewer.psm1',
    [string]$SharedModulePath = './staged/app/MarkdownViewer.Shared.psm1',
    [string]$PwshDir = ''
)

$ErrorActionPreference = 'Stop'

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command -Name $Name -ErrorAction Stop
    [pscustomobject]@{
        Command     = $Name
        CommandType = $cmd.CommandType.ToString()
        Source      = $cmd.Source
        ModuleName  = $cmd.ModuleName
    }
}

Write-Host '=== Environment ==='
[pscustomobject]@{
    PSVersion   = $PSVersionTable.PSVersion.ToString()
    PSEdition   = $PSVersionTable.PSEdition
    PSHome      = $PSHOME
    Platform    = $PSVersionTable.Platform
    OS          = $PSVersionTable.OS
    CurrentDir  = (Get-Location).Path
    ScriptPath  = $ScriptPath
    ModulePath  = $ModulePath
    SharedModule = $SharedModulePath
} | Format-List

$errors = 0

# Check files exist
if (-not (Test-Path $ScriptPath)) { Write-Error "Open-Markdown.ps1 not found: $ScriptPath"; $errors++ }
if (-not (Test-Path $ModulePath)) { Write-Error "MarkdownViewer.psm1 not found: $ModulePath"; $errors++ }
if (-not (Test-Path $SharedModulePath)) { Write-Error "MarkdownViewer.Shared.psm1 not found: $SharedModulePath"; $errors++ }

# Check pwsh binary if PwshDir specified
if ($PwshDir -and (Test-Path $PwshDir)) {
    $pwshBin = Join-Path $PwshDir 'pwsh'
    if (Test-Path $pwshBin) {
        Write-Host "  Bundled pwsh found: $pwshBin"
    } else {
        Write-Warning "  Bundled pwsh NOT found at: $pwshBin"
        $errors++
    }
}

Write-Host ''
Write-Host '=== Check required cmdlets (engine/inbox) ==='
$required = @(
    'Add-Type', 'ConvertFrom-Markdown', 'ConvertTo-Json', 'Get-Content',
    'Import-Module', 'Join-Path', 'New-Object', 'Out-Null', 'Resolve-Path',
    'Split-Path', 'Start-Process', 'Test-Path'
)

# Note: Unblock-File is Windows-only; not required on Linux
$cmdResults = @()
foreach ($cmdName in $required) {
    try {
        $cmdResults += Assert-Command $cmdName
    } catch {
        Write-Error "Required cmdlet not found: $cmdName"
        $errors++
    }
}
$cmdResults | Sort-Object Command | Format-Table -AutoSize

Write-Host '=== Import shared module ==='
try {
    Import-Module (Resolve-Path $SharedModulePath).Path -Force -PassThru | Format-List Name, Version, Path
} catch {
    Write-Error "Failed to import shared module: $_"
    $errors++
}

Write-Host '=== Import app module ==='
try {
    Import-Module (Resolve-Path $ModulePath).Path -Force -PassThru | Format-List Name, Version, Path
} catch {
    Write-Error "Failed to import module: $_"
    $errors++
}

Write-Host '=== Exported functions ==='
$modName = 'MarkdownViewer'
$exportedCmds = Get-Command -Module $modName -ErrorAction SilentlyContinue
if (-not $exportedCmds) {
    Write-Warning "No exported commands found for module '$modName'."
    $errors++
} else {
    $exportedCmds | Sort-Object Name | Format-Table Name, CommandType -AutoSize
}

# Verify required exports
$requiredExports = @(
    'Invoke-HtmlSanitization', 'Test-RemoteImages', 'Repair-MarkdownLinks',
    'Repair-HtmlLinks', 'Get-FileBaseHref', 'Test-Motw', 'Start-DefaultBrowser',
    'Initialize-PlatformUI', 'Show-MotwWarning', 'Show-FileNotFound', 'Show-ErrorDialog'
)
$exportedNames = @($exportedCmds | ForEach-Object { $_.Name })
foreach ($fn in $requiredExports) {
    if ($fn -notin $exportedNames) {
        Write-Error "Required export missing: $fn"
        $errors++
    }
}

Write-Host '=== Smoke test: ConvertFrom-Markdown ==='
try {
    $result = ConvertFrom-Markdown -InputObject '# Test'
    if ($result.Html -match '<h1') {
        Write-Host '  ConvertFrom-Markdown: OK'
    } else {
        Write-Warning "  ConvertFrom-Markdown produced unexpected output: $($result.Html)"
        $errors++
    }
} catch {
    Write-Error "ConvertFrom-Markdown failed: $_"
    $errors++
}

Write-Host '=== Smoke test: Invoke-HtmlSanitization ==='
try {
    $sanitized = Invoke-HtmlSanitization -Html '<h1>Test</h1><script>bad</script>'
    if ($sanitized -notmatch '<script') {
        Write-Host '  Invoke-HtmlSanitization: OK'
    } else {
        Write-Warning "  Sanitization did not strip <script> tag"
        $errors++
    }
} catch {
    Write-Error "Invoke-HtmlSanitization failed: $_"
    $errors++
}

Write-Host ''
if ($errors -gt 0) {
    Write-Host "VERIFICATION FAILED: $errors error(s)" -ForegroundColor Red
    exit 1
} else {
    Write-Host 'VERIFICATION PASSED' -ForegroundColor Green
}
