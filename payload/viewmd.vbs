Option Explicit
If WScript.Arguments.Count < 1 Then WScript.Quit 1
Dim mdPath : mdPath = WScript.Arguments(0)

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim scriptDir : scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

Dim cmd
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File """ & scriptDir & "\Open-Markdown.ps1"" -Path """ & mdPath & """"
CreateObject("WScript.Shell").Run cmd, 0, False
