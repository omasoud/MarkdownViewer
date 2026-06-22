# Markdown Viewer Developer Guide

This guide covers building, testing, and developing Markdown Viewer on Windows, Linux, and macOS.

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Windows Prerequisites](#windows-prerequisites)
  - [Linux Prerequisites](#linux-prerequisites)
  - [macOS Prerequisites](#macos-prerequisites)
  - [Installing Pester](#installing-pester)
- [Project Structure](#project-structure)
- [Building](#building)
  - [Windows: Visual Studio](#windows-visual-studio)
  - [Windows: Command Line (msbuild)](#windows-command-line-msbuild)
  - [Windows: Build Outputs](#windows-build-outputs)
  - [Linux: Snap Package](#linux-snap-package)
  - [macOS: DMG Package](#macos-dmg-package)
  - [Cleaning Build Outputs](#cleaning-build-outputs)
- [Running Tests](#running-tests)
  - [Run All Tests (Windows)](#run-all-tests-windows)
  - [Run All Tests (Linux)](#run-all-tests-linux)
  - [Run All Tests (macOS)](#run-all-tests-macos)
  - [PowerShell Tests (Pester)](#powershell-tests-pester)
  - [C# Tests (xUnit) — Windows Only](#c-tests-xunit--windows-only)
  - [E2E MSIX Activation Tests — Windows Only](#e2e-msix-activation-tests--windows-only)
- [Development Testing](#development-testing)
  - [Testing Changes to the Engine](#testing-changes-to-the-engine)
  - [Testing CSS/JS Changes](#testing-cssjs-changes)
  - [Testing with Module Changes](#testing-with-module-changes)
  - [Manual Local-File Link Test (Windows)](#manual-local-file-link-test-windows)
  - [Manual Local-File Link Test (Linux)](#manual-local-file-link-test-linux)
  - [Manual Local-File Link Test (macOS)](#manual-local-file-link-test-macos)
  - [Testing the Installed MSIX (Windows)](#testing-the-installed-msix-windows)
  - [Testing the Installed Snap (Linux)](#testing-the-installed-snap-linux)
  - [Testing the Installed DMG (macOS)](#testing-the-installed-dmg-macos)
- [Creating Installers](#creating-installers)
  - [Ad-hoc Installer — Windows](#ad-hoc-installer--windows)
  - [MSIX Package — Windows](#msix-package--windows)
  - [Signing MSIX Packages](#signing-msix-packages)
  - [Installing the MSIX (Sideload)](#installing-the-msix-sideload)
  - [Snap Package — Linux](#snap-package--linux)
  - [DMG Package — macOS](#dmg-package--macos)
- [Debugging](#debugging)
  - [Debugging the Engine](#debugging-the-engine)
  - [Debugging the Host EXE (Windows)](#debugging-the-host-exe-windows)
  - [Debugging the Mac Host (macOS)](#debugging-the-mac-host-macos)
  - [Viewing Generated HTML](#viewing-generated-html)
- [Common Development Tasks](#common-development-tasks)
  - [Bumping the Version](#bumping-the-version)
- [Troubleshooting](#troubleshooting)
  - [Windows Troubleshooting](#windows-troubleshooting)
  - [Linux Troubleshooting](#linux-troubleshooting)
  - [macOS Troubleshooting](#macos-troubleshooting)
- [Code Style](#code-style)
- [Contributing](#contributing)

---

## Prerequisites

### Windows Prerequisites

- **PowerShell 7+** (pwsh) — Required for all scripts and testing
- **Windows 10 SDK** — Required for MSIX packaging (includes `makeappx.exe`)
- **.NET Framework 4.8.1** — Pre-installed on Windows 11 (no SDK needed)
- **Visual Studio 2026** — Required for building the Host EXE (msbuild)
- **Pester 5.x** — Required for PowerShell tests

```powershell
# PowerShell 7 (if not installed)
winget install Microsoft.PowerShell

# .NET Framework 4.8.1 is pre-installed on Windows 11
# No separate installation needed
```

### Linux Prerequisites

- **PowerShell 7+** (pwsh) — Required for the engine and testing
- **snapcraft** — Required for building the snap package
- **wget**, **sha256sum** — Required for downloading the bundled pwsh

```bash
# Ubuntu amd64 — install pwsh from apt
sudo apt-get update && sudo apt-get install -y powershell

# Ubuntu arm64 — install pwsh from tarball (apt repo is x64-only)
PWSH_VERSION="7.5.4"
wget -q "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-arm64.tar.gz" -O /tmp/pwsh.tar.gz
sudo mkdir -p /opt/microsoft/powershell/7
sudo tar xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7
sudo chmod +x /opt/microsoft/powershell/7/pwsh
sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh

# snapcraft (for building snaps)
sudo snap install snapcraft --classic
```

### macOS Prerequisites

- **PowerShell 7+** (pwsh) — Required for the engine, tests, and packaging scripts
- **Xcode Command Line Tools** — Required for `swiftc`, `codesign`, `hdiutil`, `sips`, `iconutil`, and `plutil`
- **Apple Developer Program membership** — Required only for public Developer ID signing and notarization

```bash
# Xcode Command Line Tools
xcode-select --install

# Verify required tools
command -v pwsh swiftc codesign hdiutil sips iconutil plutil
```

### Installing Pester

Pester 5.x is required for PowerShell tests on all platforms. The system may have Pester 3.x pre-installed; always import explicitly:

```powershell
# Install Pester 5.x (one-time)
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser

# Verify version
Import-Module Pester -RequiredVersion 5.7.1 -Force
```

---

## Project Structure

```
MarkdownViewer/
├── MarkdownViewer.slnx          # Visual Studio solution (Windows)
├── src/
│   ├── core/                    # Cross-platform engine + assets
│   │   ├── Open-Markdown.ps1    # Main PowerShell engine
│   │   ├── MarkdownViewer.Shared.psm1  # Shared cross-platform module
│   │   ├── script.js            # Client-side JavaScript
│   │   ├── style.css            # Client-side CSS
│   │   ├── highlight.min.js     # Syntax highlighting
│   │   ├── highlight-theme.css  # Highlight.js theme
│   │   └── icons/               # Application icons
│   ├── win/                     # Windows platform module
│   │   ├── MarkdownViewer.psm1  # Windows-specific functions
│   │   ├── viewmd.vbs           # VBScript launcher (ad-hoc)
│   │   └── uninstall.vbs        # Silent uninstall helper
│   ├── linux/                   # Linux platform module
│   │   ├── MarkdownViewer.psm1  # Linux-specific functions
│   │   ├── markview             # Bash launcher script
│   │   ├── markview.desktop     # Freedesktop desktop entry
│   │   └── markview.png         # Application icon (256x256)
│   ├── mac/                     # macOS platform module
│   │   ├── MarkdownViewer.psm1  # macOS-specific functions
│   │   └── markview             # Bash launcher script
│   └── host/                    # Native host applications
│       ├── MarkdownViewerHost/     # Windows .NET Framework 4.8.1 host
│       └── MarkdownViewerMacHost/  # macOS Swift/AppKit host
├── installers/
│   ├── win-adhoc/               # Per-user ad-hoc installer (Windows)
│   ├── win-msix/                # MSIX packaging (Windows)
│   ├── linux-snap/              # Snap packaging (Linux)
│   │   ├── snap/snapcraft.yaml  # Snap definition
│   │   ├── build.sh             # Stage + trim + build snap
│   │   └── scripts/             # Trimming & verification scripts
│   └── macos-dmg/               # DMG packaging (macOS)
│       ├── build.sh             # Stage + trim + build DMG
│       └── scripts/             # Icon, signing, trimming, verification
├── tests/
│   ├── Invoke-AllTests.ps1      # Run all tests at once (Windows)
│   ├── MarkdownViewer.Tests.ps1 # Pester tests (engine, module, MSIX structure)
│   ├── Test-PackagedActivation.ps1  # E2E MSIX activation tests (Windows)
│   ├── Test-StagedPayload.ps1   # Staged payload integration tests (Windows)
│   ├── MarkdownViewerHost.Tests/# xUnit tests — C# host (Windows)
│   ├── ActivationDriver/        # COM activation tool for E2E tests (Windows)
│   ├── local-file-normalization/       # Manual link test sources (Windows)
│   ├── local-file-normalization-linux/ # Manual link test sources (Linux)
│   ├── local-file-normalization-macos/ # Manual link test sources (macOS)
│   └── pwsh/                    # Additional Pester tests
│       ├── BrowserLaunch.Tests.ps1
│       ├── Build.Tests.ps1
│       ├── LinuxModule.Tests.ps1
│       ├── MacModule.Tests.ps1
│       ├── MacBundle.Tests.ps1
│       ├── LocalFileNormalization.Tests.ps1
│       ├── LocalFileNormalizationWithFragments.Tests.ps1
│       ├── SnapBuild.Tests.ps1
│       └── Stage.Tests.ps1
└── dev/
    ├── docs/                    # Developer documentation
    └── scripts/
        └── test/
            ├── Deploy-LinkTests.ps1         # Deploy link tests (Windows)
            ├── Deploy-LinkTests-Linux.ps1   # Deploy link tests (Linux)
            └── Deploy-LinkTests-macOS.ps1   # Deploy link tests (macOS)
```

---

## Building

### Windows: Visual Studio

1. Open `MarkdownViewer.slnx` in Visual Studio 2026
2. Select Build > Build Solution (Ctrl+Shift+B)
3. Projects build to their respective `bin/Debug/` directories

### Windows: Command Line (msbuild)

The Host EXE targets .NET Framework 4.8.1, which requires msbuild (not dotnet CLI):

```powershell
# Launch VS Developer PowerShell first
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
. "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation

# Restore NuGet packages and build entire solution (Debug, default platform)
msbuild MarkdownViewer.slnx /t:Restore
msbuild MarkdownViewer.slnx

# Build for release
msbuild MarkdownViewer.slnx /t:Restore
msbuild MarkdownViewer.slnx /p:Configuration=Release

# Build x64 release (explicit platform)
msbuild MarkdownViewer.slnx /t:Restore /p:Platform=x64
msbuild MarkdownViewer.slnx /p:Configuration=Release /p:Platform=x64
```

**Note:** After cleaning, you must run `/t:Restore` to restore NuGet packages before building. `dotnet build` works for the C# test project but not for the main Host EXE.

### Windows: Build Outputs

| Project | Output Location |
|---------|-----------------|
| MarkdownViewerHost | `src/host/MarkdownViewerHost/bin/<Platform>/Debug/net481/` |
| MarkdownViewerHost.Tests | `tests/MarkdownViewerHost.Tests/bin/Debug/net481/` |
| MSIX Package | `installers/win-msix/output/MarkdownViewer_<version>_<arch>.msix` |

### Linux: Snap Package

The snap packages the engine, a bundled PowerShell runtime, and desktop integration into a single `.snap` file:

```bash
cd installers/linux-snap

# Build for current architecture
./build.sh

# Build for a specific architecture
./build.sh arm64
./build.sh amd64

# Stage files only (skip snapcraft, useful for development)
./build.sh --stage-only
```

**Build flow:**
1. Stages engine files from `src/core/` and `src/linux/` to `staged/`
2. Downloads pinned PowerShell version (cached in `.cache/`)
3. Verifies SHA256 hash
4. Trims the PowerShell bundle to reduce snap size
5. Runs snapcraft to produce the `.snap` file

**Output:** `installers/linux-snap/output/markview_<version>_<arch>.snap`

**Prerequisites:**
- `pwsh` 7+ (for JSON parsing and trimming scripts)
- `snapcraft` (for building the snap package)
- `wget` and `sha256sum` (for downloading and verifying pwsh)

The pinned PowerShell version is configured in `installers/linux-snap/build/pwsh-versions.json`.

### macOS: DMG Package

The macOS package builds `MarkView.app`, bundles a trimmed arm64 PowerShell runtime, ad-hoc signs local developer builds, and creates a DMG:

```bash
cd installers/macos-dmg

# Build app bundle and DMG
./build.sh

# Stage app bundle only, useful for development and tests
./build.sh --stage-only

# Skip runtime trimming while debugging packaging
./build.sh --stage-only --skip-pwsh-trim
```

**Build flow:**
1. Stages engine files from `src/core/` and `src/mac/` into `MarkView.app`
2. Generates `markview.icns`
3. Compiles the Swift/AppKit host from `src/host/MarkdownViewerMacHost/`
4. Downloads pinned PowerShell arm64 archive (cached in `.cache/`)
5. Verifies SHA256 hash
6. Trims and verifies the bundled PowerShell runtime
7. Ad-hoc signs local builds, or Developer ID signs when `MARKVIEW_CODESIGN_IDENTITY` is set
8. Creates `installers/macos-dmg/output/MarkView_<version>_arm64.dmg`

For public distribution, sign with a Developer ID Application identity, then notarize and staple the DMG with `xcrun notarytool` and `xcrun stapler`.

### Cleaning Build Outputs

**Windows:**
```powershell
# Clean all build outputs
.\dev\scripts\Clean-Build.ps1

# Preview what would be cleaned without deleting
.\dev\scripts\Clean-Build.ps1 -WhatIf

# Also remove Visual Studio cache (causes VS reload)
.\dev\scripts\Clean-Build.ps1 -IncludeVsCache
```

**What gets cleaned:**
- `src/host/MarkdownViewerHost/bin/` and `obj/`
- `tests/MarkdownViewerHost.Tests/bin/` and `obj/`
- `tests/ActivationDriver/bin/` and `obj/`
- `installers/win-msix/bin/`, `obj/`, `output/`, `AppPackages/`, `BundleArtifacts/`

**Linux:**
```bash
# Clean snap build artifacts
cd installers/linux-snap
rm -rf staged/ parts/ prime/ stage/ output/ .craft/
```

**macOS:**
```bash
# Clean DMG build artifacts
cd installers/macos-dmg
rm -rf staged/ dmg/root/ output/
```

---

## Running Tests

This project has three levels of tests:

| Test Suite | Framework | Count* | Platform | Purpose |
|------------|-----------|--------|----------|---------|
| Pester | PowerShell | ~480 | All | Engine, module, sanitizer, MSIX/snap/DMG structure |
| xUnit | C#/.NET | ~43 | Windows | Host EXE activation handling |
| E2E MSIX | PowerShell | ~8 | Windows | Full packaged app activation (interactive) |

\* Counts are approximate; platform-specific tests are auto-skipped on the other platform.

### Run All Tests (Windows)

```powershell
# Launch VS Developer PowerShell first (required for msbuild)
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
. "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation

# Run all tests (builds MSIX, runs Pester + xUnit)
.\tests\Invoke-AllTests.ps1

# Skip the build step (if already built)
.\tests\Invoke-AllTests.ps1 -NoBuild

# Include E2E MSIX tests (interactive, requires clicking Install)
.\tests\Invoke-AllTests.ps1 -IncludeE2E
```

**Note:** `Invoke-AllTests.ps1` requires msbuild to build the MSIX package. Run from VS Developer PowerShell.

### Run All Tests (Linux)

On Linux, run Pester directly. There is no `Invoke-AllTests.ps1` wrapper needed since there are no C# or E2E tests on Linux:

```bash
pwsh -NoProfile -Command '
    Import-Module Pester -RequiredVersion 5.7.1 -Force
    Invoke-Pester tests -Output Minimal
'
```

Linux-specific tests include:
- `tests/pwsh/LinuxModule.Tests.ps1` — Linux `MarkdownViewer.psm1` module
- `tests/pwsh/BrowserLaunch.Tests.ps1` — `xdg-open` / `snapctl user-open` browser launch
- `tests/pwsh/SnapBuild.Tests.ps1` — Snap packaging structure and build script
- `tests/pwsh/LocalFileNormalization.ActualBehavior.Tests.ps1` — Linux file normalization

Windows-only tests (auto-skipped on Linux and macOS):
- `tests/pwsh/Build.Tests.ps1`, `Stage.Tests.ps1` — MSIX build/staging
- `tests/pwsh/LocalFileNormalization.Tests.ps1`, `LocalFileNormalizationWithFragments.Tests.ps1` — Windows paths

### Run All Tests (macOS)

On macOS, run Pester directly:

```bash
pwsh -NoProfile -Command '
    Import-Module Pester -RequiredVersion 5.7.1 -Force
    Invoke-Pester tests -Output Minimal
'
```

macOS-specific tests include:
- `tests/pwsh/MacModule.Tests.ps1` — macOS `MarkdownViewer.psm1` module
- `tests/pwsh/MacBundle.Tests.ps1` — app bundle/DMG staging and bundled runtime verification

Linux-only snap tests and Windows-only path/MSIX tests are auto-skipped on macOS.

### PowerShell Tests (Pester)

Tests for the PowerShell engine, module, HTML sanitizer, and packaging structure:

```powershell
# Run ALL Pester tests in the tests directory
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester tests -Output Minimal

# Run with detailed output (useful for debugging failures)
Invoke-Pester tests -Output Detailed

# Run only the main test file
Invoke-Pester tests/MarkdownViewer.Tests.ps1 -Output Minimal

# Run only build/stage tests (includes Linux-specific tests on Linux)
Invoke-Pester tests/pwsh -Output Minimal

# Run only Linux-specific tests
Invoke-Pester tests/pwsh/LinuxModule.Tests.ps1 -Output Minimal
Invoke-Pester tests/pwsh/SnapBuild.Tests.ps1 -Output Minimal

# Run only macOS-specific tests
Invoke-Pester tests/pwsh/MacModule.Tests.ps1 -Output Minimal
Invoke-Pester tests/pwsh/MacBundle.Tests.ps1 -Output Minimal
```

#### Skipped Tests

Some tests are conditionally skipped:

| Condition | Platform | Tests Skipped | How to Run |
|-----------|----------|---------------|------------|
| Not Windows | Linux/macOS | ~80 | Run on Windows |
| Not Linux | Windows/macOS | ~40 | Run on Linux |
| Not macOS | Windows/Linux | ~20 | Run on macOS |
| No staging directory | Windows | ~12 | Run `.\installers\win-msix\build.ps1` first |
| No bundled pwsh | Windows | ~3 | Run build with `-DownloadPwsh` flag |
| No MSIX file | Windows | ~10 | Run build to create MSIX package |

### C# Tests (xUnit) — Windows Only

Tests for the Host EXE activation handling (file activation, protocol activation, path resolution):

```powershell
# Run C# tests via dotnet CLI
dotnet test tests\MarkdownViewerHost.Tests\MarkdownViewerHost.Tests.csproj

# Run with detailed output
dotnet test tests\MarkdownViewerHost.Tests\MarkdownViewerHost.Tests.csproj -v normal
```

**Note:** Running `dotnet test MarkdownViewer.slnx` will show an error about the WAP project not supporting VSTest. This is harmless — the C# tests still run. Use the specific project path to avoid the warning.

### E2E MSIX Activation Tests — Windows Only

Full end-to-end tests that build, install, and activate the MSIX package. These tests require user interaction (clicking "Install" in App Installer):

```powershell
# Run full E2E test (builds MSIX, installs, tests activation)
.\tests\Test-PackagedActivation.ps1

# Skip build if MSIX already exists
.\tests\Test-PackagedActivation.ps1 -SkipBuild

# Keep the package installed after test (for manual testing)
.\tests\Test-PackagedActivation.ps1 -KeepInstalled
```

**What the E2E test does:**
1. Checks for Windows App SDK runtime (warns if present — may mask issues)
2. Builds ActivationDriver.exe (COM-based activation tool)
3. Builds MSIX package via build.ps1
4. Runs staged payload integration test
5. Scans for forbidden runtime dependencies
6. **Installs MSIX** (opens App Installer — **click Install**)
7. Tests protocol, file, and launch activation
8. Uninstalls the package (unless `-KeepInstalled`)

---

## Development Testing

### Testing Changes to the Engine

The easiest way to test engine changes during development:

**Windows:**
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "src\core\Open-Markdown.ps1" -Path "tests\highlight-test.md"
```

**Linux:**
```bash
# Using the launcher script (dev layout)
src/linux/markview tests/highlight-test.md

# Or directly via pwsh
pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path tests/highlight-test.md
```

**macOS:**
```bash
# Using the launcher script (dev layout)
src/mac/markview tests/highlight-test.md

# Or directly via pwsh
pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path tests/highlight-test.md

# Using a staged app bundle
open -a "$PWD/installers/macos-dmg/staged/MarkView.app" "$PWD/tests/highlight-test.md"
```

This opens the rendered markdown in your default browser.

### Testing CSS/JS Changes

CSS and JS changes take effect immediately when you re-run the engine, since they're inlined into the generated HTML. Just run the engine again on any markdown file.

### Testing with Module Changes

If you modify a platform module (`src/win/MarkdownViewer.psm1`, `src/linux/MarkdownViewer.psm1`, or `src/mac/MarkdownViewer.psm1`) or the shared module (`src/core/MarkdownViewer.Shared.psm1`):

```powershell
# Force reimport the module before testing
Import-Module "src/win/MarkdownViewer.psm1" -Force    # Windows
Import-Module "src/linux/MarkdownViewer.psm1" -Force   # Linux
Import-Module "src/mac/MarkdownViewer.psm1" -Force     # macOS

# Then run the engine
pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path tests/highlight-test.md
```

### Manual Local-File Link Test (Windows)

The local-file-normalization test verifies that all variations of markdown links to local files (relative paths, absolute paths, UNC paths, `file://` URLs, paths with spaces, fragment anchors) work correctly when clicked in the browser.

**Test files are in** `tests/local-file-normalization/` but must be deployed to specific locations on disk (e.g. `C:\repo\`, `C:\My Docs\`) because the links use absolute paths.

**Deploy the test files** (run from an **elevated** PowerShell — writes to `C:\`):

```powershell
# Deploy local files (C:\repo\, C:\, C:\My Docs\)
.\dev\scripts\test\Deploy-LinkTests.ps1

# Also deploy to a UNC share (for cases 9-10, 13-14, 18-20)
.\dev\scripts\test\Deploy-LinkTests.ps1 -UncShare '\\myserver\share'
```

**Run the test:**

```powershell
pwsh -NoProfile -File "src\core\Open-Markdown.ps1" -Path "C:\repo\subdir\manual-test.md"
```

Then click each link in the rendered table and verify:
1. Each `[specN]` link opens the correct spec file
2. Each `[fragN]` link (`#section-1`) scrolls to the "section-1" heading
3. Each `[fragNs]` link (`#Section %231`) scrolls to the "Section #1" heading

**Clean up when done:**

```powershell
.\dev\scripts\test\Deploy-LinkTests.ps1 -Clean
```

### Manual Local-File Link Test (Linux)

The Linux version tests the same link patterns minus Windows-only paths (UNC, drive letters). It deploys to `~/markview-test/` (under the user's home directory, since snap strict confinement restricts access to `$HOME`).

**Deploy the test files:**

```bash
pwsh -NoProfile -File dev/scripts/test/Deploy-LinkTests-Linux.ps1
```

**Run the test:**

```bash
pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path "$HOME/markview-test/repo/subdir/manual-test.md"
```

**Test cases covered (9 total):**
- Case 1: Relative path (`docs/spec1.md`)
- Case 2: Parent traversal (`../docs/spec3.md`)
- Cases 3-4: Linux absolute paths (`~/markview-test/spec5.md`, with `%20`-encoded spaces)
- Cases 5-7: `file:///` URLs with plain path, spaces, and `%20`-encoded spaces

Then click each link and verify file opens + fragment scrolling works.

**Clean up when done:**

```bash
pwsh -NoProfile -File dev/scripts/test/Deploy-LinkTests-Linux.ps1 -Clean
```

### Manual Local-File Link Test (macOS)

The macOS version tests the same POSIX link patterns as Linux: relative paths, parent traversal, absolute paths, `file:///` URLs, paths with spaces, encoded spaces, and fragment anchors. Windows-only forms such as drive letters and UNC paths are intentionally omitted.

It deploys to `~/markview-test/`, matching normal macOS user-writable locations.

**Deploy the test files:**

```bash
pwsh -NoProfile -File dev/scripts/test/Deploy-LinkTests-macOS.ps1
```

**Run the test from source:**

```bash
pwsh -NoProfile -File src/core/Open-Markdown.ps1 -Path "$HOME/markview-test/repo/subdir/manual-test.md"
```

**Run the test with the staged app bundle:**

```bash
open -a "$PWD/installers/macos-dmg/staged/MarkView.app" "$HOME/markview-test/repo/subdir/manual-test.md"
```

**Test cases covered (7 total):**
- Case 1: Relative path (`docs/spec1.md`)
- Case 2: Parent traversal (`../docs/spec3.md`)
- Cases 3-4: macOS absolute paths (`~/markview-test/spec5.md`, with `%20`-encoded spaces)
- Cases 5-7: `file:///` URLs with plain path, spaces, and `%20`-encoded spaces

Then click each link and verify file opens + fragment scrolling works.

**Clean up when done:**

```bash
pwsh -NoProfile -File dev/scripts/test/Deploy-LinkTests-macOS.ps1 -Clean
```

### Testing the Installed MSIX (Windows)

After building and installing the MSIX package:

```powershell
# Open a markdown file via the registered file association
Start-Process "C:\path\to\your\file.md"

# Or use the protocol handler
Start-Process "mdview:file:///C:/path/to/doc.md"
```

You can also right-click any `.md` file in Explorer and select "Open with > Markdown Viewer".

### Testing the Installed Snap (Linux)

After building and installing the snap:

```bash
# Install the locally-built snap
sudo snap install installers/linux-snap/output/markview_1.0.1_arm64.snap --dangerous

# Open a markdown file
markview tests/highlight-test.md

# Test the protocol handler (via xdg-open)
xdg-open "mdview:file:///home/$USER/path/to/doc.md"

# Verify linked-file navigation works (opens a .md with links to other .md files)
markview tests/test-toc-links.md

# Uninstall when done
sudo snap remove markview
```

**Snap confinement notes:**
- The snap uses **strict** confinement and can only access files under `$HOME`
- Output HTML files are written to `~/MarkView/` (not `/tmp/`) so browsers can access them
- Browser launch uses `snapctl user-open` (propagates through XDG Desktop Portal)
- The portal can strip fragment/query state from launched `file:` URLs, so the engine embeds `scrollTarget` directly in the HTML config object as the primary scroll target

### Testing the Installed DMG (macOS)

After building the DMG:

```bash
# Mount and install manually, or open the DMG in Finder
open installers/macos-dmg/output/MarkView_1.2.0_arm64.dmg

# Smoke-test the staged app bundle before copying to Applications
open -a "$PWD/installers/macos-dmg/staged/MarkView.app" "$PWD/README.md"

# Test the native host directly with an absolute file path
installers/macos-dmg/staged/MarkView.app/Contents/MacOS/MarkViewHost "$PWD/README.md"

# Test the protocol handler after the app has been installed/registered
open "mdview:file://$PWD/README.md"
```

Generated HTML is written to `~/Library/Caches/MarkView`.

---

## Creating Installers

### Ad-hoc Installer — Windows

The ad-hoc installer copies files to `%LOCALAPPDATA%\Programs\MarkdownViewer` and registers file associations.

```powershell
# Install
.\installers\win-adhoc\install.ps1

# Or double-click INSTALL.cmd

# Uninstall
.\installers\win-adhoc\uninstall.ps1

# Or double-click UNINSTALL.cmd
```

### MSIX Package — Windows

The MSIX package bundles the Host EXE, PowerShell runtime, and engine files. There are two build methods:

#### Method 1: WAP Project (MSBuild) — Recommended

This is the preferred method using the Windows Application Packaging (WAP) project:

```powershell
# Prerequisites: Visual Studio 2026 with Desktop Bridge workload
# Launch Developer PowerShell first:
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
. "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation

# Build x64 Release
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release

# Build ARM64 Release
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=ARM64 /p:Configuration=Release

# Build with signing enabled
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /p:SignMsix=true

# Skip bundling pwsh (for faster dev builds)
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /p:SkipPwsh=true
```

**WAP Build Flow:**
1. MSBuild builds `MarkdownViewerHost.csproj` via project reference
2. `Directory.Build.targets` invokes `stage.ps1` to compose the payload
3. `stage.ps1` downloads pwsh (if not cached), copies engine files, generates assets
4. WAP packages the staged content into MSIX

**MSBuild Properties:**

| Property | Description |
|----------|-------------|
| `/p:Platform=x64\|ARM64` | Target architecture (required) |
| `/p:Configuration=Debug\|Release` | Build configuration (default: Debug) |
| `/p:SkipPwsh=true` | Skip bundling PowerShell runtime |
| `/p:SkipPwshTrim=true` | Skip trimming bundled pwsh (keeps full size) |
| `/p:PwshTrimLevel=None\|Level1\|Level2\|Level3\|All` | Trimming level (default: All) |
| `/p:ForceRegenAssets=true` | Force regenerate PNG assets from ICO |
| `/p:SignMsix=true` | Sign package after build |

#### PowerShell Bundle Trimming

Both the Windows MSIX and Linux snap trim the bundled PowerShell runtime to reduce package size. Trimming removes unused components (locales, WPF, Roslyn, diagnostics, etc.) while preserving modules needed for Markdown viewing.

**Typical size reduction:** ~48% (278 MB → 143 MB for x64)

**Disabling Trimming (Windows):**

```powershell
# Skip all trimming
msbuild ... /p:SkipPwshTrim=true

# Apply only Level 1 trimming (safest)
msbuild ... /p:PwshTrimLevel=Level1
```

**Output:** `installers\win-msix\AppPackages\MarkdownViewer_<version>_<arch>_Test\MarkdownViewer_<version>_<arch>.msix`

**Prerequisites for WAP Build:**
- Visual Studio 2026 with "Windows Application Packaging Project" workload
- .NET Framework 4.8.1 (pre-installed on Windows 11)
- ImageMagick (optional, for asset generation from ICO — falls back to solid-color placeholders)

#### Method 2: build.ps1 (Legacy)

The standalone PowerShell script for environments without Visual Studio:

```powershell
# Build MSIX package (single architecture, uses system pwsh)
.\installers\win-msix\build.ps1

# Full production build: both architectures, bundle, pinned pwsh, signed
.\installers\win-msix\build.ps1 -Bundle -DownloadPwsh -Sign
```

| Parameter | Description |
|-----------|-------------|
| `-Configuration` | `Debug` or `Release` (default: Release) |
| `-Architecture` | `x64` or `arm64` (default: x64, ignored with -BuildAll) |
| `-Version` | Package version (default: read from csproj) |
| `-SkipBuild` | Don't rebuild Host EXE |
| `-SkipPwsh` | Don't bundle PowerShell runtime |
| `-BuildAll` | Build both x64 and ARM64 packages |
| `-Bundle` | Create .msixbundle (implies -BuildAll) |
| `-Sign` | Sign package(s) after build using sign.ps1 |
| `-DownloadPwsh` | Download pinned PowerShell version instead of using system pwsh |

### Signing MSIX Packages

The MSIX is unsigned by default. Use `sign.ps1` for dev signing:

```powershell
# Create certificate and sign a package
.\installers\win-msix\sign.ps1 -MsixPath ".\output\MarkdownViewer_1.0.1.0_x64.msix" -Sign

# Create certificate only (to be used later)
.\installers\win-msix\sign.ps1 -CreateCertOnly
```

| Parameter | Description |
|-----------|-------------|
| `-MsixPath` | Path to MSIX file to sign |
| `-Sign` | Actually perform signing |
| `-CertSubject` | Certificate subject (default: CN=MarkdownViewerDev) |
| `-CreateCertOnly` | Only create certificate, don't sign |

### Installing the MSIX (Sideload)

The MSIX is unsigned by default, so you need either:

1. **Developer Mode** (Settings > For Developers > Developer Mode) — then double-click the .msix file
2. **Signed package** using sign.ps1 (`.\installers\win-msix\build.ps1 -Sign`)

### Snap Package — Linux

Build the snap with the included build script:

```bash
cd installers/linux-snap

# Build for current architecture
./build.sh

# Build for a specific architecture
./build.sh arm64

# Stage only (for inspection without running snapcraft)
./build.sh --stage-only
```

**Snap structure (after staging):**
```
staged/
├── bin/markview             # Bash launcher
├── app/                     # Engine payload
│   ├── Open-Markdown.ps1
│   ├── MarkdownViewer.psm1  # Linux platform module
│   ├── MarkdownViewer.Shared.psm1
│   ├── script.js
│   ├── style.css
│   ├── highlight.min.js
│   ├── highlight-theme.css
│   └── markdown.ico
├── pwsh/                    # Bundled & trimmed PowerShell 7
│   ├── pwsh
│   └── ...
└── meta/gui/
    ├── markview.desktop
    └── markview.png
```

**Install locally-built snap:**
```bash
sudo snap install output/markview_1.0.1_arm64.snap --dangerous
```

**Updating the pinned PowerShell version:**
1. Edit `installers/linux-snap/build/pwsh-versions.json` with new version and URLs
2. Get SHA256 hashes from the [PowerShell GitHub release page](https://github.com/PowerShell/PowerShell/releases)
3. Update the `sha256` values in the config file
4. Downloads are cached in `installers/linux-snap/.cache/`

### DMG Package — macOS

Build the macOS DMG with the included build script:

```bash
cd installers/macos-dmg

# Build the arm64 DMG
./build.sh

# Stage only, useful for tests and inspection
./build.sh --stage-only
```

**App bundle structure (after staging):**
```
staged/MarkView.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/MarkViewHost
    └── Resources/
        ├── app/                  # Engine payload + macOS platform module
        ├── pwsh/                 # Bundled & trimmed PowerShell 7
        └── markview.icns
```

**Developer ID signing and notarization:**

```bash
# Build with Developer ID signing
MARKVIEW_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh

# Submit the DMG to Apple notarization
xcrun notarytool submit output/MarkView_1.2.0_arm64.dmg --keychain-profile markview-notary --wait
xcrun stapler staple output/MarkView_1.2.0_arm64.dmg
```

**Updating the pinned PowerShell version:**
1. Edit `installers/macos-dmg/build/pwsh-versions.json` with the new arm64 macOS archive URL
2. Get SHA256 hashes from the [PowerShell GitHub release page](https://github.com/PowerShell/PowerShell/releases)
3. Update the `sha256` value in the config file
4. Downloads are cached in `installers/macos-dmg/.cache/`

---

## Debugging

### Debugging the Engine

Add `-Debug` or `Write-Host` statements to `Open-Markdown.ps1`:

```powershell
# Add at top of script
$DebugPreference = 'Continue'

# Then use
Write-Debug "Variable value: $variable"
```

### Debugging the Host EXE (Windows)

1. Set `MarkdownViewerHost` as startup project in Visual Studio
2. Add command-line arguments in Project Properties > Debug:
   - Arguments: `C:\path\to\test.md`
3. Set breakpoints and press F5

### Debugging the Mac Host (macOS)

The macOS host is a small Swift/AppKit executable:

```bash
# Compile just the host
swiftc src/host/MarkdownViewerMacHost/MarkViewHost.swift \
    -o /tmp/MarkViewHost \
    -framework AppKit \
    -framework Foundation

# Build the full app bundle and test host activation
installers/macos-dmg/build.sh --stage-only
installers/macos-dmg/staged/MarkView.app/Contents/MacOS/MarkViewHost "$PWD/README.md"
```

Host errors are shown with `NSAlert`. Engine errors are shown by the PowerShell macOS platform module through `osascript` dialogs.

### Viewing Generated HTML

The engine writes temporary HTML files:
- **Windows:** `%TEMP%\viewmd_<name>_<hash>.html`
- **Linux:** `~/MarkView/viewmd_<name>_<hash>.html`
- **macOS:** `~/Library/Caches/MarkView/viewmd_<name>_<hash>.html`

The `_remote.html` variant is created when the document has remote images and the user enables them.

Open these in a text editor to inspect the generated HTML.

---

## Common Development Tasks

### Bumping the Version

The canonical version is the `<Version>` property in `src/host/MarkdownViewerHost/MarkdownViewerHost.csproj` (3-part, e.g. `1.0.1`). All other version references are derived from it.

**Version scheme:**
- **3-part** (`1.0.1`): canonical `<Version>`, `snapcraft.yaml`
- **4-part** (`1.0.1.0`): MSIX identity, assembly, filenames (appends `.0`)

**Steps:**

1. Edit the `<Version>` element in `src/host/MarkdownViewerHost/MarkdownViewerHost.csproj`
2. Run the consistency script with `-Fix` to propagate to all derived files:
   ```powershell
   .\dev\scripts\Test-VersionConsistency.ps1 -Fix
   ```
3. Verify everything is consistent:
   ```powershell
   .\dev\scripts\Test-VersionConsistency.ps1
   ```

**Files checked/updated by the script:**

| File | Property | Format |
|------|----------|--------|
| `MarkdownViewerHost.csproj` | `<FileVersion>`, `<AssemblyVersion>` | 4-part |
| `Package.appxmanifest` | `<Identity Version>` | 4-part |
| `MarkdownViewer.wapproj` | `<PackageVersion>` | 4-part |
| `build.ps1` | `-Version` default | 4-part |
| `snapcraft.yaml` | `version` | 3-part |
| `installers/macos-dmg/build.sh` | derived from csproj | 3-part |
| `Test-PackagedActivation.ps1` | `-Version` default | 4-part |
| `Invoke-AllTests.ps1` | MSIX filename pattern | 4-part |
| `MarkdownViewer.Tests.ps1` | MSIX filename pattern | 4-part |

**Not app versions:** `markview.desktop` `Version=1.0` is the Desktop Entry spec version, and `pwsh-versions.json` is the bundled PowerShell runtime version — neither should be changed during a version bump.

### Adding a New Language Alias for Syntax Highlighting

Edit `src/core/script.js` and add to the `LANG_MAP` object:

```javascript
const LANG_MAP = {
    // ...existing mappings...
    'newlang': 'existinglang',  // Add your alias
};
```

### Modifying the HTML Sanitizer

Edit the shared module `src/core/MarkdownViewer.Shared.psm1`, function `Invoke-HtmlSanitization`, or a platform-specific module if the change is platform-specific.

**Important:** Add corresponding tests in `tests/MarkdownViewer.Tests.ps1`.

### Adding a New Theme Variation

1. Edit `src/core/style.css` — Add new `[data-theme="..."][data-variation="N"]` rules
2. Edit `src/core/script.js` — Add variation name to `lightNames` or `darkNames` array

### Updating highlight.js

1. Download new bundle from https://highlightjs.org/download/
2. Replace `src/core/highlight.min.js`
3. Update `src/core/highlight-theme.css` if theme changed
4. Run tests to verify

### Changing the App Name

**Files to update:**

1. `installers/win-msix/Package.appxmanifest` — `<DisplayName>` and `<uap:VisualElements DisplayName>`
2. `src/host/MarkdownViewerHost/MarkdownViewerHost.csproj` — `<Product>`
3. `src/core/Open-Markdown.ps1` — User-facing strings
4. `src/host/MarkdownViewerHost/Program.cs` — TaskDialog caption
5. `installers/linux-snap/snap/snapcraft.yaml` — `name`, `title`
6. `src/host/MarkdownViewerMacHost/Info.plist.template` — `CFBundleDisplayName`, `CFBundleName`

---

## Troubleshooting

### Windows Troubleshooting

**"ConvertFrom-Markdown not found"** — Ensure you're using PowerShell 7+, not Windows PowerShell 5.1:
```powershell
$PSVersionTable.PSVersion  # Should be 7.x
```

**Tests fail with "Module not found"** — Ensure paths are correct:
```powershell
Test-Path "src\win\MarkdownViewer.psm1"
```

**MSIX build fails with "makeappx.exe not found"** — Install Windows 10 SDK:
```powershell
winget install Microsoft.WindowsSDK.10.0.22621
```

**Solution doesn't build in Visual Studio** — Close VS, delete `bin/`, `obj/`, `.vs/` folders, reopen and rebuild.

### Linux Troubleshooting

**"ConvertFrom-Markdown not found"** — Ensure you have PowerShell 7+:
```bash
pwsh --version  # Should be 7.x
```

**`xdg-open` doesn't open the browser** — Check that a default browser is configured:
```bash
xdg-settings get default-web-browser
```

**Snap can't access files outside `$HOME`** — The snap uses strict confinement and can only read files under your home directory. Copy the file to `~/` first.

**Fragment scrolling doesn't work in snap** — The XDG Desktop Portal can strip fragment/query state from launched `file:` URLs. The engine embeds `scrollTarget` directly in the HTML config object as the primary scroll target. If scrolling still fails, check that `window.mdviewer_config.scrollTarget` is being set correctly in the generated HTML.

**`snapcraft` fails with architecture mismatch** — Ensure you're building for the correct platform:
```bash
./build.sh arm64   # or amd64
```

**Pester tests skip with "Windows-only"** — This is expected. Tests gated with `if (-not $IsWindows) { return }` skip on Linux and macOS. Run on Windows to execute those tests.

### macOS Troubleshooting

**"ConvertFrom-Markdown not found"** — Ensure you have PowerShell 7+ for source runs:
```bash
pwsh --version
```

**DMG build fails with missing Xcode tools** — Install Xcode Command Line Tools:
```bash
xcode-select --install
```

**Bundled PowerShell verification fails after trimming** — Rebuild without trimming to isolate the issue:
```bash
installers/macos-dmg/build.sh --stage-only --skip-pwsh-trim
```

**App opens but no rendered file appears** — Check `~/Library/Caches/MarkView` and run the host directly with an absolute path:
```bash
installers/macos-dmg/staged/MarkView.app/Contents/MacOS/MarkViewHost "$PWD/README.md"
```

**Gatekeeper blocks a downloaded DMG** — Public releases must be signed with Developer ID and notarized. Local developer builds are only ad-hoc signed.

---

## Code Style

- **PowerShell:** Follow existing patterns, use `$ErrorActionPreference = 'Stop'`
- **C#:** Follow .NET conventions, nullable enabled
- **Swift:** Keep the macOS host small and use structured `Process` arguments
- **JavaScript:** No framework, vanilla JS with IIFEs for isolation
- **CSS:** CSS custom properties for theming
- **Bash:** `set -e`, POSIX-compatible where possible

---

## Contributing

1. Create a feature branch
2. Make changes
3. Run all tests (Pester on your platform + xUnit on Windows)
4. Update documentation if needed
5. Submit pull request
