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
- Dark mode support: Use the "Theme" toggle button in the top-right corner of the page to switch between system theme (follows OS preference) and inverted theme (opposite of system preference).- **Theme variations:** Click the theme variation button (e.g., "Light Theme: Default") below the Theme button to choose from 5 color scheme variations for each theme:
  - **Light themes:** Default, Warm, Cool, Sepia, High Contrast
  - **Dark themes:** Default, Warm, Cool, OLED Black, Dimmed
  - Hover over options to preview, click to select. Preferences are saved separately for light and dark modes.- **Linked markdown files:** Clicking links to other local `.md` files within a document opens them in Markdown Viewer. First time you click a linked Markdown file, Chrome/Edge will ask to allow launching the Markdown Viewer. Check ‘Always allow…’ to avoid future prompts.

## Uninstallation

- Run `UNINSTALL.cmd` (or `uninstall.ps1` directly).
- Alternatively, uninstall via Windows Settings > Apps > Apps & features (search for "Markdown Viewer").

## Requirements

- Windows 10 or later
- PowerShell 7 (pwsh) - automatically installed if missing

## Security

This tool includes several security measures for viewing Markdown files safely:

- **Content Security Policy (CSP):** The rendered HTML uses a strict CSP with a cryptographic nonce. Only the app's own scripts and styles execute; any scripts embedded in the Markdown (malicious or otherwise) are blocked by the browser.

- **HTML Sanitization:** Before rendering, the app strips dangerous HTML elements and attributes from the Markdown output:
  - Removes `<script>`, `<iframe>`, `<object>`, `<embed>`, `<meta>`, `<base>`, `<link>`, `<style>` tags
  - Removes event handlers (`onclick`, `onerror`, etc.)
  - Neutralizes `javascript:` URIs in links and sources
  - Blocks `data:` URIs in links (but allows them in images)
  
  This is defense-in-depth behind the CSP.

- **Mark-of-the-Web (MOTW) detection:** Files downloaded from the internet are flagged by Windows with a Zone Identifier. When you open such a file, the app displays a warning dialog with options to:
  - **Open** — view this time (will warn again next time)
  - **Unblock & Open** — permanently trust this file
  - **Cancel** — don't open

- **Read-only installation:** Installed files are marked read-only to deter casual tampering.

- **No network access:** The CSP blocks all network requests (`connect-src 'none'`). The rendered page cannot phone home or load remote resources.

- **Remote images opt-in:** By default, external images (badges, etc.) are blocked. If a Markdown file contains remote images, an "Images" button appears. Clicking it prompts for confirmation before enabling remote image loading. This preference is stored per-document and can be toggled back to local-only at any time.

### Limitations

- **Not a sandbox:** The app opens HTML in your default browser. While CSP blocks scripts and sanitization removes dangerous elements, a malicious Markdown file could still contain misleading HTML content (e.g., fake login forms). Exercise caution with files from untrusted sources.

- **No code signing:** The scripts are not digitally signed. If you're security-conscious, review the source code before running.

### Reporting issues

If you discover a security vulnerability, please open an issue on GitHub.


## Files

- `INSTALL.cmd` / `install.ps1`: Installation scripts
- `UNINSTALL.cmd` / `uninstall.ps1` / `uninstall.vbs`: Uninstallation scripts
- `payload/viewmd.vbs`: The main viewer script
- `payload/markdown-mark-solid-win10-light.ico` (used) / `payload/markdown-mark-solid-win10-filled.ico` (not used): Application icon (modified from the public domain Markdown Mark: https://github.com/dcurtis/markdown-mark)
- `payload/viewmd-experimental-not-used.reg`: Unused registry file (legacy)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
