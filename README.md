# Markdown Viewer

A simple tool to view Markdown files rendered in your browser. Supports Windows, Linux, and macOS.

## Description

This project provides a way to open `.md` and `.markdown` files directly in your default web browser, rendered as HTML using PowerShell's built-in Markdown conversion.

## How It Works

When you open a Markdown file, the app uses PowerShell's `ConvertFrom-Markdown` cmdlet to transform the Markdown into HTML. To ensure the output doesn't look like it's 1995, it adds some basic CSS styling. The result is then saved as a temporary HTML file and opened in your default web browser. The browser tab will display the app's icon and the actual Markdown filename as the title.

## Installation

### Option 1: Microsoft Store (MSIX)

PowerShell 7 is bundled in the package—no separate installation required.

1. Install from the [Microsoft Store](https://apps.microsoft.com/detail/9MSWK3Q0JZ5N?hl=en-us&gl=US&ocid=pdpshare)
2. The app will optionally show the user how to make it the defailt handler for `.md` and `.markdown` files

**Architecture support:** x64 package is available (ARM64 at a future release)

### Option 1b: Sideload MSIX (Developer)

For testing or development builds without the Store:

1. Clone this repository
2. Build the MSIX package:
   ```powershell
   cd installers/win-msix
   .\build.ps1 -Sign  # Creates and signs with dev certificate
   ```
3. Double-click the generated `.msix` file in `installers/win-msix/output/`

**Note:** First-time sideloading requires either:
- Developer Mode enabled in Windows Settings, or
- A signed package (the `-Sign` flag handles this automatically)

### Option 2: Ad-hoc Installer (Per-User)

For manual installation without the Store:

1. Download or clone this repository.
2. Navigate to `installers/win-adhoc/`
3. Run `INSTALL.cmd` (or `install.ps1` directly) as a user (no admin required).
4. The installer will:
   - Copy files to `%LOCALAPPDATA%\Programs\MarkdownViewer`.
   - Register file associations for `.md` and `.markdown` files.
   - Optionally add a "View Markdown" context menu item.
   - Optionally open Default Apps settings to set this as the default handler.
5. If PowerShell 7 (pwsh) is not installed, the installer will prompt you to install it.

### Linux: Snap Package (Ubuntu)

PowerShell 7 is bundled in the snap—no separate installation required.

```bash
sudo snap install markview
```

The snap registers file associations for `.md` and `.markdown` files and the `mdview:` URI scheme for linked-file navigation.

**Architecture support:** arm64 and amd64

### Linux: Run from Source (Developer)

For testing or development without building a snap:

1. Install PowerShell 7:
   ```bash
   # Ubuntu amd64
   sudo apt-get update && sudo apt-get install -y powershell

   # Ubuntu arm64 (tarball — apt repo is x64-only)
   PWSH_VERSION="7.6.3"
   wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-arm64.tar.gz" -O /tmp/pwsh.tar.gz
   sudo mkdir -p /opt/microsoft/powershell/7
   sudo tar xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7
   sudo chmod +x /opt/microsoft/powershell/7/pwsh
   sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
   ```
2. Clone this repository and run directly:
   ```bash
   src/linux/markview path/to/file.md
   ```
3. Optionally register for desktop integration:
   ```bash
   sudo cp src/linux/markview /usr/local/bin/markview
   cp src/linux/markview.desktop ~/.local/share/applications/
   update-desktop-database ~/.local/share/applications/
   xdg-mime default markview.desktop text/markdown text/x-markdown x-scheme-handler/mdview
   ```

### macOS: DMG Package (Apple Silicon)

PowerShell 7 is bundled in the app - no separate installation required.

1. Download `MarkView_<version>_arm64.dmg` from the release artifacts.
2. Open the DMG and drag `MarkView.app` to Applications.
3. Open a `.md` or `.markdown` file with MarkView from Finder.

**Architecture support:** arm64

Developer builds can be created locally:

```bash
cd installers/macos-dmg
./build.sh
```

The generated DMG is written to `installers/macos-dmg/output/`.

### macOS: Run from Source (Developer)

For testing or development without building the app bundle:

1. Install PowerShell 7.
2. Clone this repository and run directly:
   ```bash
   src/mac/markview path/to/file.md
   ```

## Usage

- **Windows:** After installation, double-click any `.md` or `.markdown` file to view it rendered in your default web browser. If the context menu was enabled during installation, right-click on a Markdown file and select "View Markdown".
- **Linux:** Run `markview file.md` from the terminal, or right-click a `.md` file in your file manager and open with MarkView.
- **macOS:** Open a Markdown file with `MarkView.app` from Finder, or run `src/mac/markview file.md` from a source checkout.
- The rendered HTML includes basic styling for readability.
- **Dark mode support:** Use the "Theme" toggle button in the top-right corner of the page to switch between system theme (follows OS preference) and inverted theme (opposite of system preference).
- **Theme variations:** Click the theme variation button (e.g., "Light Theme: Default") below the Theme button to choose from 5 color scheme variations for each theme:
  - **Light themes:** Default, Warm, Cool, Sepia, High Contrast
  - **Dark themes:** Default, Warm, Cool, OLED Black, Dimmed
  - Hover over options to preview, click to select. Preferences are saved separately for light and dark modes.
- **Syntax highlighting:** Fenced code blocks with language tags (e.g., \`\`\`powershell, \`\`\`javascript) are automatically highlighted using highlight.js. Supported language aliases include:
  - **PowerShell:** `powershell`, `ps1`, `pwsh`, `psm1`, `psd1`
  - **JavaScript/TypeScript:** `javascript`, `js`, `typescript`, `ts`, `jsx`, `tsx`
  - **Web:** `html`, `css`, `json`, `xml`, `yaml`, `yml`
  - **Other:** `python`, `py`, `bash`, `sh`, `sql`, `csharp`, `cs`, `cpp`, `c`, `java`, `go`, `rust`, `ruby`, `rb`, `php`, `markdown`, `md`, `diff`, `dockerfile`
  - Supports all languages included in the bundled `highlight.min.js` (currently 192 languages)
  - Code blocks without a recognized language tag are displayed as plain preformatted text (no auto-detection).
- **Linked markdown files:** Clicking links to other local `.md` files within a document opens them in Markdown Viewer. First time you click a linked Markdown file, Chrome/Edge will ask to allow launching the Markdown Viewer. Check 'Always allow…' to avoid future prompts.

## Uninstallation

### MSIX Version (Windows)
- Uninstall via Windows Settings > Apps > Installed apps (search for "Markdown Viewer")

### Ad-hoc Version (Windows)
- Navigate to `installers/win-adhoc/` and run `UNINSTALL.cmd` (or `uninstall.ps1` directly)
- Alternatively, uninstall via Windows Settings > Apps > Apps & features (search for "Markdown Viewer")

### Snap (Linux)
```bash
sudo snap remove markview
```

### macOS
- Drag `MarkView.app` from Applications to Trash.
- Optional: remove generated HTML/cache files from `~/Library/Caches/MarkView`.

## Requirements

### Windows
- Windows 10 (version 2004/19041) or later
- PowerShell 7 (pwsh)
  - **MSIX:** Bundled in the package
  - **Ad-hoc:** Automatically installed if missing

### Linux
- Ubuntu 24.04+ (or compatible distribution)
- PowerShell 7 (pwsh)
  - **Snap:** Bundled in the package
  - **From source:** Install separately (see installation instructions)
- `xdg-open` for launching the default browser (pre-installed on most desktops)
- `zenity` for dialog boxes (optional; falls back to terminal warnings)

### macOS
- macOS 14+ on Apple Silicon
- PowerShell 7 (pwsh)
  - **DMG:** Bundled in the app
  - **From source:** Install separately
- Xcode Command Line Tools for building the DMG locally

## Security

This tool includes several security measures for viewing Markdown files safely:

- **Content Security Policy (CSP):** The rendered HTML uses a strict CSP with a cryptographic nonce. Only the app's own scripts and styles execute; any scripts embedded in the Markdown (malicious or otherwise) are blocked by the browser. The CSP allows loading local files (`file:` scheme) for syntax highlighting assets, but HTML sanitization (below) ensures no unauthorized file references exist in the rendered output.

- **HTML Sanitization:** Before rendering, the app strips dangerous HTML elements and attributes from the Markdown output:
  - Removes `<script>`, `<iframe>`, `<object>`, `<embed>`, `<meta>`, `<base>`, `<link>`, `<style>` tags
  - Removes event handlers (`onclick`, `onerror`, etc.)
  - Neutralizes `javascript:` URIs in links and sources
  - Blocks `data:` URIs in links (but allows them in images)
  
  This sanitization is the primary security barrier. The CSP provides defense-in-depth, blocking execution even if sanitization were bypassed.

- **Mark-of-the-Web (MOTW) detection (Windows):** Files downloaded from the internet are flagged by Windows with a Zone Identifier. When you open such a file, the app displays a warning dialog with options to:
  - **Open** — view this time (will warn again next time)
  - **Unblock & Open** — permanently trust this file
  - **Cancel** — don't open
  
  **macOS quarantine detection:** macOS files with the `com.apple.quarantine` attribute receive the same warning flow. Choosing **Unblock & Open** removes that quarantine attribute.

  *Note: Linux has no MOTW equivalent. Downloaded files open without a warning.*

- **Read-only installation:** Installed files are marked read-only to deter casual tampering.

- **No network access:** The CSP blocks all network requests (`connect-src 'none'`). The rendered page cannot phone home or load remote resources.

- **Remote images opt-in:** By default, external images (badges, etc.) are blocked. If a Markdown file contains remote images, an "Images" button appears. Clicking it prompts for confirmation before enabling remote image loading. This preference is stored per-document and can be toggled back to local-only at any time.

### Limitations

- **Not a sandbox:** The app opens HTML in your default browser. While CSP blocks scripts and sanitization removes dangerous elements, a malicious Markdown file could still contain misleading HTML content (e.g., fake login forms). Exercise caution with files from untrusted sources.

- **Code signing:** Windows Store/MSIX and macOS release builds should be signed through their platform packaging flows. Source scripts and local developer builds may be unsigned or ad-hoc signed; if you're security-conscious, review the source before running.

### Reporting issues

If you discover a security vulnerability, please open an issue on GitHub.


## Project Structure

```
MarkdownViewer/
├── src/
│   ├── core/                        # Cross-platform engine + assets
│   │   ├── Open-Markdown.ps1        # Main PowerShell engine
│   │   ├── MarkdownViewer.Shared.psm1 # Shared cross-platform module
│   │   ├── script.js                # Client-side JavaScript
│   │   ├── style.css                # Client-side CSS
│   │   ├── highlight.min.js         # Syntax highlighting (highlight.js)
│   │   ├── highlight-theme.css      # Highlight.js theme
│   │   └── icons/                   # Application icons
│   ├── win/                         # Windows platform module
│   │   ├── MarkdownViewer.psm1      # Windows-specific functions
│   │   ├── viewmd.vbs               # VBScript launcher (ad-hoc)
│   │   └── uninstall.vbs            # Silent uninstall helper
│   ├── linux/                       # Linux platform module
│   │   ├── MarkdownViewer.psm1      # Linux-specific functions
│   │   ├── markview                 # Bash launcher script
│   │   ├── markview.desktop         # Freedesktop desktop entry
│   │   └── markview.png             # Application icon (256x256)
│   ├── mac/                         # macOS platform module
│   │   ├── MarkdownViewer.psm1      # macOS-specific functions
│   │   └── markview                 # Bash launcher script
│   └── host/                        # Native host applications
│       ├── MarkdownViewerHost/      # Windows .NET host
│       └── MarkdownViewerMacHost/   # macOS Swift/AppKit host
├── installers/
│   ├── win-adhoc/                   # Per-user ad-hoc installer
│   │   ├── INSTALL.cmd
│   │   ├── UNINSTALL.cmd
│   │   ├── install.ps1
│   │   └── uninstall.ps1
│   ├── win-msix/                    # MSIX packaging
│   │   ├── Package.appxmanifest
│   │   └── build.ps1
│   ├── linux-snap/                  # Snap packaging (Linux)
│   │   ├── snap/snapcraft.yaml
│   │   ├── build.sh                 # Stage + trim + build snap
│   │   └── scripts/                 # Trimming & verification
│   └── macos-dmg/                   # DMG packaging (macOS)
│       ├── build.sh                 # Stage + trim + build DMG
│       └── scripts/                 # Icon, signing, trimming, verification
├── tests/
│   ├── MarkdownViewer.Tests.ps1     # Core Pester tests
│   ├── local-file-normalization/    # Manual link test sources (Windows)
│   ├── local-file-normalization-linux/ # Manual link test sources (Linux)
│   ├── local-file-normalization-macos/ # Manual link test sources (macOS)
│   ├── pwsh/                        # Additional Pester tests
│   │   ├── LinuxModule.Tests.ps1
│   │   ├── MacModule.Tests.ps1
│   │   ├── MacBundle.Tests.ps1
│   │   ├── SnapBuild.Tests.ps1
│   │   └── ...                      # Browser, normalization, etc.
│   └── MarkdownViewerHost.Tests/    # C# xUnit tests
└── dev/
    └── docs/                        # Development documentation
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This project includes third-party software (highlight.js) under separate licenses - see [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for details.
