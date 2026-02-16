# MarkdownViewer.psm1 - Windows platform module for Markdown Viewer

$ErrorActionPreference = 'Stop'

# Import cross-platform shared functions
# In MSIX/installed layout, the shared module is co-located; in dev layout it's in ..\core\
$sharedPath = Join-Path $PSScriptRoot 'MarkdownViewer.Shared.psm1'
if (-not (Test-Path $sharedPath)) {
    $sharedPath = Join-Path $PSScriptRoot '..\core\MarkdownViewer.Shared.psm1'
}
Import-Module $sharedPath -Force


<#
.SYNOPSIS
    Gets the base href for a file path.
.DESCRIPTION
    Converts a Windows file path to a file:// URL for use as the base href.
.PARAMETER FilePath
    The file path to convert.
.OUTPUTS
    The file:// URL string.
#>
function Get-FileBaseHref {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $dir = Split-Path -LiteralPath $FilePath

    # Strip PSProvider prefixes that can appear when paths come from PSDrives
    # e.g. "Microsoft.PowerShell.Core\FileSystem::" or just "FileSystem::"
    if ($dir -match '^(?:Microsoft\.PowerShell\.Core\\)?FileSystem::(.+)$') {
        $dir = $Matches[1]
    }

    if ($dir.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\?\UNC\server\share\path -> file://server/share/path/
        $unc = $dir.Substring(8)
        return 'file://' + ($unc.Replace('\', '/')) + '/'
    }

    if ($dir.StartsWith('\\', [StringComparison]::OrdinalIgnoreCase) -and
        -not $dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\server\share\path -> file://server/share/path/
        return 'file://' + ($dir.TrimStart('\').Replace('\', '/')) + '/'
    }

    if ($dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\?\C:\path -> file:///C:/path/
        $norm = $dir.Substring(4)
        return 'file:///' + ($norm.Replace('\', '/')) + '/'
    }

    # C:\path -> file:///C:/path/
    return 'file:///' + ($dir.Replace('\', '/')) + '/'
}


<#
.SYNOPSIS
    Tests if a file has a Mark-of-the-Web (MOTW) zone identifier.
.DESCRIPTION
    Reads the Zone.Identifier alternate data stream to determine the security zone.
.PARAMETER FilePath
    The file path to check.
.OUTPUTS
    The zone ID (0-4) or $null if no zone identifier exists.
#>
function Test-Motw {
    [CmdletBinding()]
    [OutputType([System.Nullable[int]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $adsPath = $FilePath + ":Zone.Identifier"
    
    if (-not (Test-Path -LiteralPath $adsPath)) {
        return $null
    }
    
    try {
        $content = Get-Content -LiteralPath $adsPath -ErrorAction Stop
        foreach ($line in $content) {
            if ($line -match '^ZoneId=(\d+)') {
                return [int]$Matches[1]
            }
        }
    }
    catch {
        return $null
    }
    return $null
}


<#
.SYNOPSIS
    Gets the default browser's ProgId from Windows registry.
.DESCRIPTION
    Reads the user's default browser association for https (preferred) or http.
.OUTPUTS
    The ProgId string (e.g., "ChromeHTML", "MSEdgeHTM", "FirefoxURL").
#>
function Get-DefaultBrowserProgId {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $keys = @(
        'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice',
        'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice'
    )
    
    foreach ($k in $keys) {
        try {
            $p = Get-ItemProperty -Path $k -Name ProgId -ErrorAction Stop
            if ($p.ProgId) { return $p.ProgId }
        } catch { }
    }
    
    throw "Could not determine default browser ProgId from HKCU UrlAssociations."
}


<#
.SYNOPSIS
    Gets the shell open command for a ProgId.
.DESCRIPTION
    Reads the shell\open\command from HKCR for the specified ProgId.
.PARAMETER ProgId
    The ProgId to look up (e.g., "ChromeHTML").
.OUTPUTS
    The command string with environment variables expanded.
#>
function Get-ProgIdOpenCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $ProgId
    )
    
    $cmdKey = "Registry::HKEY_CLASSES_ROOT\$ProgId\shell\open\command"
    try {
        $cmd = (Get-ItemProperty -Path $cmdKey -Name '(default)' -ErrorAction Stop).'(default)'
        return [Environment]::ExpandEnvironmentVariables($cmd)
    } catch {
        throw "Failed to read open command for ProgId '$ProgId' at '$cmdKey'."
    }
}


<#
.SYNOPSIS
    Extracts the executable path from a shell open command.
.DESCRIPTION
    Parses the .exe path from commands like:
    - "C:\Path\browser.exe" -- "%1"
    - C:\Path\browser.exe -- "%1"
.PARAMETER OpenCommand
    The shell open command string.
.OUTPUTS
    The full path to the executable.
#>
function Get-ExePathFromOpenCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $OpenCommand
    )
    
    $cmd = $OpenCommand.Trim()
    
    $exe = $null
    if ($cmd -match '^\s*"([^"]+?\.exe)"') {
        $exe = $Matches[1]
    } elseif ($cmd -match '^\s*([^\s]+?\.exe)') {
        $exe = $Matches[1]
    }
    
    if (-not $exe) {
        throw "Could not parse an .exe from open command: $OpenCommand"
    }
    
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Parsed exe does not exist: $exe`nOpen command: $OpenCommand"
    }
    
    return $exe
}


<#
.SYNOPSIS
    Gets the path to the user's default web browser executable.
.DESCRIPTION
    Resolves the default browser from registry associations and returns the exe path.
.OUTPUTS
    The full path to the browser executable.
#>
function Get-DefaultBrowserExePath {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    $progId = Get-DefaultBrowserProgId
    $openCmd = Get-ProgIdOpenCommand -ProgId $progId
    return Get-ExePathFromOpenCommand -OpenCommand $openCmd
}


<#
.SYNOPSIS
    Launches the default browser with a URL.
.DESCRIPTION
    Bypasses ShellExecute URL parsing by launching the browser directly.
    This preserves URL fragments that would otherwise be stripped.
.PARAMETER Url
    The URL to open (typically a file:// URL with fragment).
#>
function Start-DefaultBrowser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url
    )
    
    $exe = Get-DefaultBrowserExePath
    Start-Process -FilePath $exe -ArgumentList $Url
}


<#
.SYNOPSIS
    Initializes platform-specific UI requirements.
.DESCRIPTION
    Loads WinForms and enables visual styles for TaskDialog support.
#>
function Initialize-PlatformUI {
    [CmdletBinding()]
    param()
    
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    [System.Windows.Forms.Application]::EnableVisualStyles()
}


<#
.SYNOPSIS
    Shows a MOTW security warning dialog.
.PARAMETER FilePath
    The file path that has a Mark-of-the-Web.
.OUTPUTS
    "Open", "Unblock", or "Cancel".
#>
function Show-MotwWarning {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$FilePath)
    
    $fileName = [IO.Path]::GetFileName($FilePath)
    
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    
    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "Security Warning - MarkView"
    $page.Heading = "This file was downloaded from the internet"
    $page.Text = "$fileName`n`nIt may contain malicious content."
    $page.Icon = [System.Windows.Forms.TaskDialogIcon]::Warning
    
    $btnOpen = New-Object System.Windows.Forms.TaskDialogButton("Open")
    $btnUnblock = New-Object System.Windows.Forms.TaskDialogButton("Unblock && Open")
    $btnCancel = New-Object System.Windows.Forms.TaskDialogButton("Cancel")
    
    $page.Buttons.Add($btnOpen)
    $page.Buttons.Add($btnUnblock)
    $page.Buttons.Add($btnCancel)
    $page.DefaultButton = $btnCancel
    
    $result = [System.Windows.Forms.TaskDialog]::ShowDialog($owner.Handle, $page)
    $owner.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
    
    if ($result -eq $btnUnblock) {
        return "Unblock"
    }
    elseif ($result -eq $btnOpen) {
        return "Open"
    }
    else {
        return "Cancel"
    }
}


<#
.SYNOPSIS
    Shows a "file not found" warning dialog.
.PARAMETER FilePath
    The file path that was not found.
.PARAMETER FromLink
    Optional: the original link that referenced this file.
#>
function Show-FileNotFound {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$FromLink = ''
    )

    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true

    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "MarkView"
    $page.Heading = "File not found"
    $page.Text = if ($FromLink) {
        "The linked Markdown file could not be found:`n`n$FilePath`n`nLink: $FromLink"
    } else {
        "The Markdown file could not be found:`n`n$FilePath"
    }
    $page.Icon = [System.Windows.Forms.TaskDialogIcon]::Warning
    $page.Buttons.Add([System.Windows.Forms.TaskDialogButton]::OK)

    [System.Windows.Forms.TaskDialog]::ShowDialog($owner.Handle, $page) | Out-Null
    $owner.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
}


<#
.SYNOPSIS
    Shows an error dialog.
.PARAMETER Message
    The error message to display.
#>
function Show-ErrorDialog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)
    
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    
    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "MarkView"
    $page.Heading = "Error opening file"
    $page.Text = $Message
    $page.Icon = [System.Windows.Forms.TaskDialogIcon]::Error
    $page.Buttons.Add([System.Windows.Forms.TaskDialogButton]::OK)
    
    [System.Windows.Forms.TaskDialog]::ShowDialog($owner.Handle, $page) | Out-Null
    $owner.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
}


# Export functions
Export-ModuleMember -Function @(
    # Shared cross-platform functions (re-exported from MarkdownViewer.Shared.psm1)
    'Invoke-HtmlSanitization'
    'Test-RemoteImages'
    'Repair-MarkdownLinks'
    'Repair-HtmlLinks'
    # Windows-specific functions
    'Get-FileBaseHref'
    'Test-Motw'
    'Get-DefaultBrowserProgId'
    'Get-ProgIdOpenCommand'
    'Get-ExePathFromOpenCommand'
    'Get-DefaultBrowserExePath'
    'Start-DefaultBrowser'
    # Platform UI functions
    'Initialize-PlatformUI'
    'Show-MotwWarning'
    'Show-FileNotFound'
    'Show-ErrorDialog'
)
