# macOS Port Implementation Plan

## Overview

Port MarkView to macOS by adding a macOS platform module (`src/mac/`), making the core engine select between Windows, Linux, and macOS explicitly, adding a small native macOS app host for Finder and URL-scheme activation, and packaging a signed/notarized `.app` inside a `.dmg` for distribution.

The first production distribution target should be direct macOS distribution with a Developer ID signed and notarized DMG. A Mac App Store release is possible later, but it should be treated as a separate track because App Sandbox, file access, browser launch behavior, and the bundled PowerShell runtime need additional validation.

**Target platforms:** macOS 14+ initially, arm64-only for the first public release
**Primary local baseline:** macOS 26.4 on Apple Silicon arm64, PowerShell 7.6.3  
**Distribution:** Developer ID signed and notarized DMG, with GitHub Releases as the first download channel  
**Command:** `markview file.md` for development and optional CLI use  
**Desktop integration:** Finder "Open With" for `.md` and `.markdown`, plus `mdview:` URI scheme for linked Markdown navigation

---

## Phase 0: macOS Environment Setup

**Goal:** Establish a working macOS development environment and identify which existing tests should run on macOS.

### 0.1 Confirm Toolchain

The current Mac development machine has:

```bash
sw_vers
# ProductVersion: 26.4

uname -m
# arm64

pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
# 7.6.3

command -v xcodebuild swiftc open osascript plutil codesign xcrun iconutil hdiutil sips
```

Required developer tools:

- Xcode or Xcode Command Line Tools
- PowerShell 7+
- Pester 5.x
- Apple Developer Program membership for public Developer ID signing and notarization

Install Pester:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module Pester -RequiredVersion 5.7.1 -Force
```

### 0.2 PowerShell Runtime Source

For development, use the normal macOS PowerShell package or Homebrew install. For app packaging, use the official macOS `tar.gz` archive so the bundle can stage and trim the runtime consistently, similar to the Linux snap flow.

Initial packaging should support:

| Architecture | PowerShell archive |
|--------------|--------------------|
| arm64 | `powershell-<version>-osx-arm64.tar.gz` |
| x64 | `powershell-<version>-osx-x64.tar.gz` |

Create `installers/macos-dmg/build/pwsh-versions.json` rather than reusing the Linux file, because macOS archives and hashes are different.

### 0.3 Test Classification

| Area | Current Status on macOS | Required Change |
|------|--------------------------|-----------------|
| Core sanitizer/theme/link tests | Mostly cross-platform | Run as normal where they do not depend on Windows paths |
| Windows MSIX tests | Windows-only | Already guarded with `-Skip:(-not $IsWindows)` |
| Linux module tests | Currently skip only Windows | Change to skip unless `$IsLinux` |
| Snap build tests | Currently skip only Windows | Change to skip unless `$IsLinux` |
| Browser registry tests | Windows-only | Existing non-Windows guard is correct |
| macOS module tests | Missing | Add `tests/pwsh/MacModule.Tests.ps1` |
| macOS bundle tests | Missing | Add `tests/pwsh/MacBundle.Tests.ps1` |

### 0.4 Immediate Compatibility Finding

`src/core/Open-Markdown.ps1` currently chooses the Linux module for every non-Windows platform:

```powershell
$platformDir = if ($IsWindows) { 'win' } else { 'linux' }
```

This must become a three-way platform selection before macOS can run correctly from source.

---

## Phase 1: Platform Contract Cleanup

**Goal:** Make the core engine call platform functions instead of embedding Windows-vs-Linux assumptions.

### 1.1 Add Explicit Platform Selection

- [ ] 1.1.1 Update module discovery in `src/core/Open-Markdown.ps1`:

  ```powershell
  $platformDir = if ($IsWindows) {
      'win'
  } elseif ($IsMacOS) {
      'mac'
  } elseif ($IsLinux) {
      'linux'
  } else {
      throw "Unsupported platform: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
  }
  ```

- [ ] 1.1.2 Keep installed-layout behavior unchanged: if `MarkdownViewer.psm1` is co-located with `Open-Markdown.ps1`, import that first.
- [ ] 1.1.3 Add tests that module discovery chooses `src/mac/MarkdownViewer.psm1` when `$IsMacOS`.

### 1.2 Move Output Directory Selection into Platform Modules

The current core uses `%TEMP%` on Windows and `~/MarkView` on every non-Windows platform. That Linux choice exists for snap-confined browsers, but macOS should use a more conventional cache directory.

- [ ] 1.2.1 Add `Get-MarkViewOutputDirectory` to all platform modules.
- [ ] 1.2.2 Windows returns `[IO.Path]::GetTempPath()`.
- [ ] 1.2.3 Linux returns `~/MarkView` to preserve snap browser compatibility.
- [ ] 1.2.4 macOS returns `~/Library/Caches/MarkView` for direct Developer ID builds.
- [ ] 1.2.5 Update `Open-Markdown.ps1` to call `Get-MarkViewOutputDirectory`.
- [ ] 1.2.6 Add focused tests for the output directory function on each platform.

### 1.3 Generalize File Trust Marker Handling

Windows uses Mark-of-the-Web. macOS has a similar user-facing concept through the `com.apple.quarantine` extended attribute. Linux currently has no equivalent in this project.

- [ ] 1.3.1 Keep `Test-Motw` for compatibility, but document the platform behavior:
  - Windows: return ZoneId from `Zone.Identifier`.
  - Linux: return `$null`.
  - macOS: return `3` when `com.apple.quarantine` is present, otherwise `$null`.
- [ ] 1.3.2 Add `Clear-FileTrustMarker` to platform modules:
  - Windows: `Unblock-File -LiteralPath $FilePath`.
  - macOS: `/usr/bin/xattr -d com.apple.quarantine "$FilePath"`.
  - Linux: no-op.
- [ ] 1.3.3 Replace the Windows-only `Unblock-File` guard in `Open-Markdown.ps1` with `Clear-FileTrustMarker`.
- [ ] 1.3.4 Rename the user-facing dialog text from "MOTW" concepts to "downloaded from the internet" where appropriate, so the same UX works on Windows and macOS.

### 1.4 Keep Browser Launch Platform-Specific

- [ ] 1.4.1 Keep `Start-DefaultBrowser` as the browser launch abstraction.
- [ ] 1.4.2 Windows continues launching the default browser executable directly to preserve fragments.
- [ ] 1.4.3 Linux continues using `snapctl user-open` inside snap and `xdg-open` outside snap.
- [ ] 1.4.4 macOS uses `/usr/bin/open <url>` and must verify that `file://...?_fragment=...` survives to Safari, Chrome, Firefox, and Edge.

