# Markdown Viewer Architecture

## Overview

Markdown Viewer is a cross-platform application (Windows, Linux, and macOS) that renders Markdown files as styled HTML in the user's default web browser. It is designed as a lightweight tool supporting multiple installation methods: per-user ad-hoc installation and MSIX packaging on Windows, snap packaging on Linux, and DMG packaging on macOS.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            User Interaction                                  │
│  (Double-click .md file, Context menu, Finder/Open With, or mdview: link)   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
          ┌──────────────┬──────────────┼──────────────┬──────────────┐
          │              │              │              │              │
          ▼              ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ viewmd.vbs   │ │ Win Host EXE │ │ markview     │ │ MarkViewHost │ │ markview     │
│ Windows      │ │ Windows MSIX │ │ Linux        │ │ macOS app    │ │ macOS source │
│ ad-hoc       │ │              │ │ snap/source  │ │ bundle       │ │ launcher     │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                │                │                │                │
       └────────────────┴────────────────┼────────────────┴────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Open-Markdown.ps1 (Core Engine)                       │
│  - Parses input path (file:, mdview: protocols, fragments)                  │
│  - Platform trust-marker check + user prompts                               │
│  - Converts Markdown → HTML via ConvertFrom-Markdown                        │
│  - Sanitizes HTML (removes dangerous elements/attributes)                   │
│  - Injects CSS, JS, CSP, highlight.js, optional KaTeX, and favicon           │
│  - Writes generated HTML to the platform output directory                   │
│  - Launches default browser                                                 │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                              ▼
┌───────────────────────────────┐  ┌───────────────────────────────────────────┐
│  Platform MarkdownViewer.psm1 │  │           Generated HTML Document          │
│  - Invoke-HtmlSanitization    │  │  ┌─────────────────────────────────────┐   │
│  - Test-RemoteImages          │  │  │ <head>                              │   │
│  - Get-FileBaseHref           │  │  │   - CSP meta tag (nonce-based)      │   │
│  - Test-Motw                  │  │  │   - Inline CSS (style.css)          │   │
└───────────────────────────────┘  │  │   - highlight-theme.css (file:)     │   │
                                   │  │   - KaTeX CSS when math is present  │   │
                                   │  │   - Base href and favicon           │   │
                                   │  └─────────────────────────────────────┘   │
                                   │  ┌─────────────────────────────────────┐   │
                                   │  │ <body>                              │   │
                                   │  │   - Theme toggle button             │   │
                                   │  │   - Images toggle button (if needed)│   │
                                   │  │   - highlight.min.js (file: defer)  │   │
                                   │  │   - katex.min.js (conditional)      │   │
                                   │  │   - Inline JS (script.js)           │   │
                                   │  │   - Sanitized HTML content          │   │
                                   │  └─────────────────────────────────────┘   │
                                   └───────────────────────────────────────────┘
