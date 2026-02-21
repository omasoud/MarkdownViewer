[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [string] $StylePath = (Join-Path $PSScriptRoot 'style.css'),
    [string] $ScriptPath = (Join-Path $PSScriptRoot 'script.js'),
    [string] $IconPath = (Join-Path $PSScriptRoot 'markdown.ico'),
    [string] $HighlightJsPath = (Join-Path $PSScriptRoot 'highlight.min.js'),
    [string] $HighlightThemePath = (Join-Path $PSScriptRoot 'highlight-theme.css'),
    [string] $ModulePath = ''
)

$ErrorActionPreference = 'Stop'

# Import the platform module
# The module can be co-located with this script (ad-hoc/MSIX/Snap install) or in a sibling directory (development)
if (-not $ModulePath) {
    $ModulePath = Join-Path $PSScriptRoot 'MarkdownViewer.psm1'
}

if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    # Fallback: look for module relative to repo structure (for development from src/core)
    $platformDir = if ($IsWindows) { 'win' } else { 'linux' }
    $devModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "$platformDir/MarkdownViewer.psm1"
    if (Test-Path $devModulePath) {
        Import-Module $devModulePath -Force
    } else {
        throw "Cannot find MarkdownViewer.psm1 module at '$ModulePath' or '$devModulePath'"
    }
}

# Also check for icon in icons subdirectory (development structure)
if (-not (Test-Path $IconPath)) {
    $devIconPath = Join-Path $PSScriptRoot 'icons/markdown.ico'
    if (Test-Path $devIconPath) {
        $IconPath = $devIconPath
    }
}

Initialize-PlatformUI
	

# Note: Test-Motw, Get-FileBaseHref, Show-MotwWarning, Show-FileNotFound,
# and Show-ErrorDialog are now provided by the platform module


try {
    $raw = $Path
    $frag = ''

    if ($raw -match '^(?i)mdview:(.+)$') {
        $raw = $Matches[1]
    }

    if ($raw -match '^(?i)file:') {
        $u = [Uri]$raw

        # Extract _fragment from query string (cross-platform safe, no System.Web dependency).
        # _fragment is the app-contract transport for scroll targets — #hash is not used.
        if ($u.Query -match '[?&]_fragment=([^&#]*)') {
            $decoded = [Uri]::UnescapeDataString($Matches[1])
            if ($decoded) { $frag = '#' + $decoded }
        }

        # Build a clean URI (scheme + authority + path only) so LocalPath
        # is not polluted by query string characters.
        $clean = [UriBuilder]::new($u)
        $clean.Query = $null
        $clean.Fragment = $null
        $raw = $clean.Uri.LocalPath
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
            if ($IsWindows) {
                Unblock-File -LiteralPath $p
            }
        }
        elseif ($result -ne "Open") {
            exit 0
        }
    }

    $title = [System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p))
    $base = Get-FileBaseHref -FilePath $p

    $css = Get-Content -Raw -LiteralPath $StylePath
    $js = Get-Content -Raw -LiteralPath $ScriptPath
    
    # Read markdown, repair local file links, then convert to HTML
    $md = Get-Content -Raw -LiteralPath $p
    $md = Repair-MarkdownLinks -Markdown $md
    $html = (ConvertFrom-Markdown -InputObject $md).Html


    # --- HTML SANITIZATION (Defense-in-Depth) ---
    # Uses the module function which properly handles content in code blocks
    $html = Invoke-HtmlSanitization -Html $html
    
    # Post-process HTML to fix any remaining link encoding issues
    $html = Repair-HtmlLinks -Html $html

    # Detect remote images in the rendered HTML
    $hasRemoteImages = Test-RemoteImages -Html $html

    
    $favicon = ""
    if (Test-Path -LiteralPath $IconPath) {
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($IconPath))
        $favicon = "<link rel='icon' type='image/x-icon' href='data:image/x-icon;base64,$b64'>"
    }

    # Create a stable MD5 hash of the full path (but only keep the first 8 characters) so the temp filename is stable for this specific file
    # Windows paths are case-insensitive; Linux paths are case-sensitive
    $pathForHash = if ($IsWindows) { $p.ToLower() } else { $p }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pathForHash)
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

    # On Linux, browsers installed as snaps (e.g. Firefox on Ubuntu 22.04+)
    # cannot access hidden directories (dot-prefixed) or /tmp due to strict
    # confinement. The snap 'home' plug only exposes non-hidden paths under
    # $HOME, so we use ~/MarkView/ as the output directory.
    $outDir = if ($IsWindows) {
        [IO.Path]::GetTempPath()
    } else {
        $cacheDir = Join-Path $HOME 'MarkView'
        if (-not (Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        $cacheDir
    }
    $outLocal = Join-Path $outDir "$baseName.html"
    $outRemote = Join-Path $outDir ($baseName + "_remote.html")

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
        if ($IsWindows) {
            # Windows: use file:// URIs (same-origin works fine)
            $highlightJsUri = ([Uri]::new($HighlightJsPath)).AbsoluteUri
            $highlightThemeUri = ([Uri]::new($HighlightThemePath)).AbsoluteUri
        } else {
            # Linux: copy assets alongside the HTML so browsers (especially
            # snap-confined Firefox) can load them from the same directory.
            # Use file:// URIs to the copies (not relative paths, because
            # <base href> points at the markdown source directory).
            Copy-Item -LiteralPath $HighlightJsPath    -Destination $outDir -Force
            Copy-Item -LiteralPath $HighlightThemePath -Destination $outDir -Force
            $highlightJsUri = ([Uri]::new((Join-Path $outDir ([IO.Path]::GetFileName($HighlightJsPath))))).AbsoluteUri
            $highlightThemeUri = ([Uri]::new((Join-Path $outDir ([IO.Path]::GetFileName($HighlightThemePath))))).AbsoluteUri
        }
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
            scrollTarget  = if ($frag) { $frag.TrimStart('#') } else { $null }
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

    # Launch the HTML file in the default browser.
    # When _fragment is present, we MUST open as a URL (file:///…?_fragment=…)
    # via Start-DefaultBrowser, not as a filesystem path. On Windows,
    # Start-Process treats '?' as part of the filename and fails.
    # On Linux, Start-Process tries to exec the file directly, so always use
    # Start-DefaultBrowser which calls xdg-open.
    if ($frag -or -not $IsWindows) {
        $launchUrl = $uLocal
        if ($frag) {
            $launchUrl += '?_fragment=' + [Uri]::EscapeDataString($frag.TrimStart('#'))
        }
        Start-DefaultBrowser -Url $launchUrl
    } else {
        Start-Process $outLocal
    }
}
catch {
    $msg = $_.Exception.Message
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        $msg += "`r`n`r`n" + $_.InvocationInfo.PositionMessage
    }
    
    Show-ErrorDialog -Message $msg
}