---

## Phase 2: macOS Platform Module (`src/mac/`)

**Goal:** Add macOS-specific implementations of the platform functions.

### 2.1 Create macOS Module Structure

- [ ] 2.1.1 Create `src/mac/`.
- [ ] 2.1.2 Create `src/mac/MarkdownViewer.psm1`.
- [ ] 2.1.3 Import the shared module from the installed layout or development layout:

  ```powershell
  $sharedPath = Join-Path $PSScriptRoot 'MarkdownViewer.Shared.psm1'
  if (-not (Test-Path $sharedPath)) {
      $sharedPath = Join-Path $PSScriptRoot '../core/MarkdownViewer.Shared.psm1'
  }
  Import-Module $sharedPath -Force
  ```

### 2.2 Implement macOS-Specific Functions

- [ ] 2.2.1 `Get-FileBaseHref`

  Similar to Linux, but tests should include `/Users/...`, spaces, and iCloud-style paths. Prefer URI APIs if they produce stable `file:///` output without breaking relative Markdown links.

- [ ] 2.2.2 `Test-Motw`

  ```powershell
  function Test-Motw {
      param([Parameter(Mandatory)][string] $FilePath)

      & /usr/bin/xattr -p com.apple.quarantine $FilePath *> $null
      if ($LASTEXITCODE -eq 0) { return 3 }
      return $null
  }
  ```

- [ ] 2.2.3 `Clear-FileTrustMarker`

  ```powershell
  function Clear-FileTrustMarker {
      param([Parameter(Mandatory)][string] $FilePath)

      & /usr/bin/xattr -d com.apple.quarantine $FilePath 2>$null
  }
  ```

