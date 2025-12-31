[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [string] $StylePath = (Join-Path $PSScriptRoot 'style.css'),
    [string] $ScriptPath = (Join-Path $PSScriptRoot 'script.js'),
    [string] $IconPath = (Join-Path $PSScriptRoot 'markdown.ico'),
    [string] $HighlightJsPath = (Join-Path $PSScriptRoot 'highlight.min.js'),
    [string] $HighlightThemePath = (Join-Path $PSScriptRoot 'highlight-theme.css')
)

$ErrorActionPreference = 'Stop'

# Import the shared module
Import-Module (Join-Path $PSScriptRoot 'MarkdownViewer.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles() # Required for TaskDialog
	

# Note: Test-Motw and Get-FileBaseHref are now provided by the MarkdownViewer module

function Show-MotwWarning {
    param([string]$FilePath)
    
    $fileName = [IO.Path]::GetFileName($FilePath)
    
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    
    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "Security Warning - Markdown Viewer"
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
    [System.Windows.Forms.Application]::DoEvents() # Required 
    
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

function Show-FileNotFound {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$FromLink = ''
    )

    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true

    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "Markdown Viewer"
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


try {
    $raw = $Path
    $frag = ''

    if ($raw -match '^(?i)mdview:(.+)$') {
        $raw = $Matches[1]
    }

    if ($raw -match '^(?i)file:') {
        $u = [Uri]$raw
        $frag = $u.Fragment  # includes leading '#', or empty
        $raw = $u.LocalPath
    }
    else {
        # If someone passes a literal path containing '#', treat it as fragment.
        $hash = $raw.IndexOf('#')
        if ($hash -ge 0) {
            $frag = $raw.Substring($hash)
            $raw = $raw.Substring(0, $hash)
        }
    }

    # $raw is the path after decoding (no fragment)
    if (-not (Test-Path -LiteralPath $raw)) {
        # Optional: if we still have the original incoming argument, pass it as context
        Show-FileNotFound -FilePath $raw -FromLink $Path
        return
    }

    $p = (Resolve-Path -LiteralPath $raw).Path
	
    # --- MOTW check (early exit if user cancels) ---
    # 0 = Local machine
    # 1 = Local intranet
    # 2 = Trusted sites
    # 3 = Internet
    # 4 = Restricted sites
    # Checking $zone -ge 3 catches both Internet and Restricted zones.    
    $zone = Test-Motw -FilePath $p
    if ($zone -ge 3) {
        $result = Show-MotwWarning -FilePath $p
		
        if ($result -eq "Unblock") {
            Unblock-File -LiteralPath $p
        }
        elseif ($result -ne "Open") {
            exit 0
        }
    }

    $title = [System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p))
    $base = Get-FileBaseHref -FilePath $p

    $css = Get-Content -Raw -LiteralPath $StylePath
    $js = Get-Content -Raw -LiteralPath $ScriptPath
    $html = (ConvertFrom-Markdown -Path $p).Html


    # --- HTML SANITIZATION (Defense-in-Depth) ---
    # Uses the module function which properly handles content in code blocks
    $html = Invoke-HtmlSanitization -Html $html

    # Detect remote images in the rendered HTML
    $hasRemoteImages = Test-RemoteImages -Html $html

    
    $favicon = ""
    if (Test-Path -LiteralPath $IconPath) {
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($IconPath))
        $favicon = "<link rel='icon' type='image/x-icon' href='data:image/x-icon;base64,$b64'>"
    }

    # Create a stable MD5 hash of the full path (but only keep the first 8 characters) so the temp filename is stable for this specific file
    # We use ToLower() because Windows paths are case-insensitive
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($p.ToLower())
    $hashBytes = [System.Security.Cryptography.MD5]::Create().ComputeHash($bytes)
    $hash = [BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 8)

    # Also, include the filename (truncated if too long) in the temp filename
    $name = [IO.Path]::GetFileNameWithoutExtension($p) -replace '[^\w\-]', '_'
    $maxLen = 18
    if ($name.Length -gt $maxLen) {
        $keep = [int](($maxLen - 2) / 2)  # 8 chars each side
        $name = $name.Substring(0, $keep) + ".." + $name.Substring($name.Length - $keep)
    }
    $baseName = "viewmd_$($name)_$hash"
    $outLocal = Join-Path ([IO.Path]::GetTempPath()) "$baseName.html"
    $outRemote = Join-Path ([IO.Path]::GetTempPath()) ($baseName + "_remote.html")

    $uLocal = ([Uri]::new($outLocal)).AbsoluteUri
    $uRemote = ([Uri]::new($outRemote)).AbsoluteUri    

    function New-Csp([bool]$allowRemoteImages, [string]$nonce) {
        # CSP: block everything by default; allow only your nonce'd inline JS/CSS;
        # allow local/data images (for local md images + favicon); no network.
        # allow remote images if $allowRemoteImages is $true
        #
        # SECURITY NOTE: file: in script-src/style-src allows local JS/CSS to load.
        # This is safe ONLY because Invoke-HtmlSanitization strips ALL <script>,
        # <link>, and <style> tags from markdown content before HTML generation.
        # Without sanitization, malicious markdown could reference local scripts.

        $img = if ($allowRemoteImages) { "img-src file: data: https:" } else { "img-src file: data:" }

        @(
            "default-src 'none'",
            "connect-src 'none'",
            "object-src 'none'",
            "frame-src 'none'",
            "form-action 'none'",
            "base-uri file:",
            $img,
            "style-src 'nonce-$nonce' file:",
            "script-src 'nonce-$nonce' file:"
        ) -join '; '
    }

    # nonce
    $nonceBytes = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonceBytes)
    $nonce = [Convert]::ToBase64String($nonceBytes)

    # Generate highlight.js asset URLs (only if both files exist)
    $highlightThemeLink = ''
    $highlightScript = ''
    if ((Test-Path -LiteralPath $HighlightJsPath) -and (Test-Path -LiteralPath $HighlightThemePath)) {
        $highlightJsUri = ([Uri]::new($HighlightJsPath)).AbsoluteUri
        $highlightThemeUri = ([Uri]::new($HighlightThemePath)).AbsoluteUri
        $highlightThemeLink = "<link rel=`"stylesheet`" href=`"$highlightThemeUri`">"
        $highlightScript = "<script src=`"$highlightJsUri`" defer></script>"
    }

    
    function Write-Doc([string]$outPath, [bool]$allowRemoteImages, [bool]$hasRemoteImages) {
        $csp = New-Csp -allowRemoteImages:$allowRemoteImages -nonce $nonce

        $cfgObj = @{
            docId         = $hash
            localUrl      = $uLocal
            remoteUrl     = if ($hasRemoteImages) { $uRemote } else { "" }
            remoteEnabled = $allowRemoteImages
            hasRemoteImgs = $hasRemoteImages
            mdDirBase     = $base
        }
        $cfg = $cfgObj | ConvertTo-Json -Compress
        $js2 = "window.mdviewer_config=$cfg;`n" + $js

        $imgButton = if ($hasRemoteImages) { '<button id="mvImages" type="button">Images</button>' } else { '' }

        $doc = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="$csp">
<meta name="referrer" content="no-referrer">
$favicon
<base href="$base">
<title>$title</title>
<style nonce="$nonce">
$css
</style>
$highlightThemeLink
</head>
<body>
<button id="mvTheme" type="button">Theme</button>
$imgButton
$highlightScript
<script nonce="$nonce">
$js2
</script>
$html
</body>
</html>
"@

        [IO.File]::WriteAllText($outPath, $doc, [Text.UTF8Encoding]::new($false))
    }

    Write-Doc -outPath $outLocal -allowRemoteImages:$false -hasRemoteImages:$hasRemoteImages

    if ($hasRemoteImages) {
        Write-Doc -outPath $outRemote -allowRemoteImages:$true -hasRemoteImages:$hasRemoteImages
    }

    $launch = if ($frag) { $outLocal + $frag } else { $outLocal }
    Start-Process $launch
}
catch {
    $msg = $_.Exception.Message
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        $msg += "`r`n`r`n" + $_.InvocationInfo.PositionMessage
    }
    
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    
    $page = New-Object System.Windows.Forms.TaskDialogPage
    $page.Caption = "Markdown Viewer"
    $page.Heading = "Error opening file"
    $page.Text = $msg
    $page.Icon = [System.Windows.Forms.TaskDialogIcon]::Error
    $page.Buttons.Add([System.Windows.Forms.TaskDialogButton]::OK)
    
    [System.Windows.Forms.TaskDialog]::ShowDialog($owner.Handle, $page) | Out-Null
    $owner.Dispose()
    [System.Windows.Forms.Application]::DoEvents()
}
