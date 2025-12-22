# Markdown Viewer

A simple tool to view Markdown files rendered in your browser on Windows.

## Description

This project provides a way to open `.md` and `.markdown` files directly in your default web browser, rendered as HTML using PowerShell's built-in Markdown conversion. It uses a VBScript wrapper to execute PowerShell commands seamlessly.

## How It Works

When you open a Markdown file, the app uses PowerShell's `ConvertFrom-Markdown` cmdlet to transform the Markdown into HTML. To ensure the output doesn't look like it's 1995, it adds some basic CSS styling. The result is then saved as a temporary HTML file and opened in your default web browser. A VBScript wrapper handles the execution to avoid console flashes and ensure smooth operation. The browser tab will display the app's icon and the actual Markdown filename as the title.

Note: This is not a standalone executable app. Instead, it leverages Windows' built-in Windows Script Host (wscript.exe, located in System32) to run the VBScript, which in turn executes the PowerShell command.

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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