```

## Component Details

### 1. Entry Points

#### Windows Ad-hoc: viewmd.vbs

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

#### Windows MSIX: MarkdownViewerHost.exe

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

#### Linux: markview (Bash Launcher)

**Purpose:** Shell entry point for Linux that locates pwsh and launches the engine.

**Location:** `src/linux/markview`

**Flow:**
1. Resolves its own install directory (`MARKVIEW_ROOT`)
2. Locates `pwsh` — bundled (snap) or system (`/usr/local/bin/pwsh`, `/opt/microsoft/powershell/7/pwsh`)
3. Invokes `Open-Markdown.ps1` with the input path
4. Handles both file paths and `mdview:` URIs

**Snap vs Source:**
- **Snap:** `pwsh` is bundled at `$SNAP/pwsh/pwsh`; `snapctl user-open` launches the browser
- **Source:** System `pwsh`; `xdg-open` launches the browser

#### macOS: MarkViewHost + markview

**Purpose:** Native app host for Finder file activation and `mdview:` URL activation, plus a shell launcher for source development.

**Locations:** `src/host/MarkdownViewerMacHost/`, `src/mac/markview`

**Responsibilities:**
- Receives Finder file-open events for `.md` and `.markdown`
- Receives `mdview:` URL-open events through Launch Services
- Resolves bundled `pwsh` and `Open-Markdown.ps1` inside `MarkView.app`
- Uses structured `Process` arguments
- Exits after handing off to PowerShell

**DMG vs Source:**
- **DMG:** `pwsh` is bundled at `MarkView.app/Contents/Resources/pwsh/pwsh`
- **Source:** `src/mac/markview` uses system `pwsh`

### 2. Core Engine: Open-Markdown.ps1

**Purpose:** Main orchestration script that handles the full conversion pipeline.

**Location:** `src/core/Open-Markdown.ps1`

**Key Responsibilities:**

| Function | Description |
|----------|-------------|
| Path Resolution | Handles `file:`, `mdview:` protocols and `_fragment` query-param parsing |
| Security Check | Detects platform trust markers and prompts user |
| Markdown Conversion | Uses `ConvertFrom-Markdown` cmdlet |
| HTML Sanitization | Calls module function to remove dangerous content |
| Document Assembly | Injects CSS, JS, CSP headers, favicon |
| Output | Writes temp HTML and launches browser |

**Generated Files:**
- Windows: `%TEMP%\viewmd_<name>_<hash>.html` — Local-only images version
- Windows: `%TEMP%\viewmd_<name>_<hash>_remote.html` — Remote images enabled (if needed)
- Linux: `~/MarkView/viewmd_<name>_<hash>.html` — Local-only images version
- Linux: `~/MarkView/viewmd_<name>_<hash>_remote.html` — Remote images enabled (if needed)
- macOS: `~/Library/Caches/MarkView/viewmd_<name>_<hash>.html` — Local-only images version
- macOS: `~/Library/Caches/MarkView/viewmd_<name>_<hash>_remote.html` — Remote images enabled (if needed)

### 3. Platform Modules

The module system uses a three-layer architecture:

#### Shared Module: MarkdownViewer.Shared.psm1

**Purpose:** Cross-platform functions used by Windows, Linux, and macOS.

**Location:** `src/core/MarkdownViewer.Shared.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|--------|
| `Invoke-HtmlSanitization` | Removes dangerous HTML elements and event handlers |
| `Test-RemoteImages` | Detects `https://`, `http://`, `//` in `<img>` tags |
| `Repair-MarkdownLinks` | Repairs local Markdown file link forms before conversion |
| `Repair-HtmlLinks` | Repairs local link encoding after conversion |

#### Windows Module: MarkdownViewer.psm1

**Purpose:** Windows-specific functions.

**Location:** `src/win/MarkdownViewer.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|--------|
| `Get-FileBaseHref` | Converts Windows file path to `file://` URL |
| `Test-Motw` | Reads Zone.Identifier alternate data stream |
| `Clear-FileTrustMarker` | Removes Mark-of-the-Web with `Unblock-File` |
| `Get-MarkViewOutputDirectory` | Returns `%TEMP%` |
| `Start-DefaultBrowser` | Launches default browser executable directly |

#### Linux Module: MarkdownViewer.psm1

**Purpose:** Linux-specific functions.

**Location:** `src/linux/MarkdownViewer.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|--------|
| `Get-FileBaseHref` | Converts Linux file path to `file://` URL |
| `Test-Motw` | Returns `$null` |
| `Clear-FileTrustMarker` | No-op |
| `Get-MarkViewOutputDirectory` | Returns `~/MarkView` |
| `Start-DefaultBrowser` | Launches browser via `xdg-open` or `snapctl user-open` |

#### macOS Module: MarkdownViewer.psm1

**Purpose:** macOS-specific functions.

**Location:** `src/mac/MarkdownViewer.psm1`

**Exported Functions:**

| Function | Purpose |
|----------|--------|
| `Get-FileBaseHref` | Converts macOS file path to `file://` URL |
| `Test-Motw` | Detects `com.apple.quarantine` extended attribute |
| `Clear-FileTrustMarker` | Removes `com.apple.quarantine` with `xattr` |
| `Get-MarkViewOutputDirectory` | Returns `~/Library/Caches/MarkView` |
| `Start-DefaultBrowser` | Launches browser via `/usr/bin/open` |
| `Initialize-PlatformUI`, `Show-*` | Uses AppleScript dialogs through `osascript` |

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
| Math Typesetting | Applies KaTeX only to converter-emitted `span.math` and `div.math` nodes |

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

### 7. Math Typesetting: vendored KaTeX

**Purpose:** Renders converter-recognized inline and display TeX without network access.

**Location:** `src/core/vendor/katex/`, with integration in `Open-Markdown.ps1`,
`MarkdownViewer.Shared.psm1`, `script.js`, and `style.css`.