- [ ] 2.2.4 `Start-DefaultBrowser`

  ```powershell
  function Start-DefaultBrowser {
      param([Parameter(Mandatory)][string] $Url)
      Start-Process '/usr/bin/open' -ArgumentList $Url
  }
  ```

- [ ] 2.2.5 `Get-MarkViewOutputDirectory`

  ```powershell
  function Get-MarkViewOutputDirectory {
      $dir = Join-Path $HOME 'Library/Caches/MarkView'
      if (-not (Test-Path $dir)) {
          New-Item -ItemType Directory -Path $dir -Force | Out-Null
      }
      return $dir
  }
  ```

- [ ] 2.2.6 Dialog functions

  Use `osascript` for first implementation:

  - `Initialize-PlatformUI`: no-op.
  - `Show-MotwWarning`: AppleScript dialog with `Open`, `Unblock & Open`, `Cancel`.
  - `Show-FileNotFound`: AppleScript warning with terminal fallback.
  - `Show-ErrorDialog`: AppleScript error dialog with terminal fallback.

  Longer term, the native macOS host can own these dialogs with `NSAlert`, but `osascript` keeps the first port close to the current Linux module pattern.

### 2.3 Export List

- [ ] 2.3.1 Export the same shared and platform functions as Windows/Linux, plus any new platform contract functions.
- [ ] 2.3.2 Update Windows and Linux modules to export the new contract functions too.
- [ ] 2.3.3 Add export parity tests that compare required contract functions across `src/win`, `src/linux`, and `src/mac`.

---

## Phase 3: macOS Development Launcher

**Goal:** Support command-line development before the app bundle exists.

### 3.1 Create `src/mac/markview`

- [ ] 3.1.1 Add a shell launcher:

  ```bash
  #!/bin/bash
  set -e

  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

  if [ -x "$SCRIPT_DIR/../pwsh/pwsh" ]; then
      PWSH="$SCRIPT_DIR/../pwsh/pwsh"
  else
      PWSH="pwsh"
  fi

  if [ -d "$SCRIPT_DIR/../app" ]; then
      APP_DIR="$SCRIPT_DIR/../app"
  else
      APP_DIR="$SCRIPT_DIR/../core"
  fi

  exec "$PWSH" -NoProfile -ExecutionPolicy Bypass \
      -File "$APP_DIR/Open-Markdown.ps1" -Path "$1"
  ```

- [ ] 3.1.2 Make executable: `chmod +x src/mac/markview`.
- [ ] 3.1.3 Verify from source:

  ```bash
  src/mac/markview README.md
  ```

### 3.2 Do Not Rely on Shell Script for Finder Activation

Finder document activation and custom URL scheme activation are delivered through Launch Services and Apple Events. A plain shell script is useful for development, but the distributable app needs a real `.app` bundle with a native executable that can receive file-open and URL-open events.

---

## Phase 4: Native macOS App Host

**Goal:** Add a thin native host analogous to the Windows `MarkdownViewerHost.exe`.

### 4.1 Host Responsibilities

The macOS host should be intentionally small and stateless:

- [ ] 4.1.1 Receive Finder file-open events for `.md` and `.markdown`.
- [ ] 4.1.2 Receive `mdview:` URL-open events from browsers.
- [ ] 4.1.3 Resolve bundled `pwsh` and `Open-Markdown.ps1` inside the app bundle.
- [ ] 4.1.4 Launch:

  ```text
  pwsh -NoProfile -ExecutionPolicy Bypass -File <Resources/app/Open-Markdown.ps1> -Path <input>
  ```

- [ ] 4.1.5 Exit after handing off to PowerShell.
- [ ] 4.1.6 On no-argument launch, show a simple help/about dialog or open README-style guidance.

### 4.2 Implementation Option

Recommended first implementation: Swift + AppKit, compiled with `swiftc` or an Xcode project.

Proposed location:

```text
src/host/MarkdownViewerMacHost/
|-- MarkViewHost.swift
|-- Info.plist.template
\-- MarkdownViewerMacHost.md
```

The host should implement `NSApplicationDelegate` methods for file and URL activation, then use `Process` to launch the bundled PowerShell runtime. Keep argument passing structured as an array, matching the spirit of the Windows host's argument safety.

