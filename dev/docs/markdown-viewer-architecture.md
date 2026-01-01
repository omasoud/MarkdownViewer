# Markdown Viewer Architecture

## Overview

Markdown Viewer is a Windows application that renders Markdown files as styled HTML in the user's default web browser. It is designed as a lightweight, per-user installable tool that requires no administrator privileges.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            User Interaction                                  │
│  (Double-click .md file, Context menu, or mdview: protocol link)            │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         viewmd.vbs (Entry Point)                            │
│  - Windows Script Host wrapper                                              │
│  - Launches pwsh silently (no console flash)                                │
│  - Passes markdown file path to PowerShell                                  │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Open-Markdown.ps1 (Core Logic)                        │
│  - Parses input path (file:, mdview: protocols, fragments)                  │
│  - MOTW security check + user prompts                                       │
│  - Converts Markdown → HTML via ConvertFrom-Markdown                        │
│  - Sanitizes HTML (removes dangerous elements/attributes)                   │
│  - Injects CSS, JS, CSP, highlight.js, favicon into HTML document           │
│  - Writes temp HTML file(s) to %TEMP%                                       │
│  - Launches default browser                                                 │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                              ▼
┌───────────────────────────────┐  ┌───────────────────────────────────────────┐
│  MarkdownViewer.psm1 (Module) │  │           Generated HTML Document          │
│  - Invoke-HtmlSanitization    │  │  ┌─────────────────────────────────────┐   │
│  - Test-RemoteImages          │  │  │ <head>                              │   │
│  - Get-FileBaseHref           │  │  │   - CSP meta tag (nonce-based)      │   │
│  - Test-Motw                  │  │  │   - Inline CSS (style.css)          │   │
└───────────────────────────────┘  │  │   - highlight-theme.css (file:)     │   │
                                   │  │   - Base href for relative links    │   │
                                   │  │   - Favicon (base64-encoded)        │   │
                                   │  └─────────────────────────────────────┘   │
                                   │  ┌─────────────────────────────────────┐   │
                                   │  │ <body>                              │   │
                                   │  │   - Theme toggle button             │   │
                                   │  │   - Images toggle button (if needed)│   │
                                   │  │   - Inline JS (script.js)           │   │
                                   │  │   - highlight.min.js (file: defer)  │   │
                                   │  │   - Sanitized HTML content          │   │
                                   │  └─────────────────────────────────────┘   │
                                   └───────────────────────────────────────────┘