**Architecture:**
- KaTeX 0.18.3 is vendored with its browser runtime, stylesheet, and every font referenced by that stylesheet.
- The PowerShell engine checks sanitized converter output for `span.math` or `div.math`. Documents without those nodes do not receive KaTeX links or copy the bundle.
- A deterministic content hash identifies an immutable `katex.<hash>` directory beside generated HTML. Publishing uses a temporary directory and atomic rename, so concurrent renders reuse one complete bundle.
- The stylesheet loads in `<head>`. The deferred KaTeX script loads after highlight.js and before the nonce-protected viewer script.
- The browser integration reads only `textContent` from converter-created nodes, accepts the converter's `\(...\)` and `\[...\]` wrappers, and does not use KaTeX auto-render.
- KaTeX runs with `trust: false`, `strict: 'warn'`, bounded expansion/size settings, and accessible HTML plus MathML output.
- Missing assets, malformed expressions, and resource-limit skips preserve readable source and do not stop other viewer features.

### 8. Ad-hoc Mode Installation: install.ps1 (Windows)

**Purpose:** Per-user installation without admin privileges.

**Location:** `installers/win-adhoc/install.ps1`

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
│   ├── MarkdownViewer.Shared.psm1
│   ├── MarkdownViewer.psm1
│   ├── script.js
│   ├── style.css
│   ├── highlight.min.js
│   ├── highlight-theme.css
│   ├── vendor/katex/             # KaTeX JS, CSS, fonts, and license
│   ├── THIRD-PARTY-LICENSES.md
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

## Snap Packaging (Linux)

### Package Structure

```
<Snap>/
├── markview                   # Bash launcher (entry point)
├── markview.desktop           # Freedesktop desktop entry
├── markview.png               # Application icon
├── app/                       # Engine payload
│   ├── Open-Markdown.ps1
│   ├── MarkdownViewer.Shared.psm1
│   ├── MarkdownViewer.psm1   # Linux platform module
│   ├── script.js
│   ├── style.css
│   ├── highlight.min.js
│   ├── highlight-theme.css
│   └── icons/
├── pwsh/                      # Bundled PowerShell 7 (trimmed)
│   ├── pwsh
│   └── ...
└── meta/                      # Snap metadata
    └── snap.yaml
```

### Activation Flow (Snap)

1. User double-clicks `.md` file, runs `markdownviewer file.md`, or clicks `mdview:` link
2. Desktop environment invokes `markdownviewer` launcher via desktop entry
3. Launcher resolves bundled `pwsh` at `$SNAP/pwsh/pwsh`
4. Launches: `pwsh -NoProfile -File $SNAP/app/Open-Markdown.ps1 -Path <input>`
5. Engine renders HTML to `~/MarkView/` (within `$SNAP_USER_DATA`)
6. Browser launched via `snapctl user-open` (respects snap strict confinement)

### Confinement

The snap uses **strict confinement** with these interfaces:
- `home` — read access to user's home directory for markdown files
- `desktop` — access to desktop environment for browser launch
- `network` — not connected (no network access)

**Portal stripping:** On Linux, `xdg-open` and `snapctl user-open` pass URIs through the XDG Desktop Portal, which strips `#fragment` from URIs. The `_fragment` query parameter contract was designed specifically to work around this limitation.

## DMG Packaging (macOS)

### App Bundle Structure

```
MarkView.app/
└── Contents/
    ├── Info.plist                  # Bundle metadata, document types, URL scheme
    ├── MacOS/
    │   └── MarkViewHost            # Swift/AppKit host executable
    └── Resources/
        ├── app/                    # Engine payload
        │   ├── Open-Markdown.ps1
        │   ├── MarkdownViewer.Shared.psm1
        │   ├── MarkdownViewer.psm1 # macOS platform module
        │   ├── script.js
        │   ├── style.css
        │   ├── highlight.min.js
        │   ├── highlight-theme.css
        │   └── markdown.ico
        ├── pwsh/                   # Bundled PowerShell 7 arm64 runtime
        │   ├── pwsh
        │   └── ...
        └── markview.icns           # Application icon
```

### Activation Flow (DMG)

1. User opens a `.md` or `.markdown` file with `MarkView.app`, or clicks an `mdview:` link
2. macOS Launch Services activates `MarkViewHost`
3. Host resolves bundled `pwsh` at `Contents/Resources/pwsh/pwsh`
4. Host launches: `pwsh -NoProfile -File Contents/Resources/app/Open-Markdown.ps1 -Path <input>`
5. Engine renders HTML to `~/Library/Caches/MarkView/`
6. Browser is launched via `/usr/bin/open`

### Distribution