### 4.3 Info.plist Launch Services Declarations

The generated app bundle needs Launch Services metadata:

- `CFBundleIdentifier`: `com.omasoud.MarkView`.
- `CFBundleDisplayName`: `MarkView`.
- `CFBundleDocumentTypes`: claim `.md` and `.markdown` as viewer document types.
- `CFBundleURLTypes`: claim `mdview`.
- `CFBundleIconFile`: `markview.icns`.
- `LSMinimumSystemVersion`: minimum supported macOS version.
- `LSApplicationCategoryType`: likely `public.app-category.utilities`.

Document type notes:

- Prefer `CFBundleTypeRole = Viewer`.
- Include extensions `md` and `markdown`.
- Include MIME type `text/markdown`.
- Include modern UTI declarations where useful, likely `net.daringfireball.markdown`.
- Use a conservative handler rank initially so the app appears in "Open With" without forcibly stealing existing defaults.

### 4.4 Expected App Bundle Layout

```text
MarkView.app/
\-- Contents/
    |-- Info.plist
    |-- MacOS/
    |   \-- MarkViewHost
    \-- Resources/
        |-- markview.icns
        |-- app/
        |   |-- Open-Markdown.ps1
        |   |-- MarkdownViewer.psm1
        |   |-- MarkdownViewer.Shared.psm1
        |   |-- script.js
        |   |-- style.css
        |   |-- highlight.min.js
        |   |-- highlight-theme.css
        |   \-- markdown.ico
        \-- pwsh/
            \-- pwsh + trimmed runtime
```

---

## Phase 5: macOS Packaging

**Goal:** Build a repeatable app bundle and DMG with bundled PowerShell.

### 5.1 Create Installer Directory

- [ ] 5.1.1 Create `installers/macos-dmg/`.
- [ ] 5.1.2 Create subdirectories:

```text
installers/macos-dmg/
|-- build/
|   \-- pwsh-versions.json
|-- scripts/
|   |-- Trim-PwshBundle-macOS.ps1
|   |-- Verify-MarkViewPwsh-macOS.ps1
|   |-- New-MarkViewIcns.ps1
|   \-- Sign-MarkViewApp.sh
|-- build.sh
\-- dmg/
```

### 5.2 Build Script Flow

`installers/macos-dmg/build.sh` should:

- [ ] 5.2.1 Normalize architecture (`arm64`, `x64`).
- [ ] 5.2.2 Stage `src/core` and `src/mac` files.
- [ ] 5.2.3 Download the pinned macOS PowerShell archive if not cached.
- [ ] 5.2.4 Verify SHA256 hash.
- [ ] 5.2.5 Extract and trim PowerShell.
- [ ] 5.2.6 Run the macOS PowerShell bundle verifier.
- [ ] 5.2.7 Generate `markview.icns` from existing icon assets.
- [ ] 5.2.8 Compile the Swift host.
- [ ] 5.2.9 Generate `Info.plist` from template.
- [ ] 5.2.10 Assemble `MarkView.app`.
- [ ] 5.2.11 Ad-hoc sign for local developer builds when no Developer ID identity is provided.
- [ ] 5.2.12 Optionally sign with Developer ID when `MARKVIEW_CODESIGN_IDENTITY` is set.
- [ ] 5.2.13 Create a DMG in `installers/macos-dmg/output/`.

### 5.3 PowerShell Trimming

Start from the Linux trimming script but validate macOS-specific runtime needs separately.

Keep at minimum:

- `pwsh`
- .NET runtime native libraries required by PowerShell on macOS
- `Microsoft.PowerShell.Management`
- `Microsoft.PowerShell.Utility`
- assemblies required for `ConvertFrom-Markdown`
- ICU/globalization dependencies if required by the runtime

The verifier should check:

```powershell
& "$PwshDir/pwsh" -NoProfile -Command @'
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
ConvertFrom-Markdown -InputObject "# hello" | Out-Null
Import-Module "<staged app>/MarkdownViewer.psm1" -Force
'@
```

### 5.4 Icon Generation

Use macOS-native tools:

```bash
mkdir -p markview.iconset
sips -z 16 16     src/linux/markview.png --out markview.iconset/icon_16x16.png
sips -z 32 32     src/linux/markview.png --out markview.iconset/icon_16x16@2x.png
sips -z 32 32     src/linux/markview.png --out markview.iconset/icon_32x32.png
sips -z 64 64     src/linux/markview.png --out markview.iconset/icon_32x32@2x.png
sips -z 128 128   src/linux/markview.png --out markview.iconset/icon_128x128.png
sips -z 256 256   src/linux/markview.png --out markview.iconset/icon_128x128@2x.png
sips -z 256 256   src/linux/markview.png --out markview.iconset/icon_256x256.png
sips -z 512 512   src/linux/markview.png --out markview.iconset/icon_256x256@2x.png
sips -z 512 512   src/linux/markview.png --out markview.iconset/icon_512x512.png
iconutil -c icns markview.iconset -o markview.icns
```

If the source icon is only 256x256, create larger source art before final public release so the 512x512 slots are not upscaled.

---

## Phase 6: Signing, Notarization, and Public Distribution

**Goal:** Produce a Gatekeeper-friendly Mac download.

### 6.1 Recommended First Distribution Path

Ship a signed and notarized DMG outside the Mac App Store first.

Reasons:

- It matches the project's existing lightweight utility model.
- It allows bundling PowerShell without App Store sandbox review questions as the first blocker.
- It supports direct download from GitHub Releases.
- It can later be wrapped by a Homebrew Cask.
- It still gives users Gatekeeper trust when signed and notarized correctly.

### 6.2 Signing Strategy

- [ ] 6.2.1 Sign nested Mach-O files inside `Resources/pwsh` first.
- [ ] 6.2.2 Sign the Swift host.
- [ ] 6.2.3 Sign `MarkView.app` last.
- [ ] 6.2.4 Use Developer ID Application identity for public builds.
- [ ] 6.2.5 Enable hardened runtime.
- [ ] 6.2.6 Timestamp signatures.
- [ ] 6.2.7 Validate with:

  ```bash
  codesign --verify --deep --strict --verbose=4 MarkView.app
  spctl --assess --type execute --verbose=4 MarkView.app
  ```

### 6.3 Entitlements to Validate

Start with the smallest entitlement set that lets the host and bundled PowerShell run under hardened runtime.

Likely candidates to test:

| Entitlement | Why it might be needed |
|-------------|-------------------------|
| `com.apple.security.cs.allow-jit` | .NET runtime may require JIT execution |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Some .NET runtime paths may require executable memory |
| `com.apple.security.cs.disable-library-validation` | Bundled runtime/library loading may require it if signing is not accepted as same-team code |

Do not add these blindly. Sign, launch, run end-to-end, then add only what the hardened runtime actually requires.

### 6.4 Notarization Flow

- [ ] 6.4.1 Store notary credentials once:

  ```bash
  xcrun notarytool store-credentials markview-notary
  ```

- [ ] 6.4.2 Create the DMG.
- [ ] 6.4.3 Sign the DMG if needed.
- [ ] 6.4.4 Submit and wait:

  ```bash
  xcrun notarytool submit MarkView.dmg --keychain-profile markview-notary --wait
  ```

- [ ] 6.4.5 Staple the ticket:

  ```bash
  xcrun stapler staple MarkView.dmg
  ```

- [ ] 6.4.6 Validate on a clean Mac user account, then on another Mac if available:

  ```bash
  spctl --assess --type open --context context:primary-signature --verbose=4 MarkView.dmg
  ```

### 6.5 Mac App Store Track

Defer Mac App Store work until the Developer ID DMG is stable.

Mac App Store requirements and concerns:

- App Sandbox is required for Mac App Store distribution.
- Finder-opened files and linked Markdown files may need security-scoped URL handling.
- Launching a bundled PowerShell child process from a sandboxed app needs careful entitlement and review validation.
- Writing generated HTML where an external browser can read it may need a different strategy under sandboxing.
- The app may need a native UI surface for sandbox-friendly open panels and help.

---

## Phase 7: Testing

**Goal:** Prove macOS behavior without regressing Windows or Linux.

