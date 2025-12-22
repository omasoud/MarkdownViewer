# Markdown Viewer

A simple tool to view Markdown files rendered in your browser on Windows.

## Description

This project provides a way to open `.md` and `.markdown` files directly in your default web browser, rendered as HTML using PowerShell's built-in Markdown conversion. It uses a VBScript wrapper to execute PowerShell commands seamlessly.

## Installation

1. Download or clone this repository.
2. Run `INSTALL.cmd` (or `install.ps1` directly) as a user (no admin required for per-user installation).
3. The installer will:
   - Copy files to `%LOCALAPPDATA%\Programs\MarkdownViewer`.
   - Register file associations for `.md` and `.markdown` files.
   - Optionally add a "View Markdown" context menu item.
   - Optionally open Default Apps settings to set this as the default handler.
4. If PowerShell 7 (pwsh) is not installed, the installer will prompt you to install it.

## Usage

- After installation, double-click any `.md` or `.markdown` file to view it rendered in your default web browser.
- If the context menu was enabled during installation, right-click on a Markdown file and select "View Markdown".
- The rendered HTML includes basic styling for readability.

## Uninstallation

- Run `UNINSTALL.cmd` (or `uninstall.ps1` directly).
- Alternatively, uninstall via Windows Settings > Apps > Apps & features (search for "Markdown Viewer").

## Requirements

- Windows 10 or later
- PowerShell 7 (pwsh) - automatically installed if missing

## Files

- `INSTALL.cmd` / `install.ps1`: Installation scripts
- `UNINSTALL.cmd` / `uninstall.ps1` / `uninstall.vbs`: Uninstallation scripts
- `payload/viewmd.vbs`: The main viewer script
- `payload/markdown-mark-solid-win10-filled.ico`: Application icon (modified from the public domain Markdown Mark: https://github.com/dcurtis/markdown-mark)
- `payload/viewmd-experimental-not-used.reg`: Unused registry file (legacy)

## License

MIT License

Copyright (c) 2025 Markdown Viewer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.