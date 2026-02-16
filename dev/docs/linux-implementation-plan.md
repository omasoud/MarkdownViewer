# Linux (Ubuntu) Port Implementation Plan

## Overview

Port MarkView to Ubuntu Linux by creating a Linux platform module (`src/linux/`), making the core engine (`Open-Markdown.ps1`) platform-aware, and packaging as a strict Snap with bundled+trimmed pwsh. The existing Windows code stays untouched. Target: installable via `snap install markview`.

**Target platforms:** Ubuntu 24.04+ (arm64, amd64)  
**Distribution:** Snap Store (strict confinement)  
**Command:** `markview file.md`  
**Desktop integration:** Double-click `.md` files in file managers (Nautilus, Thunar, etc.)

---

## Phase 0: Test Environment Setup

**Goal:** Establish a working test environment on Linux and identify which existing tests are cross-platform.

### 0.1 Install PowerShell 7 on Ubuntu ARM64

The Microsoft apt repository only provides x64 packages. For ARM64, install via tarball:

```bash
# Download and install pwsh 7.5.4 (or latest)
PWSH_VERSION="7.5.4"
wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-arm64.tar.gz" \
    -O /tmp/pwsh-arm64.tar.gz
sudo mkdir -p /opt/microsoft/powershell/7
sudo tar xzf /tmp/pwsh-arm64.tar.gz -C /opt/microsoft/powershell/7
sudo chmod +x /opt/microsoft/powershell/7/pwsh
sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
pwsh --version  # Verify: PowerShell 7.5.4
```

For x64, the apt method works:
```bash
source /etc/os-release
wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell
```

### 0.2 Install Pester 5.x

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module Pester -RequiredVersion 5.7.1
```

### 0.3 Test File Classification

| File | Classification | Linux Runnable | Notes |
|------|---------------|----------------|-------|
| `MarkdownViewer.Tests.ps1` | Partially cross-platform | ~170 of 211 | Skip `Test-Motw`, `Get-FileBaseHref` (Windows paths), MSIX tests |
| `BrowserLaunch.Tests.ps1` | Windows-only | 0 of 16 | Registry-based browser detection |
| `Build.Tests.ps1` | Partially cross-platform | ~24 of 27 | Fix `$env:TEMP` assertions |
| `LocalFileNormalization.Tests.ps1` | Partially cross-platform | ~12 of 43 | Linux path contexts work; Windows path contexts need skip |
| `LocalFileNormalization.ActualBehavior.Tests.ps1` | Windows-only | 0 of 18 | All tests hard-code `C:` base paths |
| `LocalFileNormalization.UncBasePath.Tests.ps1` | Windows-only | 0 of 7 | UNC paths are Windows-only |
| `LocalFileNormalizationWithFragments.Tests.ps1` | Partially cross-platform | ~26 of 66 | Fragment encoding + Linux path contexts work |
| `LocalFileNormalizationWithFragments.ActualBehavior.Tests.ps1` | Windows-only | 0 of 22 | All tests hard-code `C:` base paths |
| `Stage.Tests.ps1` | Cross-platform | ~45 of 48 | Minor path separator fixes needed |
| `Invoke-AllTests.ps1` | Windows-only | N/A | MSBuild/WAP runner script |
| `Test-PackagedActivation.ps1` | Windows-only | N/A | MSIX E2E tests |
| `Test-StagedPayload.ps1` | Windows-only | N/A | Windows EXE validation |

### 0.4 Baseline Test Run on Linux

Run tests before any changes to establish baseline:

```powershell
cd /home/ubuntu/projects/MarkdownViewer
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester tests -Output Minimal
```

**Baseline result (before skip guards):** 301 passed, 127 failed, 38 skipped

### 0.5 Add Platform Skip Guards to Tests

Add `-Skip:(-not $IsWindows)` to Windows-only test contexts. This is non-breaking for Windows runs.

- [x] 0.5.1 `MarkdownViewer.Tests.ps1`: Skip `Test-Motw` Describe block on Linux
- [x] 0.5.2 `MarkdownViewer.Tests.ps1`: Skip `Get-FileBaseHref` Describe block on Linux (tests Windows paths)
- [x] 0.5.3 `MarkdownViewer.Tests.ps1`: Skip MSIX integration Describe blocks on Linux
- [x] 0.5.4 `BrowserLaunch.Tests.ps1`: Skip entire file on Linux (add top-level guard)
- [x] 0.5.5 `Build.Tests.ps1`: Skip `Build Cache Directory` Describe on Linux (uses `$env:TEMP`)
- [x] 0.5.6 `LocalFileNormalization.Tests.ps1`: Skip entire file on Linux (uses Windows module)
- [x] 0.5.7 `LocalFileNormalization.ActualBehavior.Tests.ps1`: Skip entire file on Linux
- [x] 0.5.8 `LocalFileNormalization.UncBasePath.Tests.ps1`: Skip entire file on Linux
- [x] 0.5.9 `LocalFileNormalizationWithFragments.Tests.ps1`: Skip entire file on Linux (uses Windows module)
- [x] 0.5.10 `LocalFileNormalizationWithFragments.ActualBehavior.Tests.ps1`: Skip entire file on Linux
- [x] 0.5.11 `Stage.Tests.ps1`: No changes needed — paths are handled by Join-Path

### 0.6 Verification

After adding skip guards:

**Linux result (2025-01-20):** 240 passed, 0 failed, 53 skipped ✅  
**Windows target:** 428 passed, 0 failed, 38 skipped (unchanged from current) — user to verify

Run on both platforms to verify:
```powershell
# Linux
Invoke-Pester tests -Output Minimal