The first macOS package target is **Apple Silicon arm64 only**. Local developer builds are ad-hoc signed so they can be exercised on the build machine. Public DMG releases should be signed with a Developer ID Application certificate, notarized with Apple, and stapled before publishing.

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
script-src 'nonce-<random>' file:;
font-src file:
```

**Note:** The `file:` directives load bundled highlight.js and KaTeX assets. `font-src file:` is limited to local KaTeX fonts. Inline scripts and styles still require the cryptographic nonce, and KaTeX is configured with `trust: false`.

### HTML Sanitization (Defense-in-Depth)

Applied before output, removes:
1. Dangerous tags: `<script>`, `<iframe>`, `<object>`, `<embed>`, `<meta>`, `<base>`, `<link>`, `<style>`
2. Event handlers: `on*` attributes (only in HTML tags, not code blocks)
3. JavaScript URIs: `javascript:` in href/src
4. Data URIs: `data:` in href (but allowed in img src)

### Platform Trust Markers

Files downloaded from the internet can carry platform-specific trust markers. MarkView treats those as an early warning before rendering:
- **Windows:** Zone.Identifier alternate data stream (Mark-of-the-Web, Zone 3+)
- **macOS:** `com.apple.quarantine` extended attribute
- **Linux:** No equivalent marker is checked

When a marker is present, the platform dialog offers:
- **Open** - View once (warns again next time)
- **Unblock & Open** - Remove the marker permanently, then open
- **Cancel** - Abort

## Data Flow

```
Input: C:\docs\README.md  (or /home/user/docs/README.md, /Users/user/docs/README.md)
       or mdview:file:///C:/docs/README.md?_fragment=intro
         │
         ▼
    ┌─────────────┐
    │ Parse Path  │ ─── Strip mdview:, extract _fragment from query, resolve file:
    └─────────────┘
         │
         ▼
    ┌─────────────┐
    │ Trust Check │ ─── Zone.Identifier ADS (Windows), quarantine xattr (macOS)
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
    │ Write HTML  │ ─── %TEMP%, ~/MarkView, or ~/Library/Caches/MarkView
    └─────────────┘
         │
         ▼
    ┌───────────────┐
    │ Launch        │ ─── file:///…/viewmd_README_A1B2C3D4.html?_fragment=intro
    │               │     (Start-DefaultBrowser: xdg-open/snapctl on Linux,
    │               │      /usr/bin/open on macOS, Start-Process/COM on Windows)
    └───────────────┘
         │
         ▼
    ┌───────────────┐
    │ Browser/JS    │ ─── script.js reads embedded scroll target or ?_fragment=,
    │               │     cleans URL via history.replaceState
    └───────────────┘
```

## File Structure

```
MarkdownViewer/
├── README.md                # User documentation
├── LICENSE                  # MIT License
├── THIRD-PARTY-LICENSES.md  # Third-party license attributions
├── PSScriptAnalyzerSettings.psd1  # Linter config
│
├── src/
│   ├── core/                        # Cross-platform engine + assets
│   │   ├── Open-Markdown.ps1        # Main PowerShell engine
│   │   ├── MarkdownViewer.Shared.psm1 # Shared cross-platform module
│   │   ├── script.js                # Client-side JavaScript
│   │   ├── style.css                # Client-side CSS
│   │   ├── highlight.min.js         # highlight.js bundle
│   │   ├── highlight-theme.css      # highlight.js theme
│   │   ├── vendor/katex/            # Offline KaTeX runtime and fonts
│   │   └── icons/
│   │       ├── markdown.ico
│   │       └── markdown-light.ico
│   │
│   ├── win/                         # Windows platform
│   │   ├── MarkdownViewer.psm1      # Windows-specific module
│   │   ├── viewmd.vbs               # Ad-hoc launcher
│   │   └── uninstall.vbs            # Silent uninstall helper
│   │
│   ├── linux/                       # Linux platform
│   │   ├── MarkdownViewer.psm1      # Linux-specific module
│   │   ├── markview                 # Bash launcher script
│   │   ├── markview.desktop         # Freedesktop desktop entry
│   │   └── markview.png             # Application icon (256x256)
│   │
│   ├── mac/                         # macOS platform
│   │   ├── MarkdownViewer.psm1      # macOS-specific module
│   │   └── markview                 # Bash launcher script
│   │
│   └── host/                        # Native host applications
│       ├── MarkdownViewerHost/      # Windows MSIX host
│       │   ├── MarkdownViewerHost.csproj
│       │   └── Program.cs
│       └── MarkdownViewerMacHost/   # macOS AppKit host
│           ├── Info.plist.template
│           └── MarkViewHost.swift
│
├── installers/
│   ├── win-adhoc/                   # Per-user ad-hoc installer (Windows)
│   │   ├── INSTALL.cmd
│   │   ├── UNINSTALL.cmd
│   │   ├── install.ps1
│   │   └── uninstall.ps1
│   │
│   ├── win-msix/                    # MSIX packaging (Windows)
│   │   ├── MarkdownViewer.wapproj
│   │   ├── Package.appxmanifest
│   │   ├── sign.ps1
│   │   └── build/
│   │       ├── stage.ps1
│   │       ├── pwsh-versions.json
│   │       └── Directory.Build.targets
│   │
│   ├── linux-snap/                  # Snap packaging (Linux)
│   │   ├── snap/snapcraft.yaml
│   │   ├── build.sh                 # Stage + trim + build snap
│   │   └── scripts/                 # Trimming & verification
│   │
│   └── macos-dmg/                   # DMG packaging (macOS)
│       ├── build.sh                 # Stage + trim + build DMG
│       ├── build/pwsh-versions.json # Pinned macOS PowerShell runtime
│       └── scripts/                 # Icon, signing, trimming, verification
│
├── tests/
│   ├── MarkdownViewer.Tests.ps1     # Core Pester tests
│   ├── MarkdownViewerHost.Tests/    # xUnit tests
│   ├── local-file-normalization/    # Manual link test sources (Windows)
│   ├── local-file-normalization-linux/ # Manual link test sources (Linux)
│   ├── local-file-normalization-macos/ # Manual link test sources (macOS)
│   ├── pwsh/                        # Additional Pester tests
│   │   ├── BrowserLaunch.Tests.ps1
│   │   ├── Build.Tests.ps1
│   │   ├── MacModule.Tests.ps1
│   │   ├── MacBundle.Tests.ps1
│   │   ├── Stage.Tests.ps1
│   │   ├── LocalFileNormalization.Tests.ps1
│   │   └── ...
│   ├── highlight-test.md
│   ├── math-test.md
│   └── theme-variation-test.md
│
└── dev/
    ├── scripts/             # Build/dev scripts
    └── docs/                # Development documentation
        ├── markdown-viewer-architecture.md (this file)
        ├── markdown-viewer-implementation-plan.md
        ├── msix-activation-matrix.md
        └── msix-packaging-and-host-launcher-specification.md
