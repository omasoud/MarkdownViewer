# install.ps1
# Per-user installer for Markdown Viewer (VBS + pwsh).
# - Copies payload into %LOCALAPPDATA%\Programs\MarkdownViewer
# - Registers ProgId + DefaultIcon + Capabilities (Default Apps entry)
# - Optionally adds context menu
# - Optionally opens Default Apps settings directly to this app
# - No Explorer restart; uses SHChangeNotify to refresh associations/icons
param([switch]$NoWait)

$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
  $ScriptRoot = Split-Path -Parent $PSCommandPath
}
if (-not $ScriptRoot) {
  throw "Cannot determine script directory. Run this script via -File."
}

$ErrorActionPreference = "Stop"

$AppName    = "Markdown Viewer"
$AppId      = "MarkdownViewer"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\MarkdownViewer"

# The source icon file to use
$SourceIconFileName = "markdown-mark-solid-win10-light.ico"

$PayloadDir = Join-Path $ScriptRoot "payload"

# The icon file path after installation
$InstalledIconPath = Join-Path $InstallDir "markdown.ico"


function Ask($prompt, $defaultYes=$true) {
  $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
  $no  = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
  $def = if ($defaultYes) { 0 } else { 1 }
  $c = $Host.UI.PromptForChoice($AppName, $prompt, @($yes,$no), $def)
  return ($c -eq 0)
}

function Ensure-Pwsh {
  if (Get-Command pwsh -ErrorAction SilentlyContinue) { return $true }

  # Prefer WinGet if available
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
      winget install --id 9MZ1SNWT0N5D --source msstore --accept-source-agreements --accept-package-agreements
    } catch {
      # Fall through to Store link + friendly exit
    }
  }

  if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Start-Process "https://apps.microsoft.com/detail/9MZ1SNWT0N5D?hl=en-us&gl=US&ocid=pdpshare"
    Write-Host "PowerShell 7 (pwsh) was not found."
    Write-Host "Please install it from the Microsoft Store, then run install.ps1 again."
    exit 1
  }

  return $true
}

function Copy-Payload {
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Copy-Item -Force (Join-Path $PayloadDir "viewmd.vbs")    $InstallDir
  Copy-Item -Force (Join-Path $PayloadDir "Open-Markdown.ps1") $InstallDir
  Copy-Item -Force (Join-Path $PayloadDir "style.css") $InstallDir
  Copy-Item -Force (Join-Path $PayloadDir "script.js") $InstallDir
  Copy-Item -Force (Join-Path $PayloadDir $SourceIconFileName) $InstalledIconPath
  Copy-Item -Force (Join-Path $ScriptRoot "uninstall.ps1") $InstallDir
  Copy-Item -Force (Join-Path $ScriptRoot "uninstall.vbs") $InstallDir
}

function Set-ReadOnlyAcl {
    $InstalledIconFileName = [IO.Path]::GetFileName($InstalledIconPath)
    $files = @("Open-Markdown.ps1", "viewmd.vbs", "script.js", "style.css", $InstalledIconFileName, "uninstall.ps1", "uninstall.vbs")
    foreach ($f in $files) {
        $path = Join-Path $InstallDir $f
        if (Test-Path $path) {
            Set-ItemProperty $path -Name IsReadOnly -Value $true
        }
    }
}

function Set-Registry {
  $vbsPath  = Join-Path $InstallDir "viewmd.vbs"
  $icoPath  = $InstalledIconPath
  $cmd      = "wscript.exe `"$vbsPath`" `"%1`""

  # ProgId command
  New-Item -Path "HKCU:\Software\Classes\$AppId\shell\open\command" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$AppId" -Name "(default)" -Value $AppName -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$AppId\shell" -Name "(default)" -Value "open" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$AppId\shell\open\command" -Name "(default)" -Value $cmd -Force | Out-Null

  # Icon
  New-Item -Path "HKCU:\Software\Classes\$AppId\DefaultIcon" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$AppId\DefaultIcon" -Name "(default)" -Value $icoPath -Force | Out-Null

  # Default Apps registration (Capabilities)
  New-Item -Path "HKCU:\Software\RegisteredApplications" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\RegisteredApplications" -Name $AppName -Value "Software\$AppId\Capabilities" -Force | Out-Null
  

  New-Item -Path "HKCU:\Software\$AppId\Capabilities\FileAssociations" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\$AppId\Capabilities" -Name "ApplicationName" -Value $AppName -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\$AppId\Capabilities" -Name "ApplicationDescription" -Value "View Markdown rendered in your browser" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\$AppId\Capabilities" -Name "ApplicationIcon" -Value $icoPath -Force | Out-Null

  # File associations (both .md and .markdown)
  New-ItemProperty -Path "HKCU:\Software\$AppId\Capabilities\FileAssociations" -Name ".md" -Value $AppId -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\$AppId\Capabilities\FileAssociations" -Name ".markdown" -Value $AppId -Force | Out-Null
}