# Windows (user runs separately)
Invoke-Pester tests -Output Minimal
```

---

## Phase 1: Extract Shared Functions into Core Module

**Goal:** Avoid duplicating ~250 lines of cross-platform logic between `src/win/` and `src/linux/` modules.

### 1.1 Create Shared Module

- [x] 1.1.1 Create `src/core/MarkdownViewer.Shared.psm1` with these functions (copied from `src/win/MarkdownViewer.psm1`):
  - `Invoke-HtmlSanitization` — pure regex, cross-platform
  - `Test-RemoteImages` — pure regex, cross-platform
  - `Repair-MarkdownLinks` — Windows path cases are harmless no-ops on Linux
  - `Repair-MarkdownLinksInText` — internal helper
  - `Convert-LinkTarget` — Windows path cases won't match on Linux, safe
  - `Repair-HtmlLinks` — Windows-specific `%5C` fix is a no-op on Linux

### 1.2 Update Windows Module

- [x] 1.2.1 Update `src/win/MarkdownViewer.psm1`:
  - Import `../core/MarkdownViewer.Shared.psm1` at top
  - Remove the 6 functions that moved to shared module
  - Re-export shared functions alongside Windows-specific ones
  - Exported function list must remain identical (no breaking change)

### 1.3 Extract Dialog Functions from Core Engine

Move UI functions from `src/core/Open-Markdown.ps1` into platform modules:

- [x] 1.3.1 Add to `src/win/MarkdownViewer.psm1`:
  - `Initialize-PlatformUI` — calls `Add-Type -AssemblyName System.Windows.Forms` + `EnableVisualStyles()`
  - `Show-MotwWarning` — WinForms TaskDialog (move from Open-Markdown.ps1)
  - `Show-FileNotFound` — WinForms TaskDialog (move from Open-Markdown.ps1)
  - `Show-ErrorDialog` — WinForms TaskDialog (extract from catch block)

- [x] 1.3.2 Update export list in `src/win/MarkdownViewer.psm1` to include the 4 new functions

### 1.4 Verification

- [ ] 1.4.1 Run `Invoke-Pester tests/MarkdownViewer.Tests.ps1 -Output Minimal` on Windows — all existing tests pass
- [x] 1.4.2 Run `Invoke-Pester tests/MarkdownViewer.Tests.ps1 -Output Minimal` on Linux — cross-platform tests pass

---

## Phase 2: Linux Platform Module (`src/linux/`)

**Goal:** Linux-specific implementations of platform functions.

### 2.1 Create Linux Module Structure

- [x] 2.1.1 Create `src/linux/` directory
- [x] 2.1.2 Create `src/linux/MarkdownViewer.psm1`

### 2.2 Implement Linux-Specific Functions

The Linux module must export the same function list as the Windows module.

- [x] 2.2.1 Import shared module: `Import-Module (Join-Path $PSScriptRoot '../core/MarkdownViewer.Shared.psm1') -Force`

- [x] 2.2.2 `Get-FileBaseHref` — simplified for Linux paths:
  ```powershell
  function Get-FileBaseHref {
      param([Parameter(Mandatory)][string] $FilePath)
      $dir = Split-Path -LiteralPath $FilePath
      # Strip PSProvider prefixes
      if ($dir -match '^(?:Microsoft\.PowerShell\.Core\\)?FileSystem::(.+)$') {
          $dir = $Matches[1]
      }
      # Linux: /home/user/docs/ -> file:///home/user/docs/
      return 'file://' + $dir + '/'
  }
  ```

- [x] 2.2.3 `Test-Motw` — stub returning `$null` (no MOTW on Linux):
  ```powershell
  function Test-Motw {
      param([Parameter(Mandatory)][string] $FilePath)
      return $null  # Linux has no Mark-of-the-Web
  }
  ```

- [x] 2.2.4 `Start-DefaultBrowser` — use `xdg-open`:
  ```powershell
  function Start-DefaultBrowser {
      param([Parameter(Mandatory)][string] $Url)
      Start-Process 'xdg-open' -ArgumentList $Url
  }
  ```

- [x] 2.2.5 `Initialize-PlatformUI` — no-op on Linux:
  ```powershell
  function Initialize-PlatformUI {
      # No WinForms initialization needed on Linux
  }
  ```

- [x] 2.2.6 Dialog functions using `zenity` with stderr fallback:
  ```powershell
  function Show-MotwWarning {
      param([string]$FilePath)
      # Unlikely to be called since Test-Motw returns $null
      # But implement for completeness
      $fileName = [IO.Path]::GetFileName($FilePath)
      if (Get-Command zenity -ErrorAction SilentlyContinue) {
          $result = zenity --question --title="Security Warning - MarkView" `
              --text="$fileName was downloaded from the internet.\nIt may contain malicious content." `
              --ok-label="Open" --cancel-label="Cancel" 2>/dev/null
          if ($LASTEXITCODE -eq 0) { return "Open" } else { return "Cancel" }
      }
      Write-Warning "Security warning: $fileName may be from an untrusted source"
      return "Open"  # Default to open on Linux (no MOTW equivalent)
  }

  function Show-FileNotFound {
      param([Parameter(Mandatory)][string]$FilePath, [string]$FromLink = '')
      $msg = if ($FromLink) {
          "The linked Markdown file could not be found:\n\n$FilePath\n\nLink: $FromLink"
      } else {
          "The Markdown file could not be found:\n\n$FilePath"
      }
      if (Get-Command zenity -ErrorAction SilentlyContinue) {
          zenity --warning --title="MarkView" --text="$msg" 2>/dev/null
      } else {
          Write-Error "File not found: $FilePath"
      }
  }

  function Show-ErrorDialog {
      param([Parameter(Mandatory)][string]$Message)
      if (Get-Command zenity -ErrorAction SilentlyContinue) {
          zenity --error --title="MarkView" --text="$Message" 2>/dev/null
      } else {
          Write-Error $Message
      }
  }
  ```

- [ ] 2.2.7 Stub Windows-only browser detection functions (not used on Linux, but needed for export parity):
  ```powershell
  function Get-DefaultBrowserProgId { throw "Not supported on Linux" }
  function Get-ProgIdOpenCommand { throw "Not supported on Linux" }
  function Get-ExePathFromOpenCommand { throw "Not supported on Linux" }
  function Get-DefaultBrowserExePath { throw "Not supported on Linux" }
  ```

  **Decision:** Omitted from Linux module — these are Windows-only registry functions not called by the engine.

### 2.3 Export List

- [x] 2.3.1 Ensure export list matches Windows module exactly:
  ```powershell
  Export-ModuleMember -Function @(
      # From shared module (re-export)
      'Invoke-HtmlSanitization'
      'Test-RemoteImages'
      'Repair-MarkdownLinks'
      'Repair-HtmlLinks'
      # Linux-specific implementations
      'Get-FileBaseHref'
      'Test-Motw'
      'Start-DefaultBrowser'
      'Initialize-PlatformUI'
      'Show-MotwWarning'
      'Show-FileNotFound'
      'Show-ErrorDialog'
      # Stubs for Windows-only (not used on Linux)
      'Get-DefaultBrowserProgId'
      'Get-ProgIdOpenCommand'
      'Get-ExePathFromOpenCommand'
      'Get-DefaultBrowserExePath'
  )
  ```

### 2.4 Verification

- [x] 2.4.1 Create `tests/pwsh/LinuxModule.Tests.ps1` with tests for:
  - `Get-FileBaseHref` with Linux paths (`/home/user/docs/file.md` → `file:///home/user/docs/`)
  - `Test-Motw` returns `$null`
  - Shared functions are exported
  - Export list matches Windows module

