# Markdown Viewer Developer Guide

This guide covers building, testing, and developing Markdown Viewer on both Windows and Linux.

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Windows Prerequisites](#windows-prerequisites)
  - [Linux Prerequisites](#linux-prerequisites)
  - [Installing Pester](#installing-pester)
- [Project Structure](#project-structure)
- [Building](#building)
  - [Windows: Visual Studio](#windows-visual-studio)
  - [Windows: Command Line (msbuild)](#windows-command-line-msbuild)
  - [Windows: Build Outputs](#windows-build-outputs)
  - [Linux: Snap Package](#linux-snap-package)
  - [Cleaning Build Outputs](#cleaning-build-outputs)
- [Running Tests](#running-tests)
  - [Run All Tests (Windows)](#run-all-tests-windows)
  - [Run All Tests (Linux)](#run-all-tests-linux)
  - [PowerShell Tests (Pester)](#powershell-tests-pester)
  - [C# Tests (xUnit) — Windows Only](#c-tests-xunit--windows-only)
  - [E2E MSIX Activation Tests — Windows Only](#e2e-msix-activation-tests--windows-only)
- [Development Testing](#development-testing)
  - [Testing Changes to the Engine](#testing-changes-to-the-engine)
  - [Testing CSS/JS Changes](#testing-cssjs-changes)
  - [Testing with Module Changes](#testing-with-module-changes)
  - [Manual Local-File Link Test (Windows)](#manual-local-file-link-test-windows)
  - [Manual Local-File Link Test (Linux)](#manual-local-file-link-test-linux)
  - [Testing the Installed MSIX (Windows)](#testing-the-installed-msix-windows)
  - [Testing the Installed Snap (Linux)](#testing-the-installed-snap-linux)
- [Creating Installers](#creating-installers)
  - [Ad-hoc Installer — Windows](#ad-hoc-installer--windows)
  - [MSIX Package — Windows](#msix-package--windows)
  - [Signing MSIX Packages](#signing-msix-packages)
  - [Installing the MSIX (Sideload)](#installing-the-msix-sideload)
  - [Snap Package — Linux](#snap-package--linux)
- [Debugging](#debugging)
  - [Debugging the Engine](#debugging-the-engine)
  - [Debugging the Host EXE (Windows)](#debugging-the-host-exe-windows)
  - [Viewing Generated HTML](#viewing-generated-html)
- [Common Development Tasks](#common-development-tasks)
  - [Bumping the Version](#bumping-the-version)
- [Troubleshooting](#troubleshooting)
  - [Windows Troubleshooting](#windows-troubleshooting)
  - [Linux Troubleshooting](#linux-troubleshooting)
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

### Installing Pester

Pester 5.x is required for PowerShell tests on both platforms. The system may have Pester 3.x pre-installed; always import explicitly:

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
│   └── host/                    # MSIX Host EXE (Windows only)
│       └── MarkdownViewerHost/  # .NET Framework 4.8.1 WinForms project
├── installers/
│   ├── win-adhoc/               # Per-user ad-hoc installer (Windows)
│   ├── win-msix/                # MSIX packaging (Windows)
│   └── linux-snap/              # Snap packaging (Linux)
│       ├── snap/snapcraft.yaml  # Snap definition
│       ├── build.sh             # Stage + trim + build snap
│       └── scripts/             # Trimming & verification scripts
├── tests/
│   ├── Invoke-AllTests.ps1      # Run all tests at once (Windows)
│   ├── MarkdownViewer.Tests.ps1 # Pester tests (engine, module, MSIX structure)
│   ├── Test-PackagedActivation.ps1  # E2E MSIX activation tests (Windows)
│   ├── Test-StagedPayload.ps1   # Staged payload integration tests (Windows)
│   ├── MarkdownViewerHost.Tests/# xUnit tests — C# host (Windows)
│   ├── ActivationDriver/        # COM activation tool for E2E tests (Windows)
│   ├── local-file-normalization/       # Manual link test sources (Windows)
│   ├── local-file-normalization-linux/ # Manual link test sources (Linux)
│   └── pwsh/                    # Additional Pester tests
│       ├── BrowserLaunch.Tests.ps1
│       ├── Build.Tests.ps1
│       ├── LinuxModule.Tests.ps1
│       ├── LocalFileNormalization.Tests.ps1
│       ├── LocalFileNormalizationWithFragments.Tests.ps1
│       ├── SnapBuild.Tests.ps1
│       └── Stage.Tests.ps1
└── dev/
    ├── docs/                    # Developer documentation
    └── scripts/
        └── test/
            ├── Deploy-LinkTests.ps1         # Deploy link tests (Windows)
            └── Deploy-LinkTests-Linux.ps1   # Deploy link tests (Linux)
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

---

## Running Tests

This project has three levels of tests:

| Test Suite | Framework | Count* | Platform | Purpose |
|------------|-----------|--------|----------|---------|
| Pester | PowerShell | ~460 | Both | Engine, module, sanitizer, MSIX/snap structure |
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

Windows-only tests (auto-skipped on Linux):
- `tests/pwsh/Build.Tests.ps1`, `Stage.Tests.ps1` — MSIX build/staging
- `tests/pwsh/LocalFileNormalization.Tests.ps1`, `LocalFileNormalizationWithFragments.Tests.ps1` — Windows paths

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
```

#### Skipped Tests

Some tests are conditionally skipped:

| Condition | Platform | Tests Skipped | How to Run |
|-----------|----------|---------------|------------|
| Not Windows | Linux | ~80 | Run on Windows |
| Not Linux | Windows | ~40 | Run on Linux |
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

This opens the rendered markdown in your default browser.

### Testing CSS/JS Changes

CSS and JS changes take effect immediately when you re-run the engine, since they're inlined into the generated HTML. Just run the engine again on any markdown file.

### Testing with Module Changes

If you modify a platform module (`src/win/MarkdownViewer.psm1` or `src/linux/MarkdownViewer.psm1`) or the shared module (`src/core/MarkdownViewer.Shared.psm1`):

```powershell
# Force reimport the module before testing
Import-Module "src/win/MarkdownViewer.psm1" -Force    # Windows
Import-Module "src/linux/MarkdownViewer.psm1" -Force   # Linux

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
- The portal strips `#fragment` and `?query` from `file:` URLs, which is why the `_fragment` contract embeds `scrollTarget` directly in the HTML config object

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

### Viewing Generated HTML

The engine writes temporary HTML files:
- **Windows:** `%TEMP%\viewmd_<name>_<hash>.html`
- **Linux:** `~/MarkView/viewmd_<name>_<hash>.html`

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

**Fragment scrolling doesn't work in snap** — The XDG Desktop Portal strips query parameters from `file:` URLs. The engine embeds `scrollTarget` directly in the HTML config object as a workaround. If scrolling still fails, check that the `window.mdviewer_config.scrollTarget` is being set correctly in the generated HTML.

**`snapcraft` fails with architecture mismatch** — Ensure you're building for the correct platform:
```bash
./build.sh arm64   # or amd64
```

**Pester tests skip with "Windows-only"** — This is expected. Tests gated with `if (-not $IsWindows) { return }` skip on Linux. Run on Windows to execute those tests.

---

## Code Style

- **PowerShell:** Follow existing patterns, use `$ErrorActionPreference = 'Stop'`
- **C#:** Follow .NET conventions, nullable enabled
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