```

## Component Details

### 1. Entry Point: viewmd.vbs

**Purpose:** Silent launcher that avoids console window flashes.

**Location:** `payload/viewmd.vbs`

**Flow:**
1. Receives markdown file path as command-line argument
2. Constructs pwsh command with `Open-Markdown.ps1`
3. Executes via `WScript.Shell.Run` with hidden window

```vb
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File ""...\Open-Markdown.ps1"" -Path ""..."""
CreateObject("WScript.Shell").Run cmd, 0, False
```

### 2. Core Logic: Open-Markdown.ps1

**Purpose:** Main orchestration script that handles the full conversion pipeline.

**Location:** `src/core/Open-Markdown.ps1`

**Key Responsibilities:**

| Function | Description |
|----------|-------------|
| Path Resolution | Handles `file:`, `mdview:` protocols and `#fragment` parsing |
| Security Check | Detects MOTW (Mark-of-the-Web) and prompts user |
| Markdown Conversion | Uses `ConvertFrom-Markdown` cmdlet |
| HTML Sanitization | Calls module function to remove dangerous content |
| Document Assembly | Injects CSS, JS, CSP headers, favicon |
| Output | Writes temp HTML and launches browser |

**Generated Files:**
- `%TEMP%\viewmd_<name>_<hash>.html` - Local-only images version
- `%TEMP%\viewmd_<name>_<hash>_remote.html` - Remote images enabled (if needed)

### 3. Shared Module: MarkdownViewer.psm1

**Purpose:** Reusable functions extracted for testability.

**Location:** `src/win/MarkdownViewer.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|---------|
| `Invoke-HtmlSanitization` | Removes dangerous HTML elements and event handlers |
| `Test-RemoteImages` | Detects `https://`, `http://`, `//` in `<img>` tags |
| `Get-FileBaseHref` | Converts file path to `file://` URL |
| `Test-Motw` | Reads Zone.Identifier alternate data stream |

### 4. Client-Side: style.css

**Purpose:** Provides visual styling for rendered Markdown.

**Location:** `src/core/style.css`

**Features:**
- CSS custom properties (variables) for theming
- Light/dark theme support via `data-theme` attribute
- System preference detection via `prefers-color-scheme`
- Fixed-position UI buttons (Theme, Images)
- Responsive typography and layout

**Theme Variables:**
```css
--bg       /* Background color */
--fg       /* Foreground/text color */
--muted    /* Secondary text color */
--codebg   /* Code block background */
--border   /* Border color */
--link     /* Link color */
```

### 5. Client-Side: script.js

**Purpose:** Interactive behavior in the rendered HTML.

**Location:** `src/core/script.js`

**IIFE Modules:**

| Module | Purpose |
|--------|---------|
| Theme Toggle | Switches between System/Invert mode, persists to localStorage |
| Theme Variations | Manages 5 color scheme variations per theme (Default, Warm, Cool, etc.) |
| Remote Images | Manages opt-in for remote image loading, page switching |
| Anchor Rewrite | Fixes in-page `#anchor` links for file:// context |
| Markdown Links | Rewrites local `.md` links to use `mdview:` protocol |
| Syntax Highlighting | Applies highlight.js to fenced code blocks with language tags |

**localStorage Keys:**
- `mdviewer_theme_mode` - "system" or "invert"
- `mdviewer_theme_variation_light` - Light theme variation (e.g., "default", "warm", "cool", "sepia", "high-contrast")
- `mdviewer_theme_variation_dark` - Dark theme variation (e.g., "default", "warm", "cool", "oled", "dimmed")
- `mdviewer_remote_images_<docId>` - "0" or "1"
- `mdviewer_remote_images_ack_<docId>` - "1" (user acknowledged prompt)

### 6. Syntax Highlighting: highlight.min.js & highlight-theme.css

**Purpose:** Provides syntax highlighting for fenced code blocks with language tags.

**Location:** `src/core/highlight.min.js`, `src/core/highlight-theme.css`

**Architecture:**
- **highlight.min.js:** Full highlight.js UMD bundle (~1MB) with all 190+ languages
- **highlight-theme.css:** Combined Tomorrow/Tomorrow Night theme with transparent backgrounds
- Both files loaded via `file:` URLs (external scripts/styles)

**Language Alias Map (script.js):**
Maps common aliases to canonical highlight.js language names:
```javascript
const LANG_MAP = {
    'ps1': 'powershell', 'pwsh': 'powershell', 'psm1': 'powershell', 'psd1': 'powershell',
    'js': 'javascript', 'ts': 'typescript', 'jsx': 'javascript', 'tsx': 'typescript',
    'yml': 'yaml', 'py': 'python', 'sh': 'bash', 'cs': 'csharp', 'rb': 'ruby',
    'md': 'markdown', 'dockerfile': 'docker', 'c++': 'cpp', /* ... */
};
```

**Performance Guards:**
- `MAX_BLOCK_SIZE = 102400` (100KB) - Skips blocks larger than this
- `MAX_BLOCKS = 500` - Stops processing after this many blocks
- No auto-detection - only highlights blocks with recognized language class

**Flow:**
1. On DOMContentLoaded, check if `window.hljs` exists
2. Query all `pre > code` elements
3. For each block: extract language class, normalize via LANG_MAP, skip if too large
4. Call `hljs.highlightElement()` for each valid block
5. Set `highlighted` flag to prevent re-execution on theme toggle

### 6. Installation: install.ps1

**Purpose:** Per-user installation without admin privileges.

**Location:** `install.ps1`

**Actions:**
1. Ensures PowerShell 7 (pwsh) is available
2. Copies payload files to `%LOCALAPPDATA%\Programs\MarkdownViewer`
3. Registers ProgId in `HKCU:\Software\Classes`
4. Registers for Default Apps via Capabilities
5. Optionally adds context menu entries
6. Registers `mdview:` protocol handler
7. Creates uninstall entry in Add/Remove Programs
8. Calls `SHChangeNotify` to refresh shell associations

## Security Architecture

### Content Security Policy (CSP)

Generated per-document with cryptographic nonce:

```
default-src 'none';
connect-src 'none';
object-src 'none';
frame-src 'none';
form-action 'none';
base-uri file:;
img-src file: data: [https: if remote enabled];
style-src 'nonce-<random>' file:;
script-src 'nonce-<random>' file:
```

**Note:** The `file:` directive is required for loading external highlight.js assets (`highlight.min.js` and `highlight-theme.css`) from the installation directory. Inline scripts and styles still require the cryptographic nonce.

### HTML Sanitization (Defense-in-Depth)

Applied before output, removes:
1. Dangerous tags: `<script>`, `<iframe>`, `<object>`, `<embed>`, `<meta>`, `<base>`, `<link>`, `<style>`
2. Event handlers: `on*` attributes (only in HTML tags, not code blocks)
3. JavaScript URIs: `javascript:` in href/src
4. Data URIs: `data:` in href (but allowed in img src)

### Mark-of-the-Web (MOTW)

Files downloaded from Internet (Zone 3+) trigger a warning dialog:
- **Open** - View once (warns again next time)
- **Unblock & Open** - Remove zone identifier permanently
- **Cancel** - Abort

## Data Flow

```
Input: C:\docs\README.md
         │
         ▼
    ┌─────────────┐
    │ Parse Path  │ ─── Handle mdview:, file:, #fragments
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ MOTW Check  │ ─── Zone.Identifier ADS
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Convert MD  │ ─── ConvertFrom-Markdown
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Sanitize    │ ─── Remove dangerous content
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Assemble    │ ─── Inject CSS, JS, CSP, favicon
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Write HTML  │ ─── %TEMP%\viewmd_README_A1B2C3D4.html
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Launch      │ ─── Start-Process (default browser)
    └─────────────┘
```

## File Structure

```
MarkdownViewer/
├── README.md                # User documentation
├── LICENSE                  # MIT License
├── THIRD-PARTY-LICENSES.md  # Third-party license attributions (highlight.js)
├── PSScriptAnalyzerSettings.psd1  # Linter config
│
├── src/
│   ├── core/                        # Cross-platform engine + assets
│   │   ├── Open-Markdown.ps1        # Main PowerShell script
│   │   ├── script.js                # Client-side JavaScript
│   │   ├── style.css                # Client-side CSS
│   │   ├── highlight.min.js         # highlight.js MD bundle (all languages)
│   │   ├── highlight-theme.css      # Combined Tomorrow/Tomorrow Night theme
│   │   └── icons/
│   │       ├── markdown-mark-solid-win10-light.ico  # App icon
│   │       └── markdown-mark-solid-win10-filled.ico # dark-filled icon, unused
│   │
│   └── win/                         # Windows-specific
│       ├── MarkdownViewer.psm1      # Shared module
│       ├── viewmd.vbs               # Ad-hoc launcher
│       └── uninstall.vbs            # Silent uninstall helper

├── installers/
│   └── win-adhoc/                   # Per-user ad-hoc installer
│       ├── INSTALL.cmd
│       ├── UNINSTALL.cmd
│       ├── install.ps1
│       └── uninstall.ps1
│
├── tests/                   # Pester unit tests
│   └── MarkdownViewer.Tests.ps1
│
└── dev/
    ├── scripts/             # Build/dev scripts
    │   ├── highlight.min.js     # Source highlight.js bundle
    │   └── highlight-theme.css  # Source theme CSS
    └── docs/                # Development documentation
        ├── markdown-viewer-architecture.md (this file)
        ├── markdown-viewer-implementation-plan.md
        ├── msix-activation-matrix.md
        ├── msix-packaging-and-host-launcher-specification.md
		
        └── sanitization-bug-fix-plan.md
```

## Testing

Unit tests use Pester 5.x and are located in `tests/MarkdownViewer.Tests.ps1`.

**Test Coverage:**
- HTML sanitization (dangerous tags, event handlers, URIs)
- Remote image detection
- File path to URL conversion
- MOTW detection
- Syntax highlighting (asset files, LANG_MAP, CSP, HTML template, installer)
- Theme variations

**Running Tests:**
```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester "tests\MarkdownViewer.Tests.ps1" -Output Minimal
```

## Configuration

The application uses localStorage in the browser for user preferences:

| Key | Values | Description |
|-----|--------|-------------|
| `mdviewer_theme_mode` | `"system"`, `"invert"` | Theme follows OS or inverts it |
| `mdviewer_remote_images_<hash>` | `"0"`, `"1"` | Per-document remote image setting |
| `mdviewer_remote_images_ack_<hash>` | `"1"` | User acknowledged remote images prompt |

## Dependencies

- **PowerShell 7 (pwsh):** Required for `ConvertFrom-Markdown` cmdlet
- **Windows Script Host:** Built into Windows, runs VBScript
- **Default Web Browser:** Chrome, Edge, Firefox, etc.
- **highlight.js:** Bundled (~1MB UMD build) for syntax highlighting
