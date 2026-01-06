[CmdletBinding()]
param(
  [string]$ScriptPath = ".\app\Open-Markdown.ps1",
  [string]$ModulePath = ".\app\MarkdownViewer.psm1"
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

Write-Host "=== Environment ==="
[pscustomobject]@{
  PSVersion    = $PSVersionTable.PSVersion.ToString()
  PSEdition    = $PSVersionTable.PSEdition
  PSHome       = $PSHOME
  CurrentDir   = (Get-Location).Path
  ScriptPath   = $ScriptPath
  ModulePath   = $ModulePath
} | Format-List

if (-not (Test-Path $ScriptPath)) { throw "Open-Markdown.ps1 not found: $ScriptPath" }
if (-not (Test-Path $ModulePath)) { throw "MarkdownViewer.psm1 not found: $ModulePath" }

Write-Host "=== Check required cmdlets (engine/inbox) ==="
$required = @(
  'Add-Type','ConvertFrom-Markdown','ConvertTo-Json','Get-Content','Import-Module',
  'Join-Path','New-Object','Out-Null','Resolve-Path','Split-Path','Start-Process',
  'Test-Path','Unblock-File'
)
($required | ForEach-Object { Assert-Command $_ }) | Sort-Object Command | Format-Table -AutoSize

Write-Host "=== Import app module ==="
Import-Module (Resolve-Path $ModulePath).Path -Force -PassThru | Format-List Name,Version,Path

Write-Host "=== What did the module EXPORT? ==="
$modName = 'MarkdownViewer'

$exportedCmds = Get-Command -Module $modName -ErrorAction SilentlyContinue
if (-not $exportedCmds) {
  Write-Warning "No exported commands found for module '$modName'. The module may not export any functions, or the module name differs."
} else {
  $exportedCmds | Sort-Object Name | Format-Table Name,CommandType,Source -AutoSize
}

Write-Host "=== What functions exist in the .psm1 file (regardless of export)? ==="
$mc = Get-Content (Resolve-Path $ModulePath).Path -Raw
$t = $null; $e = $null
$mAst = [System.Management.Automation.Language.Parser]::ParseInput($mc, [ref]$t, [ref]$e)

$definedFunctions = @(
  $mAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
    ForEach-Object { $_.Name }
) | Sort-Object -Unique

$definedFunctions | ForEach-Object { $_ }  # prints one per line

Write-Host "=== Smoke test: ConvertFrom-Markdown ==="
$md = "# Title`n`nHello"
$html = ConvertFrom-Markdown -InputObject $md
if (-not $html -or -not $html.Html) { throw "ConvertFrom-Markdown returned empty result" }
Write-Host "ConvertFrom-Markdown: OK"

Write-Host ""
Write-Host "DONE"