function Register-Protocol {
  $proto = 'mdview'
  $vbsPath = Join-Path $InstallDir 'viewmd.vbs'
  $cmd = "wscript.exe `"$vbsPath`" `"%1`""

  New-Item -Path "HKCU:\Software\Classes\$proto" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name '(default)' -Value 'URL:Markdown Viewer' -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$proto" -Name 'URL Protocol' -Value '' -Force | Out-Null

  New-Item -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Force | Out-Null
  New-ItemProperty -Path "HKCU:\Software\Classes\$proto\shell\open\command" -Name '(default)' -Value $cmd -Force | Out-Null
}


function Set-ContextMenu {
  $vbsPath = Join-Path $InstallDir "viewmd.vbs"
  $cmd     = "wscript.exe `"$vbsPath`" `"%1`""

  $base = "HKCU:\Software\Classes\SystemFileAssociations\.md\shell\viewmarkdown"
  New-Item -Path "$base\command" -Force | Out-Null
  New-ItemProperty -Path $base -Name "(default)" -Value "View Markdown" -Force | Out-Null
  New-ItemProperty -Path "$base\command" -Name "(default)" -Value $cmd -Force | Out-Null

  $base2 = "HKCU:\Software\Classes\SystemFileAssociations\.markdown\shell\viewmarkdown"
  New-Item -Path "$base2\command" -Force | Out-Null
  New-ItemProperty -Path $base2 -Name "(default)" -Value "View Markdown" -Force | Out-Null
  New-ItemProperty -Path "$base2\command" -Name "(default)" -Value $cmd -Force | Out-Null
}

function Register-UninstallEntry {
  $icoPath = $InstalledIconPath
  $unVbs   = Join-Path $InstallDir "uninstall.vbs"

  $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppId"
  New-Item -Path $k -Force | Out-Null
  New-ItemProperty -Path $k -Name "DisplayName"     -Value $AppName -Force | Out-Null
  New-ItemProperty -Path $k -Name "DisplayIcon"     -Value $icoPath -Force | Out-Null
  New-ItemProperty -Path $k -Name "InstallLocation" -Value $InstallDir -Force | Out-Null
  New-ItemProperty -Path $k -Name "Publisher"       -Value $env:USERNAME -Force | Out-Null
  New-ItemProperty -Path $k -Name "UninstallString" -Value ("wscript.exe `"$unVbs`"") -Force | Out-Null
}

function Refresh-ShellAssociations {
  $code = @'
using System;
using System.Runtime.InteropServices;
public static class ShellNotify {
  [DllImport("shell32.dll")]
  public static extern void SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
}
'@
  Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue | Out-Null

  # SHCNE_ASSOCCHANGED (0x08000000), SHCNF_IDLIST (0x0000)
  [ShellNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

Ensure-Pwsh | Out-Null
Copy-Payload
Set-ReadOnlyAcl
Set-Registry
Register-Protocol

if (Ask "Enable the right-click context menu item 'View Markdown' for .md and .markdown files?") {
  Set-ContextMenu
}

Register-UninstallEntry
Refresh-ShellAssociations

function Show-DefaultAppsMessageAndOpenSettings {
  Add-Type -AssemblyName System.Windows.Forms | Out-Null

  $msg = @"
To make Markdown Viewer the default:

1) In the Default Apps window, set BOTH:
   - .md
   - .markdown

2) In the picker, choose:
   Microsoft® Windows Based Script Host
   (this corresponds to "Markdown Viewer")

After selecting it, double-clicking .md/.markdown files will open in the browser.
"@

  Write-Host $msg
  
  $uri = "ms-settings:defaultapps?registeredAppUser=" + [Uri]::EscapeDataString($AppName)
  Start-Process $uri
}

if (Ask "Open Default Apps settings to set Markdown Viewer as the default for .md and .markdown?") {
  Show-DefaultAppsMessageAndOpenSettings
}


Write-Host "Done."
if (-not $NoWait) {
    Write-Host ""
    Read-Host "Press Enter to exit..."
}