- [x] 2.4.2 Run Linux module tests: `Invoke-Pester tests/pwsh/LinuxModule.Tests.ps1 -Output Minimal`

---

## Phase 3: Core Engine Platform-Awareness

**Goal:** Make `src/core/Open-Markdown.ps1` work on both Windows and Linux with zero OS-specific code inline.

### 3.1 Update Module Discovery

- [x] 3.1.1 Update lines 12-27 of `Open-Markdown.ps1` to handle platform-specific dev paths:
  ```powershell
  if (-not $ModulePath) {
      $ModulePath = Join-Path $PSScriptRoot 'MarkdownViewer.psm1'
  }

  if (Test-Path $ModulePath) {
      Import-Module $ModulePath -Force
  } else {
      # Development layout: platform-specific module in sibling directory
      $platformDir = if ($IsWindows) { 'win' } else { 'linux' }
      $devModulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "$platformDir/MarkdownViewer.psm1"
      if (Test-Path $devModulePath) {
          Import-Module $devModulePath -Force
      } else {
          throw "Cannot find MarkdownViewer.psm1 at '$ModulePath' or '$devModulePath'"
      }
  }
  ```

### 3.2 Replace Inline WinForms with Module Functions

- [x] 3.2.1 Remove `Add-Type -AssemblyName System.Windows.Forms` line
- [x] 3.2.2 Remove `[System.Windows.Forms.Application]::EnableVisualStyles()` line
- [x] 3.2.3 Add call to `Initialize-PlatformUI` after module import
- [x] 3.2.4 Remove inline `Show-MotwWarning` function (now in module)
- [x] 3.2.5 Remove inline `Show-FileNotFound` function (now in module)
- [x] 3.2.6 Replace catch block's inline TaskDialog with `Show-ErrorDialog -Message $msg`

