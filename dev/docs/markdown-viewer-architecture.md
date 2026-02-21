# Markdown Viewer Architecture

## Overview

Markdown Viewer is a Windows application that renders Markdown files as styled HTML in the user's default web browser. It is designed as a lightweight tool supporting both per-user ad-hoc installation and MSIX packaging for Microsoft Store distribution.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            User Interaction                                  │
│  (Double-click .md file, Context menu, or mdview: protocol link)            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
                    ▼                                      ▼
┌─────────────────────────────────┐    ┌─────────────────────────────────────┐
│     Ad-hoc: viewmd.vbs          │    │     MSIX: MarkdownViewerHost.exe    │
│  - Windows Script Host wrapper  │    │  - .NET Framework 4.8.1 GUI app     │
│  - Launches pwsh silently       │    │  - Receives file/protocol activation│
│  - Uses system pwsh             │    │  - Launches bundled pwsh            │
└─────────────────┬───────────────┘    └─────────────────┬───────────────────┘
                  │                                      │
                  └──────────────────┬───────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Open-Markdown.ps1 (Core Engine)                       │
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

### 1. Entry Points

#### Ad-hoc: viewmd.vbs

**Purpose:** Silent launcher that avoids console window flashes.

**Location:** `src/win/viewmd.vbs`

**Flow:**
1. Receives markdown file path as command-line argument
2. Constructs pwsh command with `Open-Markdown.ps1`
3. Executes via `WScript.Shell.Run` with hidden window

```vb
cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File ""...\Open-Markdown.ps1"" -Path ""..."""
CreateObject("WScript.Shell").Run cmd, 0, False
```

#### MSIX: MarkdownViewerHost.exe

**Purpose:** .NET Framework 4.8.1 host application for MSIX activation handling.

**Location:** `src/host/MarkdownViewerHost/`

**Responsibilities:**
- Receives file and protocol activation from Windows via AppInstance APIs
- Passes activation arguments to bundled pwsh
- Uses structured argument passing (no string concatenation)
- Hides console window (WinExe subsystem)
- Exits immediately after launching pwsh (stateless)

**Key Properties:**
- OutputType: WinExe (no console flash)
- Target: net481 (Full Trust desktop bridge, not packaged UWP)
- Uses Windows.ApplicationModel.AppInstance for packaged activation
- Uses System.Windows.Forms for help dialog

### 2. Core Engine: Open-Markdown.ps1

**Purpose:** Main orchestration script that handles the full conversion pipeline.

**Location:** `src/core/Open-Markdown.ps1`

**Key Responsibilities:**

| Function | Description |
|----------|-------------|
| Path Resolution | Handles `file:`, `mdview:` protocols and `_fragment` query-param parsing |
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
| Markdown Links | Rewrites local `.md` links to `mdview:` protocol with `_fragment` query param |
| Fragment Scroll | Reads `?_fragment=` from HTML URL on load, scrolls to target element |
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

### 7. Ad-hoc Mode Installation: install.ps1

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
## MSIX Packaging

### Package Structure

```
<MSIX Package>/
├── MarkdownViewerHost.exe     # Host EXE (entry point)
├── MarkdownViewerHost.dll     # Host assembly
├── *.runtimeconfig.json       # .NET configuration
├── app/                       # Engine payload
│   ├── Open-Markdown.ps1
│   ├── MarkdownViewer.psm1
│   ├── script.js
│   ├── style.css
│   ├── highlight.min.js
│   ├── highlight-theme.css
│   └── markdown.ico
├── pwsh/                      # Bundled PowerShell 7
│   ├── pwsh.exe
│   └── ...
└── Assets/                    # MSIX visual assets
    ├── Square44x44Logo.png
    ├── Square150x150Logo.png
    └── ...
```

### Activation Flow (MSIX)

1. User double-clicks `.md` file or clicks `mdview:` link
2. Windows activates `MarkdownViewerHost.exe` with arguments
3. Host resolves bundled pwsh and engine paths
4. Host launches: `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File app/Open-Markdown.ps1 -Path <input>`
5. Host exits immediately
6. Engine processes markdown and opens browser

### Activation Kinds

The MSIX package registers for three activation kinds, each triggered by different user actions:

| Activation Kind | Trigger | Example |
|-----------------|---------|---------|
| **File** | Double-click `.md` file, right-click "Open with" | Explorer → double-click `README.md` |
| **Protocol** | Click `mdview:` link, in-app link navigation | Browser link, `Start-Process "mdview:..."` |
| **Launch** | Start menu, taskbar, no arguments | Click app icon |

**Important:** The most common real-world use of Protocol activation is **in-app link navigation**:

```
                        ┌─────────────────────────────────────────────────────┐
                        │        Rendered HTML in Browser                     │
                        │                                                     │
User clicks File        │  # Project Documentation                           │
Activation              │                                                     │
(ActivationKind.File)   │  See also:                                         │
        │               │  - [Installation Guide](./install.md)  ◄───────────┤
        ▼               │  - [API Reference](./api.md)                       │
┌───────────────────┐   │                                                     │
│ Open main.md      │   │  script.js rewrites these links to:                │
│ (File Activation) │   │    mdview:file:///C:/docs/install.md               │
└───────────────────┘   │    mdview:file:///C:/docs/api.md                   │
        │               └─────────────────────────────────────────────────────┘
        ▼                                         │
┌───────────────────┐                             │ User clicks link
│ Browser renders   │                             │
│ HTML with         │                             ▼
│ rewritten links   │◄────────────────────────────┤
└───────────────────┘                             │
                                                  │
                        ┌─────────────────────────┘
                        │
                        ▼
              ┌─────────────────────────┐
              │ Browser navigates to    │
              │ mdview:file:///...      │
              └───────────┬─────────────┘
                          │
                          ▼
              ┌─────────────────────────┐
              │ Windows invokes         │
              │ protocol handler        │
              │ (ActivationKind.Protocol│
              └───────────┬─────────────┘
                          │
                          ▼
              ┌─────────────────────────┐
              │ MarkdownViewerHost.exe  │
              │ receives Protocol       │
              │ activation via          │
              │ AppInstance APIs        │
              └─────────────────────────┘
```

**Link Rewriting (script.js):**

The client-side JavaScript rewrites local markdown links to use the `mdview:` protocol. Fragments are moved from `#hash` to `?_fragment=` so they survive portal/scheme-handler boundaries that strip `#`:

```javascript
// Input:  <a href="./install.md#setup">Installation</a>
// Output: <a href="mdview:file:///C:/docs/install.md?_fragment=setup">Installation</a>

var url = new URL(abs);
var fragId = "";
if (url.hash) {
    fragId = url.hash.substring(1);
    url.hash = "";
}
var final = url.href;
if (fragId) {
    final += (final.indexOf("?") === -1 ? "?" : "&") + "_fragment=" + encodeURIComponent(fragId);
}
a.setAttribute("href", "mdview:" + final);
```

This ensures that clicking a relative link to another markdown file triggers the proper activation flow rather than trying to load the raw `.md` file in the browser.

**Protocol URI Format:**

```
mdview:file:///C:/path/to/document.md
mdview:file:///C:/path/to/document.md?_fragment=section-anchor
```

The engine strips the `mdview:` prefix, extracts `_fragment` from the query string, resolves the local file, and passes `?_fragment=` through to the rendered HTML URL so `script.js` can scroll to the target element.

### Activation Flow: Ad-hoc vs MSIX

| Aspect | Ad-hoc (viewmd.vbs) | MSIX (MarkdownViewerHost.exe) |
|--------|---------------------|-------------------------------|
| File activation | Shell → VBS → pwsh | Shell → AppInstance → Host → pwsh |
| Protocol activation | Shell → VBS → pwsh | Shell → AppInstance → Host → pwsh |
| Link rewriting | Same (script.js handles mdview:) | Same (script.js handles mdview:) |
| ActivationKind API | N/A (not packaged) | File, Protocol, or Launch |

