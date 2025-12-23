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
ps = ps & ":root{color-scheme:light dark;--bg:#ffffff;--fg:#111111;--muted:#444;--codebg:#f4f4f4;--border:#dddddd;--link:#0b57d0}"
ps = ps & "@media (prefers-color-scheme: dark){:root{--bg:#0f1115;--fg:#e7e7e7;--muted:#b8b8b8;--codebg:#1b1f2a;--border:#2a2f3a;--link:#7ab7ff}}"
ps = ps & ":root[data-theme=""light""]{--bg:#ffffff;--fg:#111111;--muted:#444;--codebg:#f4f4f4;--border:#dddddd;--link:#0b57d0}"
ps = ps & ":root[data-theme=""dark""]{--bg:#0f1115;--fg:#e7e7e7;--muted:#b8b8b8;--codebg:#1b1f2a;--border:#2a2f3a;--link:#7ab7ff}"
ps = ps & "body{background:var(--bg);color:var(--fg);font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;max-width:900px;margin:40px auto;padding:0 20px;line-height:1.6}"
ps = ps & "pre{background:var(--codebg);padding:12px;overflow-x:auto;border-radius:8px}"
ps = ps & "code{background:var(--codebg);padding:2px 6px;border-radius:6px}"
ps = ps & "table{border-collapse:collapse;margin:16px 0;width:100%}"
ps = ps & "th,td{border:1px solid var(--border);padding:6px 10px;text-align:left;vertical-align:top}"
ps = ps & "blockquote{border-left:4px solid var(--border);padding-left:12px;color:var(--muted);margin:16px 0}"
ps = ps & "a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}"
ps = ps & "#mvTheme{position:fixed;top:14px;right:14px;z-index:9999;border:1px solid var(--border);background:var(--codebg);color:var(--fg);padding:6px 10px;border-radius:10px;cursor:pointer;font-size:12px}"
ps = ps & "</style>'; "

ps = ps & "$html=(ConvertFrom-Markdown -Path $p).Html; "
ps = ps & "$out=Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()+'.html'); "

' Title + base href (fix relative images/links); HTML-escape title
ps = ps & "$title=[System.Net.WebUtility]::HtmlEncode([IO.Path]::GetFileName($p)); "
ps = ps & "$base=([Uri]::new((Split-Path -LiteralPath $p)+'\')).AbsoluteUri; "


ps = ps & "$ico=Join-Path $env:LOCALAPPDATA 'Programs\MarkdownViewer\markdown-mark-solid-win10-light.ico'; "
ps = ps & "$favicon=(Test-Path -LiteralPath $ico) ? ('<link rel=''icon'' type=''image/x-icon'' href=''data:image/x-icon;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($ico)) + '''>') : ''; "
ps = ps & "$toggle='<button id=""mvTheme"" type=""button"">Theme</button>'; "

ps = ps & "$script='<script>(function(){"
ps = ps & "const k=""mdviewer_theme_mode"";"
ps = ps & "const r=document.documentElement;"
ps = ps & "const b=document.getElementById(""mvTheme"");"
ps = ps & "const m=window.matchMedia && window.matchMedia(""(prefers-color-scheme: dark)"");"
ps = ps & "function sysDark(){return !!(m && m.matches);}"
ps = ps & "function effective(mode){const d=sysDark(); const useDark=(mode===""invert"")?!d:d; return useDark?""dark"":""light"";}"
ps = ps & "function setLabel(mode, theme){"
ps = ps & "  const t=(theme===""dark"")?""Dark"":""Light"";"
ps = ps & "  b.textContent=(mode===""invert"")?(""Theme: Invert (""+t+"")""):( ""Theme: System (""+t+"")"" );"
ps = ps & "}"
ps = ps & "function apply(mode){const th=effective(mode); r.dataset.theme=th; setLabel(mode, th);}"
ps = ps & "let mode=localStorage.getItem(k)||""system"";"
ps = ps & "if(mode!==""system"" && mode!==""invert"") mode=""system"";"
ps = ps & "apply(mode);"
ps = ps & "b.addEventListener(""click"",function(){mode=(mode===""system"")?""invert"":""system""; localStorage.setItem(k,mode); apply(mode);});"
ps = ps & "if(m){"
ps = ps & "  const onChange=function(){apply(mode);};"
ps = ps & "  if(m.addEventListener) m.addEventListener(""change"", onChange); else m.addListener(onChange);"
ps = ps & "}"
ps = ps & "})();</script>'; "


ps = ps & "Set-Content -NoNewline -LiteralPath $out -Encoding UTF8 -Value ('<html><head><meta charset=''utf-8''>'+ $favicon +'<base href='''+ $base +'''><title>'+ $title +'</title>'+ $style +'</head><body>'+ $toggle + $script + $html +'</body></html>'); "


ps = ps & "Start-Process $out; "

ps = ps & "} catch { "
ps = ps & "Add-Type -AssemblyName System.Windows.Forms; "
ps = ps & "[System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Markdown Error', 0); "
ps = ps & "}"

Dim cmd
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -Command """ & Replace(ps, """", "\""") & """"

CreateObject("WScript.Shell").Run cmd, 0, False