### 7.1 Test Guard Cleanup

- [ ] 7.1.1 Change `tests/pwsh/LinuxModule.Tests.ps1` to skip unless `$IsLinux`.
- [ ] 7.1.2 Change `tests/pwsh/SnapBuild.Tests.ps1` to skip unless `$IsLinux`.
- [ ] 7.1.3 Audit all tests with `rg -n "IsWindows|IsLinux|IsMacOS|Skip:" tests`.
- [ ] 7.1.4 Keep Windows-only path and registry tests guarded with `$IsWindows`.
- [ ] 7.1.5 Add macOS-only tests guarded with `$IsMacOS`.

### 7.2 macOS Module Tests

Create `tests/pwsh/MacModule.Tests.ps1`:

- [ ] 7.2.1 Imports `src/mac/MarkdownViewer.psm1`.
- [ ] 7.2.2 Verifies shared functions are exported.
- [ ] 7.2.3 Verifies platform functions are exported.
- [ ] 7.2.4 Tests `Get-FileBaseHref` with:
  - `/Users/test/docs/file.md`
  - `/Users/test/My Documents/file.md`
  - `/Users/test/Library/Mobile Documents/...`
- [ ] 7.2.5 Tests `Get-MarkViewOutputDirectory`.
- [ ] 7.2.6 Tests quarantine detection with a temp file and `xattr -w com.apple.quarantine`.
- [ ] 7.2.7 Tests `Clear-FileTrustMarker`.
- [ ] 7.2.8 Verifies `Start-DefaultBrowser` command shape without actually opening a browser, likely by extracting command construction into a helper or mocking `Start-Process`.

### 7.3 macOS Bundle Tests

Create `tests/pwsh/MacBundle.Tests.ps1`:

- [ ] 7.3.1 `installers/macos-dmg/build.sh --stage-only` succeeds.
- [ ] 7.3.2 `MarkView.app/Contents/Info.plist` exists and passes `plutil -lint`.
- [ ] 7.3.3 `CFBundleDocumentTypes` contains `md` and `markdown`.
- [ ] 7.3.4 `CFBundleURLTypes` contains `mdview`.
- [ ] 7.3.5 Host executable exists and is executable.
- [ ] 7.3.6 Staged app payload includes core files and macOS module.
- [ ] 7.3.7 Staged bundled `pwsh` exists and passes verifier.
- [ ] 7.3.8 Ad-hoc signature verifies for local builds.

### 7.4 Manual E2E Tests

- [ ] 7.4.1 From source: `src/mac/markview README.md`.
- [ ] 7.4.2 From app bundle: `open -a MarkView README.md`.
- [ ] 7.4.3 Finder: right-click `.md` file, Open With, MarkView.
- [ ] 7.4.4 Finder: set MarkView as default for `.md`, double-click file.
- [ ] 7.4.5 Browser: click a local linked `.md` file and confirm `mdview:` activation.
- [ ] 7.4.6 Confirm `_fragment` scrolling works through `mdview:file:///...?_fragment=...`.
- [ ] 7.4.7 Confirm theme toggle, theme variations, syntax highlighting, and remote image opt-in.
- [ ] 7.4.8 Confirm quarantine warning appears for a quarantined Markdown file.
- [ ] 7.4.9 Confirm "Unblock & Open" removes `com.apple.quarantine`.
- [ ] 7.4.10 Confirm generated HTML and copied highlight assets are cleaned up or overwritten safely.

### 7.5 Distribution QA

- [ ] 7.5.1 Install from unsigned local DMG on development machine.
- [ ] 7.5.2 Install from signed/notarized DMG on development machine.
- [ ] 7.5.3 Install from signed/notarized DMG on a clean macOS account.
- [ ] 7.5.4 Install on a second Mac if available.
- [ ] 7.5.5 Verify Gatekeeper does not show an unidentified developer warning.
- [ ] 7.5.6 Verify the app appears in Finder "Open With".
- [ ] 7.5.7 Verify uninstall is drag-to-trash plus optional cache cleanup.

---

## Phase 8: Documentation Updates

**Goal:** Make macOS a first-class supported platform in the repo docs.

