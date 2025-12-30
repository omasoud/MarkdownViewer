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
│  - Injects CSS, JS, CSP, favicon into HTML document                         │
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
└───────────────────────────────┘  │  │   - Base href for relative links    │   │
                                   │  │   - Favicon (base64-encoded)        │   │
                                   │  └─────────────────────────────────────┘   │
                                   │  ┌─────────────────────────────────────┐   │
                                   │  │ <body>                              │   │
                                   │  │   - Theme toggle button             │   │
                                   │  │   - Images toggle button (if needed)│   │
                                   │  │   - Inline JS (script.js)           │   │
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

**Location:** `payload/Open-Markdown.ps1`

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

**Location:** `payload/MarkdownViewer.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|---------|
| `Invoke-HtmlSanitization` | Removes dangerous HTML elements and event handlers |
| `Test-RemoteImages` | Detects `https://`, `http://`, `//` in `<img>` tags |
| `Get-FileBaseHref` | Converts file path to `file://` URL |
| `Test-Motw` | Reads Zone.Identifier alternate data stream |

### 4. Client-Side: style.css

**Purpose:** Provides visual styling for rendered Markdown.

**Location:** `payload/style.css`

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

**Location:** `payload/script.js`

**IIFE Modules:**

| Module | Purpose |
|--------|---------|
| Theme Toggle | Switches between System/Invert mode, persists to localStorage |
| Remote Images | Manages opt-in for remote image loading, page switching |
| Anchor Rewrite | Fixes in-page `#anchor` links for file:// context |
| Markdown Links | Rewrites local `.md` links to use `mdview:` protocol |

**localStorage Keys:**
- `mdviewer_theme_mode` - "system" or "invert"
- `mdviewer_remote_images_<docId>` - "0" or "1"
- `mdviewer_remote_images_ack_<docId>` - "1" (user acknowledged prompt)

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
style-src 'nonce-<random>';
script-src 'nonce-<random>'
```

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
├── INSTALL.cmd              # Batch wrapper for install.ps1
├── install.ps1              # Per-user installer
├── UNINSTALL.cmd            # Batch wrapper for uninstall.ps1
├── uninstall.ps1            # Per-user uninstaller
├── uninstall.vbs            # Silent uninstall launcher
├── README.md                # User documentation
├── LICENSE                  # MIT License
├── PSScriptAnalyzerSettings.psd1  # Linter config
│
├── payload/                 # Files copied during installation
│   ├── viewmd.vbs           # Entry point (VBScript)
│   ├── Open-Markdown.ps1    # Main PowerShell script
│   ├── MarkdownViewer.psm1  # Shared module (testable functions)
│   ├── script.js            # Client-side JavaScript
│   ├── style.css            # Client-side CSS
│   └── markdown-mark-solid-win10-light.ico  # App icon
│
├── tests/                   # Pester unit tests
│   └── MarkdownViewer.Tests.ps1
│
└── dev/
    └── docs/                # Development documentation
        ├── markdown-viewer-architecture.md (this file)
        └── sanitization-bug-fix-plan.md
```

## Testing

Unit tests use Pester 5.x and are located in `tests/MarkdownViewer.Tests.ps1`.

**Test Coverage:**
- HTML sanitization (dangerous tags, event handlers, URIs)
- Remote image detection
- File path to URL conversion
- MOTW detection

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