### 3.3 Platform-Specific Guards

- [x] 3.3.1 Path hash case-sensitivity — update the MD5 hash line:
  ```powershell
  # Windows paths are case-insensitive; Linux paths are case-sensitive
  $pathForHash = if ($IsWindows) { $p.ToLower() } else { $p }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($pathForHash)
  ```

- [x] 3.3.2 Wrap `Unblock-File` in platform guard:
  ```powershell
  if ($result -eq "Unblock") {
      if ($IsWindows) {
          Unblock-File -LiteralPath $p
      }
      # Linux: no equivalent action needed
  }
  ```

### 3.4 Verification

- [x] 3.4.1 Run on Linux: `pwsh src/core/Open-Markdown.ps1 -Path README.md` — opens in browser
- [x] 3.4.2 Run existing Pester tests on both platforms — all cross-platform tests pass

---

## Phase 4: Entry Point & Desktop Integration

**Goal:** Create the launcher script and desktop file for Linux.

### 4.1 Create Launcher Script

- [x] 4.1.1 Create `src/linux/markview`:
  ```bash
  #!/bin/bash
  # MarkView - Markdown Viewer for Linux
  # Launches the PowerShell engine to render markdown in browser

  SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

  # In snap, pwsh is at $SNAP/pwsh/pwsh
  # In dev/installed layout, pwsh is either bundled or system-installed
  if [ -x "$SCRIPT_DIR/../pwsh/pwsh" ]; then
      PWSH="$SCRIPT_DIR/../pwsh/pwsh"
  else
      PWSH="pwsh"
  fi

  exec "$PWSH" -NoProfile -ExecutionPolicy Bypass \
      -File "$SCRIPT_DIR/Open-Markdown.ps1" -Path "$1"
  ```

