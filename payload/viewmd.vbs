' viewmd.vbs
' Reliable: no console flash, ConvertFrom-Markdown -Path, styled HTML, temp file, message box on error.

Option Explicit

If WScript.Arguments.Count < 1 Then WScript.Quit 1

Dim mdPath : mdPath = WScript.Arguments(0)

Dim ps : ps = ""
ps = ps & "try { "
ps = ps & "$ErrorActionPreference='Stop'; "

' Embed the path directly (avoid $args quoting issues); escape single-quotes for PowerShell
ps = ps & "$p='" & Replace(mdPath, "'", "''") & "'; "

' Keep CSS as a single-quoted PS string (simplest for VBS embedding)
ps = ps & "$style='<style>"
ps = ps & "body{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:900px;margin:40px auto;padding:0 20px;line-height:1.6}"
ps = ps & "pre{background:#f4f4f4;padding:12px;overflow-x:auto;border-radius:8px}"
ps = ps & "code{background:#f4f4f4;padding:2px 6px;border-radius:6px}"
ps = ps & "table{border-collapse:collapse;margin:16px 0;width:100%}"
ps = ps & "th,td{border:1px solid #ddd;padding:6px 10px;text-align:left;vertical-align:top}"
ps = ps & "blockquote{border-left:4px solid #ddd;padding-left:12px;color:#444;margin:16px 0}"
ps = ps & "a{text-decoration:none}a:hover{text-decoration:underline}"
ps = ps & "</style>'; "

ps = ps & "$html=(ConvertFrom-Markdown -Path $p).Html; "
ps = ps & "$out=Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()+'.html'); "

' Title + base href (fix relative images/links); HTML-escape title
ps = ps & "$title=[System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p)); "
ps = ps & "$base=([Uri]::new((Split-Path $p)+'\')).AbsoluteUri; "

ps = ps & "$ico=Join-Path $env:LOCALAPPDATA 'Programs\MarkdownViewer\markdown-mark-solid-win10-light.ico'; "
ps = ps & "$favicon=(Test-Path -LiteralPath $ico) ? ('<link rel=''icon'' type=''image/x-icon'' href=''data:image/x-icon;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($ico)) + '''>') : ''; "

ps = ps & "Set-Content -NoNewline -LiteralPath $out -Encoding UTF8 -Value ('<html><head><meta charset=''utf-8''>'+ $favicon +'<base href='''+ $base +'''><title>'+ $title +'</title>'+ $style +'</head><body>'+ $html +'</body></html>'); "

ps = ps & "Start-Process $out; "

ps = ps & "} catch { "
ps = ps & "Add-Type -AssemblyName System.Windows.Forms; "
ps = ps & "[System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Markdown Error', 0); "
ps = ps & "}"

Dim cmd
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -Command """ & Replace(ps, """", "\""") & """"

CreateObject("WScript.Shell").Run cmd, 0, False
