[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [string] $StylePath = (Join-Path $PSScriptRoot 'style.css'),
    [string] $ScriptPath = (Join-Path $PSScriptRoot 'script.js'),
    [string] $IconPath = (Join-Path $PSScriptRoot 'markdown.ico')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles() # Required for TaskDialog
	

function Test-Motw {
    param([string]$FilePath)
    
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

function Get-FileBaseHref {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string] $FilePath
  )

  $dir = Split-Path -LiteralPath $FilePath

  if ($dir.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
    # \\?\UNC\server\share\path -> file://server/share/path/
    $unc = $dir.Substring(8)
    return 'file://' + ($unc.Replace('\','/')) + '/'
  }

  if ($dir.StartsWith('\\', [StringComparison]::OrdinalIgnoreCase) -and
      -not $dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
    # \\server\share\path -> file://server/share/path/
    return 'file://' + ($dir.TrimStart('\').Replace('\','/')) + '/'
  }

  if ($dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
    # \\?\C:\path -> file:///C:/path/
    $norm = $dir.Substring(4)
    return 'file:///' + ($norm.Replace('\','/')) + '/'
  }

  # C:\path -> file:///C:/path/
  return 'file:///' + ($dir.Replace('\','/')) + '/'
}


try {
    $p = (Resolve-Path -LiteralPath $Path).Path
	
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

    # 1) Drop dangerous elements (paired, self-closing, and leftover start tags)
    $dangerousTags = 'script|object|embed|iframe|meta|base|link|style'

    # paired: <tag ...> ... </tag>
    $html = $html -replace "(?is)<\s*($dangerousTags)\b[^>]*>.*?</\s*\1\s*>", ''

    # self-closing: <tag ... />
    $html = $html -replace "(?is)<\s*($dangerousTags)\b[^>]*/\s*>", ''

    # leftover start tags: <meta ...> or malformed starts
    $html = $html -replace "(?is)<\s*($dangerousTags)\b[^>]*>", ''

    # 2) Remove event handlers (quoted or unquoted)
    $html = $html -replace '(?is)\s+on[a-z0-9_-]+\s*=\s*(?:"[^"]*"|''[^'']*''|[^\s>]+)', ''

    # 3) Neutralize javascript: URIs in href/src/xlink:href/srcset
    $html = $html -replace '(?is)\b(href|src|xlink:href|srcset)\s*=\s*(?:"\s*javascript:[^"]*"|''\s*javascript:[^'']*''|\s*javascript:[^\s>]+)', '$1="#"'

    # 4) Block data: URIs only in href/xlink:href (not src, to preserve images)
    $html = $html -replace '(?is)\b(href|xlink:href)\s*=\s*(?:"\s*data:[^"]*"|''\s*data:[^'']*''|\s*data:[^\s>]+)', '$1="#"'

    # Detect remote images in the rendered HTML (<img src=...> or srcset=... containing https/http or //)
    $hasRemoteImages =
    $html -match '(?is)<img\b[^>]*(?:\bsrc\b|\bsrcset\b)\s*=\s*(?:"[^"]*(?:https?:|//)|''[^'']*(?:https?:|//)|\s*(?:https?:|//))'

    
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

        $img = if ($allowRemoteImages) { "img-src file: data: https:" } else { "img-src file: data:" }

        @(
            "default-src 'none'",
            "connect-src 'none'",
            "object-src 'none'",
            "frame-src 'none'",
            "form-action 'none'",
            "base-uri file:",
            $img,
            "style-src 'nonce-$nonce'",
            "script-src 'nonce-$nonce'"
        ) -join '; '
    }

    # nonce
    $nonceBytes = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonceBytes)
    $nonce = [Convert]::ToBase64String($nonceBytes)

    
    function Write-Doc([string]$outPath, [bool]$allowRemoteImages, [bool]$hasRemoteImages) {
        $csp = New-Csp -allowRemoteImages:$allowRemoteImages -nonce $nonce

        $cfgObj = @{
            docId         = $hash
            localUrl      = $uLocal
            remoteUrl     = if ($hasRemoteImages) { $uRemote } else { "" }
            remoteEnabled = $allowRemoteImages
            hasRemoteImgs = $hasRemoteImages
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
</head>
<body>
<button id="mvTheme" type="button">Theme</button>
$imgButton
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

    Start-Process $outLocal
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
