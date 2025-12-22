# uninstall.ps1
$ErrorActionPreference = "Stop"

$AppName    = "Markdown Viewer"
$AppId      = "MarkdownViewer"
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\MarkdownViewer"

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
  [ShellNotify]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

# Context menu (if present)
Remove-Item "HKCU:\Software\Classes\SystemFileAssociations\.md\shell\viewmarkdown" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKCU:\Software\Classes\SystemFileAssociations\.markdown\shell\viewmarkdown" -Recurse -Force -ErrorAction SilentlyContinue

# ProgId + icon
Remove-Item "HKCU:\Software\Classes\$AppId" -Recurse -Force -ErrorAction SilentlyContinue

# Default Apps registration
Remove-ItemProperty "HKCU:\Software\RegisteredApplications" -Name $AppName -Force -ErrorAction SilentlyContinue
Remove-Item "HKCU:\Software\$AppId" -Recurse -Force -ErrorAction SilentlyContinue

# Apps & features entry
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppId" -Recurse -Force -ErrorAction SilentlyContinue

# Files
Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

Refresh-ShellAssociations

Write-Host "Done."
if (-not $NoWait) {
    Write-Host ""
    Read-Host "Press Enter to exit..."
}