[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string] $Path,

  [string] $StylePath  = (Join-Path $PSScriptRoot 'style.html'),
  [string] $ScriptPath = (Join-Path $PSScriptRoot 'script.html'),
  [string] $IconPath   = (Join-Path $env:LOCALAPPDATA 'Programs\MarkdownViewer\markdown-mark-solid-win10-light.ico')
)

$ErrorActionPreference = 'Stop'

try {
  $p = (Resolve-Path -LiteralPath $Path).Path
  $title = [System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p))
  $base  = ([Uri]::new((Split-Path -LiteralPath $p) + '\')).AbsoluteUri

  $style  = Get-Content -Raw -LiteralPath $StylePath
  $script = Get-Content -Raw -LiteralPath $ScriptPath
  $html   = (ConvertFrom-Markdown -Path $p).Html

  $favicon = ""
  if (Test-Path -LiteralPath $IconPath) {
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($IconPath))
    $favicon = "<link rel='icon' type='image/x-icon' href='data:image/x-icon;base64,$b64'>"
  }

  $out = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.html')

  $doc = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
$favicon
<base href="$base">
<title>$title</title>
$style
</head>
<body>
<button id="mvTheme" type="button">Theme</button>
$script
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
    $msg = $msg + "`r`n`r`n" + $_.InvocationInfo.PositionMessage
  }
  [System.Windows.Forms.MessageBox]::Show($msg, "Markdown Viewer Error", 0, 16) | Out-Null
}