Both modes handle `mdview:` URIs identically at the engine level - the only difference is how the URI arrives:
- **Ad-hoc:** Windows invokes `viewmd.vbs "mdview:file:///..."` directly
- **MSIX:** Windows delivers `ProtocolActivatedEventArgs` via `AppInstance.GetActivatedEventArgs()`

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
Input: C:\docs\README.md  (or mdview:file:///C:/docs/README.md?_fragment=intro)
         │
         ▼
    ┌─────────────┐
    │ Parse Path  │ ─── Strip mdview:, extract _fragment from query, resolve file:
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
    ┌───────────────┐
    │ Launch        │ ─── file:///…/viewmd_README_A1B2C3D4.html?_fragment=intro
    │               │     (URL via Start-DefaultBrowser when _fragment present;
    │               │      path via Start-Process otherwise on Windows)
    └───────────────┘
         │
         ▼
    ┌───────────────┐
    │ Browser/JS    │ ─── script.js reads ?_fragment=, scrolls to element,
    │               │     cleans URL via history.replaceState
    └───────────────┘
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
│   │   ├── highlight.min.js         # highlight.js bundle
│   │   ├── highlight-theme.css      # highlight.js theme
│   │   └── icons/
│   │       ├── markdown.ico
│   │       └── markdown-light.ico
│   │
│   ├── win/                         # Windows-specific
│   │   ├── MarkdownViewer.psm1      # Shared module
│   │   ├── viewmd.vbs               # Ad-hoc launcher
│   │   └── uninstall.vbs            # Silent uninstall helper
│   │
│   └── host/                        # MSIX Host EXE
│       └── MarkdownViewerHost/
│           ├── MarkdownViewerHost.csproj
│           └── Program.cs
│
├── installers/
│   ├── win-adhoc/                   # Per-user ad-hoc installer
│   │   ├── INSTALL.cmd
│   │   ├── UNINSTALL.cmd
│   │   ├── install.ps1
│   │   └── uninstall.ps1
│   │
│   └── win-msix/                    # MSIX packaging
│       ├── Package/
│       │   ├── AppxManifest.xml
│       │   └── Assets/
│       └── build.ps1
│
├── tests/
│   ├── MarkdownViewer.Tests.ps1     # Pester tests
│   ├── MarkdownViewerHost.Tests/    # xUnit tests
│   ├── highlight-test.md
│   └── theme-variation-test.md
│
└── dev/
    ├── scripts/             # Build/dev scripts
    │   ├── highlight.min.js     # Source highlight.js bundle
    │   └── highlight-theme.css  # Source theme CSS
    └── docs/                # Development documentation
        ├── markdown-viewer-architecture.md (this file)
        ├── markdown-viewer-implementation-plan.md
        ├── msix-activation-matrix.md
        └── msix-packaging-and-host-launcher-specification.md
```

## Testing

### PowerShell Tests (Pester 5.x)

Located in `tests/MarkdownViewer.Tests.ps1`.

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

### C# Tests (xUnit)

Located in `tests/MarkdownViewerHost.Tests/`.

```powershell
dotnet test "tests\MarkdownViewerHost.Tests"
```

## Configuration

The application uses localStorage in the browser for user preferences:

| Key | Values | Description |
|-----|--------|-------------|
| `mdviewer_theme_mode` | `"system"`, `"invert"` | Theme follows OS or inverts it |
| `mdviewer_remote_images_<hash>` | `"0"`, `"1"` | Per-document remote image setting |
| `mdviewer_remote_images_ack_<hash>` | `"1"` | User acknowledged remote images prompt |

## Fragment Handling (`_fragment` Contract)

When a rendered markdown page contains links to other `.md` files with anchors (`[link](other.md#section)`), the fragment must survive the full activation round-trip. Browsers and desktop portals (especially on Linux) strip `#fragment` from URIs passed to external protocol handlers. The `_fragment` contract solves this by transporting the fragment as a query parameter.

### Contract Rules

1. **Value:** `_fragment` carries the raw element id without leading `#`.
2. **Encoding (producer):** JS uses `encodeURIComponent(id)`; PowerShell uses `[Uri]::EscapeDataString($id)`.
3. **Decoding (consumer):** PowerShell uses `[Uri]::UnescapeDataString($val)`; JS uses `URLSearchParams` (auto-decodes).
4. **Empty value:** If the decoded value is empty, ignore — no scroll.
5. **Existing query strings:** If the URL already contains `?…`, append `&_fragment=…`.
6. **`#hash` on input:** Strip it and move the value to `_fragment`. Do not preserve `#hash`.
7. **Launch rule:** When `_fragment` is present, open the HTML as a URL (`file:///…?_fragment=…`) via `Start-DefaultBrowser`, never as a filesystem path.

### End-to-End Flow

```
User clicks link in rendered HTML
        │
        ▼
script.js rewriteMarkdownLinks()
  href="docs/spec.md#section-1"
        │  strip #, encode as ?_fragment=
        ▼
  href="mdview:file:///path/docs/spec.md?_fragment=section-1"
        │
        ▼
Browser/Portal invokes protocol handler
  (?_fragment survives — only #fragment is stripped by portals)
        │
        ▼
Open-Markdown.ps1 receives:
  mdview:file:///path/docs/spec.md?_fragment=section-1
        │  regex match _fragment from query
        │  $frag = "#section-1"
        │  strip query → resolve file path
        │  render markdown → viewmd_spec_ABCD1234.html
        ▼
Start-DefaultBrowser:
  file:///…/viewmd_spec_ABCD1234.html?_fragment=section-1
        │
        ▼
Browser loads HTML, script.js runs:
  1. fixMismatchedAnchors()
  2. URLSearchParams → _fragment = "section-1"
  3. document.getElementById("section-1").scrollIntoView()
  4. history.replaceState() — clean address bar
```

## Dependencies

- **PowerShell 7 (pwsh):**
  - Ad-hoc: System installation (auto-prompted)
  - MSIX: Bundled in package
- **Windows Script Host:** Built into Windows (ad-hoc only)
- **Default Web Browser:** Chrome, Edge, Firefox, etc.
- **highlight.js:** Bundled (~1MB UMD build) for syntax highlighting