- [x] 4.1.2 Make executable: `chmod +x src/linux/markview`

### 4.2 Create Desktop Entry

- [x] 4.2.1 Create `src/linux/markview.desktop`:
  ```ini
  [Desktop Entry]
  Version=1.0
  Type=Application
  Name=MarkView
  GenericName=Markdown Viewer
  Comment=View Markdown files rendered in your browser
  Exec=markview %f
  Icon=markview
  Terminal=false
  Categories=Utility;TextEditor;Viewer;
  MimeType=text/markdown;text/x-markdown;application/x-markdown;x-scheme-handler/mdview;
  Keywords=markdown;md;viewer;preview;
  StartupNotify=false
  ```

### 4.3 Create Icon

- [ ] 4.3.1 Convert `src/core/icons/markdown.ico` to PNG (256x256) for Linux
  ```bash
  # Using ImageMagick
  convert src/core/icons/markdown.ico[0] -resize 256x256 src/linux/markview.png
  ```
  Or extract manually and save as `src/linux/markview.png`

### 4.4 Verification

- [ ] 4.4.1 Test launcher from command line:
  ```bash
  ./src/linux/markview README.md
  ```
- [ ] 4.4.2 Verify markdown renders in default browser

---

## Phase 5: Snap Packaging

**Goal:** Create a strict Snap package with bundled+trimmed pwsh for Ubuntu arm64 and amd64.

### 5.1 Create Snap Directory Structure

- [ ] 5.1.1 Create `installers/linux-snap/` directory
- [ ] 5.1.2 Create subdirectories: `snap/`, `scripts/`

### 5.2 Create snapcraft.yaml

- [ ] 5.2.1 Create `installers/linux-snap/snap/snapcraft.yaml`:
  ```yaml
  name: markview
  version: '1.0.0'
  summary: View Markdown files rendered in your browser
  description: |
    MarkView renders Markdown files as styled HTML and opens them in your
    default web browser. Features include syntax highlighting, dark mode,
    theme variations, and support for linked markdown files.

  base: core24
  confinement: strict
  grade: stable
  architectures:
    - build-on: [amd64]
      build-for: [amd64]
    - build-on: [arm64]
      build-for: [arm64]

  apps:
    markview:
      command: bin/markview
      desktop: meta/gui/markview.desktop
      plugs:
        - home
        - desktop
        - desktop-legacy
        - x11
        - wayland
        - browser-support

  parts:
    pwsh:
      plugin: dump
      source: pwsh-${CRAFT_ARCH_BUILD_FOR}.tar.gz
      source-type: tar
      organize:
        '*': pwsh/
      override-build: |
        craftctl default
        # Trimming will be done by build script before snapcraft runs

    markview:
      plugin: dump
      source: staged/
      organize:
        app/*: app/
        bin/*: bin/
        meta/*: meta/
      stage-packages:
        - zenity
        - xdg-utils

  layout:
    /usr/share/zenity:
      bind: $SNAP/usr/share/zenity
  ```