```

## Testing

### PowerShell Tests (Pester 5.x)

Located in `tests/MarkdownViewer.Tests.ps1` and `tests/pwsh/*.Tests.ps1`.

**Test Coverage:**
- HTML sanitization (dangerous tags, event handlers, URIs)
- Remote image detection
- File path to URL conversion
- Platform trust-marker detection (Windows MOTW, macOS quarantine)
- Syntax highlighting (asset files, LANG_MAP, CSP, HTML template, installer)
- Math typesetting (converter contract, immutable bundle publication, CSP, browser guardrails, packaging)
- Theme variations
- `_fragment` contract (parsing, encoding, browser launch)
- Local-file link normalization
- Snap build and staging (Linux)
- DMG app bundle staging and verification (macOS)

**Running Tests:**
```powershell
# Windows
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester "tests" -Output Minimal

# Linux
pwsh -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester tests -Output Minimal"

# macOS
pwsh -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester tests -Output Minimal"
```

### C# Tests (xUnit)

Located in `tests/MarkdownViewerHost.Tests/` (Windows only — requires .NET SDK).

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
Browser/Portal/Launch Services invokes protocol handler
  (?_fragment carries the target to the engine)
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
  2. window.mdviewer_config.scrollTarget = "section-1" (primary)
     URLSearchParams fallback reads _fragment if preserved
  3. document.getElementById("section-1").scrollIntoView()
  4. history.replaceState() — clean address bar
```

## Dependencies

- **PowerShell 7 (pwsh):**
  - Windows ad-hoc: System installation (auto-prompted)
  - Windows MSIX: Bundled in package
  - Linux snap: Bundled in snap
  - Linux source: System installation
  - macOS DMG: Bundled in app
  - macOS source: System installation
- **Windows Script Host:** Built into Windows (ad-hoc only)
- **Xcode Command Line Tools:** Required to build macOS app bundles (`swiftc`, `codesign`, `hdiutil`, `sips`, `iconutil`, `plutil`)
- **Default Web Browser:** Chrome, Edge, Firefox, etc.
- **highlight.js:** Bundled (~1MB UMD build) for syntax highlighting
- **xdg-open:** Linux desktop standard for launching default browser (Linux source only; snap uses `snapctl user-open`)
- **/usr/bin/open:** macOS Launch Services bridge for opening the default browser
- **osascript:** macOS dialog fallback for warnings and errors
- **zenity:** Optional dialog toolkit for Linux warnings (falls back to terminal output)
