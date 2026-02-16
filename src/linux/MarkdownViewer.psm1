# MarkdownViewer.psm1 - Linux platform module for Markdown Viewer

$ErrorActionPreference = 'Stop'

# Import cross-platform shared functions
# In snap/installed layout, the shared module is co-located; in dev layout it's in ../core/
$sharedPath = Join-Path $PSScriptRoot 'MarkdownViewer.Shared.psm1'
if (-not (Test-Path $sharedPath)) {
    $sharedPath = Join-Path $PSScriptRoot '../core/MarkdownViewer.Shared.psm1'
}
Import-Module $sharedPath -Force


<#
.SYNOPSIS
    Gets the base href for a file path.
.DESCRIPTION
    Converts a Linux file path to a file:// URL for use as the base href.
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
    if ($dir -match '^(?:Microsoft\.PowerShell\.Core\\)?FileSystem::(.+)$') {
        $dir = $Matches[1]
    }

    # Linux: /home/user/docs/ -> file:///home/user/docs/
    return 'file://' + $dir + '/'
}


<#
.SYNOPSIS
    Tests if a file has a Mark-of-the-Web (MOTW) zone identifier.
.DESCRIPTION
    Linux has no MOTW equivalent. Always returns $null.
.PARAMETER FilePath
    The file path to check.
.OUTPUTS
    Always $null on Linux.
#>
function Test-Motw {
    [CmdletBinding()]
    [OutputType([System.Nullable[int]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    return $null
}


<#
.SYNOPSIS
    Launches the default browser with a URL.
.DESCRIPTION
    Uses xdg-open to launch the default browser on Linux.
.PARAMETER Url
    The URL to open.
#>
function Start-DefaultBrowser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url
    )
    
    Start-Process 'xdg-open' -ArgumentList $Url
}


<#
.SYNOPSIS
    Initializes platform-specific UI requirements.
.DESCRIPTION
    No-op on Linux (no WinForms needed).
#>
function Initialize-PlatformUI {
    [CmdletBinding()]
    param()
    # No initialization needed on Linux
}


<#
.SYNOPSIS
    Shows a MOTW security warning dialog.
.DESCRIPTION
    Uses zenity if available, otherwise falls back to Write-Warning.
    Unlikely to be called since Test-Motw always returns $null on Linux.
.PARAMETER FilePath
    The file path that triggered the warning.
.OUTPUTS
    "Open", "Unblock", or "Cancel".
#>
function Show-MotwWarning {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$FilePath)
    
    $fileName = [IO.Path]::GetFileName($FilePath)
    
    if (Get-Command zenity -ErrorAction SilentlyContinue) {
        zenity --question --title="Security Warning - MarkView" `
            --text="$fileName was downloaded from the internet.`nIt may contain malicious content." `
            --ok-label="Open" --cancel-label="Cancel" 2>/dev/null
        if ($LASTEXITCODE -eq 0) { return "Open" } else { return "Cancel" }
    }
    
    Write-Warning "Security warning: $fileName may be from an untrusted source"
    return "Open"
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

    $msg = if ($FromLink) {
        "The linked Markdown file could not be found:\n\n$FilePath\n\nLink: $FromLink"
    } else {
        "The Markdown file could not be found:\n\n$FilePath"
    }
    
    if (Get-Command zenity -ErrorAction SilentlyContinue) {
        zenity --warning --title="MarkView" --text="$msg" 2>/dev/null
    } else {
        Write-Warning "File not found: $FilePath"
    }
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
    
    if (Get-Command zenity -ErrorAction SilentlyContinue) {
        zenity --error --title="MarkView" --text="$Message" 2>/dev/null
    } else {
        Write-Error $Message
    }
}


# Export functions - same interface as the Windows module
Export-ModuleMember -Function @(
    # Shared cross-platform functions (re-exported from MarkdownViewer.Shared.psm1)
    'Invoke-HtmlSanitization'
    'Test-RemoteImages'
    'Repair-MarkdownLinks'
    'Repair-HtmlLinks'
    # Linux-specific implementations
    'Get-FileBaseHref'
    'Test-Motw'
    'Start-DefaultBrowser'
    # Platform UI functions
    'Initialize-PlatformUI'
    'Show-MotwWarning'
    'Show-FileNotFound'
    'Show-ErrorDialog'
)