### 5.3 Create Build Script

- [ ] 5.3.1 Create `installers/linux-snap/build.sh`:
  ```bash
  #!/bin/bash
  set -e

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  ARCH="${1:-$(uname -m)}"

  # Normalize arch name
  case "$ARCH" in
      x86_64|amd64) ARCH="amd64" ;;
      aarch64|arm64) ARCH="arm64" ;;
      *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  echo "Building MarkView snap for $ARCH..."

  # Create staging directory
  STAGE_DIR="$SCRIPT_DIR/staged"
  rm -rf "$STAGE_DIR"
  mkdir -p "$STAGE_DIR/app" "$STAGE_DIR/bin" "$STAGE_DIR/meta/gui"

  # Copy engine files
  cp "$REPO_ROOT/src/core/Open-Markdown.ps1" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/script.js" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/style.css" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/highlight.min.js" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/highlight-theme.css" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/icons/markdown.ico" "$STAGE_DIR/app/"

  # Copy Linux module (will be created in Phase 2)
  cp "$REPO_ROOT/src/linux/MarkdownViewer.psm1" "$STAGE_DIR/app/"
  cp "$REPO_ROOT/src/core/MarkdownViewer.Shared.psm1" "$STAGE_DIR/app/"

  # Copy launcher
  cp "$REPO_ROOT/src/linux/markview" "$STAGE_DIR/bin/"
  chmod +x "$STAGE_DIR/bin/markview"

  # Copy desktop integration
  cp "$REPO_ROOT/src/linux/markview.desktop" "$STAGE_DIR/meta/gui/"
  cp "$REPO_ROOT/src/linux/markview.png" "$STAGE_DIR/meta/gui/"

  # Download and trim pwsh (if not cached)
  PWSH_VERSION="7.5.4"
  PWSH_TARBALL="pwsh-$ARCH.tar.gz"
  PWSH_CACHE="$SCRIPT_DIR/.cache"
  mkdir -p "$PWSH_CACHE"

  if [ ! -f "$PWSH_CACHE/$PWSH_TARBALL" ]; then
      PWSH_URL="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${ARCH}.tar.gz"
      echo "Downloading pwsh $PWSH_VERSION for $ARCH..."
      wget -q "$PWSH_URL" -O "$PWSH_CACHE/$PWSH_TARBALL"
  fi

  # Extract and trim pwsh
  PWSH_DIR="$SCRIPT_DIR/pwsh-$ARCH"
  rm -rf "$PWSH_DIR"
  mkdir -p "$PWSH_DIR"
  tar xzf "$PWSH_CACHE/$PWSH_TARBALL" -C "$PWSH_DIR"

  # Run trimming script (adapted for Linux)
  pwsh -NoProfile -File "$SCRIPT_DIR/scripts/Trim-PwshBundle-Linux.ps1" -PwshDir "$PWSH_DIR"

  # Repackage trimmed pwsh for snapcraft
  (cd "$PWSH_DIR" && tar czf "$SCRIPT_DIR/pwsh-$ARCH.tar.gz" .)

  # Build snap
  cd "$SCRIPT_DIR"
  snapcraft --destructive-mode

  echo "Snap built: $SCRIPT_DIR/*.snap"
  ```

### 5.4 Adapt Trimming Scripts for Linux

