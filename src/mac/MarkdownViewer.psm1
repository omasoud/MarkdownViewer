# MarkdownViewer.psm1 - macOS platform module for Markdown Viewer

$ErrorActionPreference = 'Stop'

# Import cross-platform shared functions
# In app/installed layout, the shared module is co-located; in dev layout it's in ../core/
$sharedPath = Join-Path $PSScriptRoot 'MarkdownViewer.Shared.psm1'
if (-not (Test-Path $sharedPath)) {
    $sharedPath = Join-Path $PSScriptRoot '../core/MarkdownViewer.Shared.psm1'
}
Import-Module $sharedPath -Force


function ConvertTo-AppleScriptLiteral {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [string] $Value
    )

    if ($null -eq $Value) {
        $Value = ''
    }

    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    $escaped = $escaped -replace "`r`n|`n|`r", '\n'
    return '"' + $escaped + '"'
}


function Invoke-AppleScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Script
    )

    $output = & /usr/bin/osascript -e $Script 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return ($output -join "`n")
}


<#
.SYNOPSIS
    Gets the base href for a file path.
.DESCRIPTION
    Converts a macOS file path to a file:// URL for use as the base href.
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

    # macOS: /Users/user/docs/ -> file:///Users/user/docs/
    return 'file://' + $dir + '/'
}


<#
.SYNOPSIS
    Tests if a file has a platform trust marker.
.DESCRIPTION
    On macOS, the com.apple.quarantine extended attribute marks downloaded files.
.PARAMETER FilePath
    The file path to check.
.OUTPUTS
    3 when quarantined, otherwise $null.
#>
function Test-Motw {
    [CmdletBinding()]
    [OutputType([System.Nullable[int]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    & /usr/bin/xattr -p com.apple.quarantine $FilePath >$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        return 3
    }

    return $null
}


<#
.SYNOPSIS
    Clears the platform trust marker from a file.
.DESCRIPTION
    Removes the macOS com.apple.quarantine extended attribute when present.
.PARAMETER FilePath
    The file path to clear.
#>
function Clear-FileTrustMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    & /usr/bin/xattr -d com.apple.quarantine $FilePath 2>$null
}


<#
.SYNOPSIS
    Gets the directory used for generated HTML output.
.OUTPUTS
    The output directory path.
#>
function Get-MarkViewOutputDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $cacheDir = Join-Path $HOME 'Library/Caches/MarkView'
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    return $cacheDir
}


<#
.SYNOPSIS
    Launches the default browser with a URL.
.DESCRIPTION
    Uses macOS Launch Services via /usr/bin/open.
.PARAMETER Url
    The URL to open.
#>
function Start-DefaultBrowser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Url
    )

    Start-Process '/usr/bin/open' -ArgumentList $Url
}


<#
.SYNOPSIS
    Initializes platform-specific UI requirements.
.DESCRIPTION
    No-op on macOS. Dialogs use osascript as needed.
#>
function Initialize-PlatformUI {
    [CmdletBinding()]
    param()
    # No initialization needed on macOS
}


<#
.SYNOPSIS
    Shows a downloaded-file security warning dialog.
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
    $message = ConvertTo-AppleScriptLiteral "$fileName`n`nThis file was downloaded from the internet. It may contain malicious content."
    $script = @"
set dialogResult to display dialog $message with title "Security Warning - MarkView" buttons {"Cancel", "Open", "Unblock & Open"} default button "Cancel" with icon caution
return button returned of dialogResult
"@

    $result = Invoke-AppleScript -Script $script
    if ($result -eq 'Unblock & Open') {
        return 'Unblock'
    }
    if ($result -eq 'Open') {
        return 'Open'
    }
    return 'Cancel'
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
        "The linked Markdown file could not be found:`n`n$FilePath`n`nLink: $FromLink"
    } else {
        "The Markdown file could not be found:`n`n$FilePath"
    }

    $literal = ConvertTo-AppleScriptLiteral $msg
    $script = "display dialog $literal with title `"MarkView`" buttons {`"OK`"} default button `"OK`" with icon caution"
    if (-not (Invoke-AppleScript -Script $script)) {
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

    $literal = ConvertTo-AppleScriptLiteral $Message
    $script = "display dialog $literal with title `"MarkView`" buttons {`"OK`"} default button `"OK`" with icon stop"
    if (-not (Invoke-AppleScript -Script $script)) {
        Write-Error $Message
    }
}


# Export functions - same platform contract as the other platform modules
Export-ModuleMember -Function @(
    # Shared cross-platform functions (re-exported from MarkdownViewer.Shared.psm1)
    'Invoke-HtmlSanitization'
    'Test-RemoteImages'
    'Repair-MarkdownLinks'
    'Repair-HtmlLinks'
    # macOS-specific implementations
    'Get-FileBaseHref'
    'Test-Motw'
    'Clear-FileTrustMarker'
    'Get-MarkViewOutputDirectory'
    'Start-DefaultBrowser'
    # Platform UI functions
    'Initialize-PlatformUI'
    'Show-MotwWarning'
    'Show-FileNotFound'
    'Show-ErrorDialog'
)
