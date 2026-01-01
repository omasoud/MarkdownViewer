Option Explicit
Dim shell : Set shell = CreateObject("WScript.Shell")
Dim installDir : installDir = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Programs\MarkdownViewer"
Dim ps1 : ps1 = installDir & "\uninstall.ps1"
shell.Run "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