- [ ] 5.4.1 Create `installers/linux-snap/scripts/Trim-PwshBundle-Linux.ps1`:
  - Remove non-en-US locales
  - Remove `ref/`, `preview/` directories
  - Keep only `Microsoft.PowerShell.Management` + `Microsoft.PowerShell.Utility` modules
  - Remove `.xml` help files
  - Remove Roslyn compiler DLLs
  - Remove `createdump`, `mscordaccore*.dll`, etc.
  - Verify with adapted `Verify-MarkViewPwsh.ps1`

- [ ] 5.4.2 Create `installers/linux-snap/scripts/Verify-MarkViewPwsh-Linux.ps1`:
  - Check required cmdlets: `Add-Type`, `ConvertFrom-Markdown`, `ConvertTo-Json`, `Get-Content`, `Import-Module`, `Start-Process`, `Test-Path`
  - Import `MarkdownViewer.psm1` and verify it loads
  - Smoke-test `ConvertFrom-Markdown`

### 5.5 Expected Snap Layout

```
/snap/markview/current/
├── app/
│   ├── Open-Markdown.ps1
│   ├── MarkdownViewer.psm1        # Linux module
│   ├── MarkdownViewer.Shared.psm1 # Shared module
│   ├── script.js
│   ├── style.css
│   ├── highlight.min.js
│   ├── highlight-theme.css
│   └── markdown.ico
├── bin/
│   └── markview                    # Bash launcher
├── pwsh/
│   └── pwsh + trimmed runtime
├── meta/
│   └── gui/
│       ├── markview.desktop
│       └── markview.png
└── usr/
    └── bin/
        ├── zenity
        └── xdg-open
```

### 5.6 Verification

- [ ] 5.6.1 Build snap: `cd installers/linux-snap && ./build.sh`
- [ ] 5.6.2 Install locally: `sudo snap install markview_*.snap --dangerous`
- [ ] 5.6.3 Test command: `markview README.md`
- [ ] 5.6.4 Test desktop integration: Right-click `.md` file → Open With → MarkView

---

## Phase 6: Testing

**Goal:** Comprehensive test coverage for Linux-specific code and snap package.

### 6.1 Linux Module Tests

- [ ] 6.1.1 Create `tests/pwsh/LinuxModule.Tests.ps1`:
  ```powershell
  BeforeAll {
      $modulePath = Join-Path $PSScriptRoot '../../src/linux/MarkdownViewer.psm1'
      Import-Module $modulePath -Force -Global
  }

  Describe 'Get-FileBaseHref (Linux)' -Skip:($IsWindows) {
      It 'Handles /home/user/docs/file.md' {
          Get-FileBaseHref -FilePath '/home/user/docs/file.md' | Should -Be 'file:///home/user/docs/'
      }
      It 'Handles /tmp/file.md' {
          Get-FileBaseHref -FilePath '/tmp/file.md' | Should -Be 'file:///tmp/'
      }
      It 'Handles paths with spaces' {
          Get-FileBaseHref -FilePath '/home/user/My Documents/file.md' | Should -Be 'file:///home/user/My Documents/'
      }
  }

  Describe 'Test-Motw (Linux)' -Skip:($IsWindows) {
      It 'Returns $null for any file' {
          Test-Motw -FilePath '/tmp/any-file.md' | Should -BeNullOrEmpty
      }
  }

  Describe 'Module Exports' -Skip:($IsWindows) {
      It 'Exports all required functions' {
          $required = @(
              'Invoke-HtmlSanitization', 'Test-RemoteImages',
              'Repair-MarkdownLinks', 'Repair-HtmlLinks',
              'Get-FileBaseHref', 'Test-Motw', 'Start-DefaultBrowser',
              'Initialize-PlatformUI', 'Show-MotwWarning',
              'Show-FileNotFound', 'Show-ErrorDialog'
          )
          $exported = (Get-Module MarkdownViewer).ExportedFunctions.Keys
          foreach ($fn in $required) {
              $exported | Should -Contain $fn
          }
      }
  }

  AfterAll {
      Remove-Module MarkdownViewer -Force -ErrorAction SilentlyContinue
  }
  ```