- [ ] 8.1 Update `README.md`:
  - Supported platforms: Windows, Linux, macOS.
  - macOS install from DMG.
  - macOS run from source.
  - macOS requirements and uninstall steps.
  - Security note for macOS quarantine.
- [ ] 8.2 Update `dev/docs/developer-guide.md`:
  - macOS prerequisites.
  - Build app bundle and DMG.
  - Run macOS tests.
  - Sign/notarize release builds.
- [ ] 8.3 Update `dev/docs/markdown-viewer-architecture.md`:
  - Add macOS host to entry-point diagram.
  - Add macOS package structure.
  - Add macOS activation flow.
  - Split "Linux" non-Windows notes from general Unix notes.
- [ ] 8.4 Update `PRIVACY.md` if macOS distribution or update checks add any new behavior.
- [ ] 8.5 Update `THIRD-PARTY-LICENSES.md` only if new bundled dependencies are introduced.

---

## Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform directory | `src/mac/` | Matches existing short names: `win`, `linux` |
| First architecture | arm64 | Current development hardware is Apple Silicon |
| Later architecture | x64 deferred | Still useful for Intel Macs, but not part of the first public Mac release |
| Runtime | Bundled and trimmed PowerShell | Matches Windows MSIX and Linux snap user experience |
| Dev launcher | `src/mac/markview` | Fast source testing without building an app bundle |
| Finder/protocol activation | Native Swift/AppKit host | Required for Launch Services file and URL events |
| First public distribution | Developer ID signed and notarized DMG | Practical, Gatekeeper-friendly, lower friction than Mac App Store |
| Mac App Store | Future track | Sandbox and child-process runtime behavior require separate design |
| Download trust marker | `com.apple.quarantine` support | Gives macOS users parity with Windows MOTW warning |
| Generated HTML location | `~/Library/Caches/MarkView` | Conventional for direct macOS app builds |

---

## Open Decisions

- [x] Final display name: `MarkView`.
- [x] Final bundle identifier: `com.omasoud.MarkView`.
- [ ] Minimum supported macOS version.
- [x] First public macOS release architecture: arm64-only.
- [ ] Whether direct distribution should include auto-update support, such as Sparkle, or rely on GitHub Releases initially.
- [ ] Whether Homebrew Cask should be a release goal for the first public macOS version.

---

## Out of Scope for First macOS Port

- Mac App Store submission.
- Sparkle auto-update integration.
- Homebrew Cask publication.
- Universal binary app with both arm64 and x64 PowerShell runtimes in one DMG.
- Native Markdown rendering in WebKit.
- Replacing PowerShell with a native renderer.

---

## Files to Create or Modify

### New Files

- `src/mac/MarkdownViewer.psm1`
- `src/mac/markview`
- `src/host/MarkdownViewerMacHost/MarkViewHost.swift`
- `src/host/MarkdownViewerMacHost/Info.plist.template`
- `installers/macos-dmg/build.sh`
- `installers/macos-dmg/build/pwsh-versions.json`
- `installers/macos-dmg/scripts/Trim-PwshBundle-macOS.ps1`
- `installers/macos-dmg/scripts/Verify-MarkViewPwsh-macOS.ps1`
- `installers/macos-dmg/scripts/New-MarkViewIcns.ps1`
- `installers/macos-dmg/scripts/Sign-MarkViewApp.sh`
- `tests/pwsh/MacModule.Tests.ps1`
- `tests/pwsh/MacBundle.Tests.ps1`

### Modified Files

- `src/core/Open-Markdown.ps1`
- `src/win/MarkdownViewer.psm1`
- `src/linux/MarkdownViewer.psm1`
- `tests/pwsh/LinuxModule.Tests.ps1`
- `tests/pwsh/SnapBuild.Tests.ps1`
- `tests/MarkdownViewer.Tests.ps1`
- `README.md`
- `dev/docs/developer-guide.md`
- `dev/docs/markdown-viewer-architecture.md`

---

## References Checked

- [Apple: Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Apple: Launch Services Concepts](https://developer.apple.com/library/archive/documentation/Carbon/Conceptual/LaunchServicesConcepts/LSCConcepts/LSCConcepts.html)
- [Microsoft: Install PowerShell 7 on macOS](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos)
