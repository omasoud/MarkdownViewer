[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [string] $StylePath = (Join-Path $PSScriptRoot 'style.css'),
    [string] $ScriptPath = (Join-Path $PSScriptRoot 'script.js'),
    [string] $IconPath = (Join-Path $PSScriptRoot 'markdown.ico')
)

$ErrorActionPreference = 'Stop'

try {
    $p = (Resolve-Path -LiteralPath $Path).Path
    $title = [System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p))
    $base = ([Uri]::new((Split-Path -LiteralPath $p) + '\')).AbsoluteUri

    $css = Get-Content -Raw -LiteralPath $StylePath
    $js = Get-Content -Raw -LiteralPath $ScriptPath
    $html = (ConvertFrom-Markdown -Path $p).Html

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
    $out = Join-Path ([IO.Path]::GetTempPath()) ("viewmd_$($name)_$hash.html")

    # --- CSP + nonce ---
    # 1) nonce
    $nonceBytes = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($nonceBytes)
    $nonce = [Convert]::ToBase64String($nonceBytes)
 
    # 2) CSP: block everything by default; allow only your nonce'd inline JS/CSS;
    # allow local/data images (for local md images + favicon); no network. 
    $csp = @(
        "default-src 'none'",
        "connect-src 'none'",
        "object-src 'none'",
        "frame-src 'none'",
        "form-action 'none'",
        "base-uri file:",             # Vital for <base> tag to work with local images
        "img-src file: data:",        # Allows local images and embedded icon
        "style-src 'nonce-$nonce'",   # Blocks inline style="..." attributes
        "script-src 'nonce-$nonce'"   # Blocks all unauthorized scripts
    ) -join '; '

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
<script nonce="$nonce">
$js
</script>
$html
</body>
</html>
"@


    [IO.File]::WriteAllText($out, $doc, [Text.UTF8Encoding]::new($false))
    Start-Process $out
}
catch {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $msg = $_.Exception.Message
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        $msg += "`r`n`r`n" + $_.InvocationInfo.PositionMessage
    }
    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Markdown Viewer Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