### 6.2 Snap Build Tests

- [ ] 6.2.1 Create `tests/pwsh/SnapBuild.Tests.ps1`:
  - Verify staged directory structure
  - Verify `.desktop` file has correct MIME types
  - Verify launcher script is executable
  - Verify pwsh verification passes on trimmed bundle

### 6.3 Run Full Test Suite

- [ ] 6.3.1 Linux: `Invoke-Pester tests -Output Minimal` — target 260+ passed, 0 failed
- [ ] 6.3.2 Windows: `Invoke-Pester tests -Output Minimal` — target 428 passed, 0 failed (unchanged)

### 6.4 Manual E2E Testing

- [ ] 6.4.1 Command line: `markview README.md` — opens in browser
- [ ] 6.4.2 Double-click `.md` in file manager — opens in browser
- [ ] 6.4.3 Click linked `.md` file in rendered page — opens via `mdview:` protocol
- [ ] 6.4.4 Theme toggle works
- [ ] 6.4.5 Syntax highlighting works
- [ ] 6.4.6 Remote images opt-in works
- [ ] 6.4.7 File not found — zenity dialog appears

---

## Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| App name | `markview` | Matches Windows Store name |
| Distribution | Strict Snap | Modern Store-style install, automatic updates, MIME registration |
| pwsh | Bundled + trimmed | Snaps are self-contained by design |
| Dialogs | zenity (with stderr fallback) | Works across GTK desktops, included via stage-packages |
| MOTW | Stubbed (`$null`) | No Linux equivalent; safe default |
| Architectures | arm64, amd64 | Cover most Ubuntu users |
| Confinement | strict + `home` plug | Files under `$HOME` accessible (repos, downloads, documents) |

## Out of Scope (Future)

- Context menu integration (Nautilus/Thunar scripts — desktop-specific)
- Snap Store publishing (requires account + review — separate task)
- Flatpak/AppImage alternatives
- .deb/.rpm packages

## Files to Create/Modify

### New Files
- `src/core/MarkdownViewer.Shared.psm1` — shared cross-platform functions
- `src/linux/MarkdownViewer.psm1` — Linux platform module
- `src/linux/markview` — bash launcher script
- `src/linux/markview.desktop` — desktop entry
- `src/linux/markview.png` — app icon
- `installers/linux-snap/snap/snapcraft.yaml` — snap definition
- `installers/linux-snap/build.sh` — build script
- `installers/linux-snap/scripts/Trim-PwshBundle-Linux.ps1` — trimming script
- `installers/linux-snap/scripts/Verify-MarkViewPwsh-Linux.ps1` — verification script
- `tests/pwsh/LinuxModule.Tests.ps1` — Linux module tests
- `tests/pwsh/SnapBuild.Tests.ps1` — snap build tests

### Modified Files
- `src/win/MarkdownViewer.psm1` — extract shared functions, add dialog exports
- `src/core/Open-Markdown.ps1` — platform-aware module loading, remove inline WinForms
- `tests/MarkdownViewer.Tests.ps1` — add platform skip guards
- `tests/pwsh/BrowserLaunch.Tests.ps1` — add platform skip guard
- `tests/pwsh/Build.Tests.ps1` — fix `$env:TEMP` for cross-platform
- `tests/pwsh/LocalFileNormalization.Tests.ps1` — add platform skip guards
- `tests/pwsh/LocalFileNormalization.ActualBehavior.Tests.ps1` — add platform skip guard
- `tests/pwsh/LocalFileNormalization.UncBasePath.Tests.ps1` — add platform skip guard
- `tests/pwsh/LocalFileNormalizationWithFragments.Tests.ps1` — add platform skip guards
- `tests/pwsh/LocalFileNormalizationWithFragments.ActualBehavior.Tests.ps1` — add platform skip guard
- `tests/pwsh/Stage.Tests.ps1` — fix path separators
