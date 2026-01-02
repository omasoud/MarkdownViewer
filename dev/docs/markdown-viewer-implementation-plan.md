# Markdown Viewer Implementation Plan

## Overview

This document outlines the implementation plan for Markdown Viewer features:
- **Phase A (Complete):** highlight.js syntax highlighting integration
- **Phase B (Complete):** MSIX packaging and Host launcher for Microsoft Store distribution
- **Phase C (Current):** Enhancement of MSIX Packaging and Host Launcher

**Key Documents:**
- [markdown-viewer-architecture.md](markdown-viewer-architecture.md) - Architecture overview
- [msix-packaging-and-host-launcher-specification.md](msix-packaging-and-host-launcher-specification.md) - MSIX tech spec
- [msix-activation-matrix.md](msix-activation-matrix.md) - Activation behavior contract
- [msix-project-additional-feedback.md](msix-project-additional-feedback.md) - Phase C requirements

---

# Phase A: highlight.js Integration (Complete)

## A.1 Asset Preparation

### A.1.1 Generate Combined Theme CSS

**File:** `payload/highlight-theme.css` (new)

- [x] A.1.1.1 Copy `dev/scripts/highlight-theme-tomorrow.css` to `payload/highlight-theme.css`
- [x] A.1.1.2 Verify CSS contains reset block with `background: transparent`
- [x] A.1.1.3 Verify CSS contains `:root[data-theme="light"]` scoped rules
- [x] A.1.1.4 Verify CSS contains `:root[data-theme="dark"]` scoped rules

### A.1.2 Prepare highlight.js Bundle

**File:** `payload/highlight.min.js` (new)

- [x] A.1.2.1 Copy `dev/scripts/highlight.min.js` to `payload/highlight.min.js`
- [x] A.1.2.2 Verify bundle is UMD build (defines `window.hljs`)

---

## A.2 CSP and HTML Infrastructure

### A.2.1 Update CSP Generation

**File:** `payload/Open-Markdown.ps1`

- [x] A.2.1.1 Add `file:` to `style-src` directive
- [x] A.2.1.2 Add `file:` to `script-src` directive
- [x] A.2.1.3 Add comment documenting security tradeoff

### A.2.2 Add Asset Path Handling

- [x] A.2.2.1 Add `$HighlightJsPath` variable
- [x] A.2.2.2 Add `$HighlightThemePath` variable
- [x] A.2.2.3 Generate `file:///` URLs for both assets
- [x] A.2.2.4 Check if asset files exist before including references

### A.2.3 Update HTML Template

- [x] A.2.3.1 Add `<link>` for highlight-theme.css
- [x] A.2.3.2 Add `<script defer>` for highlight.min.js
- [x] A.2.3.3 Only include if both files exist
- [x] A.2.3.4 Ensure NO query strings on asset URLs

---

## A.3 JavaScript Highlighting Module

### A.3.1 Create Highlighting IIFE

**File:** `payload/script.js`

- [x] A.3.1.1 Add configuration constants: `MAX_BLOCK_SIZE`, `MAX_BLOCKS`
- [x] A.3.1.2 Add `LANG_MAP` object with all alias mappings
- [x] A.3.1.3 Add guard for `hljs` undefined
- [x] A.3.1.4 Add `highlighted` flag to prevent re-execution

### A.3.2 Helper Functions

- [x] A.3.2.1 Implement `getLanguageClass(codeEl)`
- [x] A.3.2.2 Implement `normalizeLanguage(lang)`
- [x] A.3.2.3 Implement `shouldHighlight(codeEl)`
- [x] A.3.2.4 Implement `highlightBlock(codeEl)`

### A.3.3 Main Function

- [x] A.3.3.1 Implement `runHighlighting()`
- [x] A.3.3.2 Use selector `'pre code[class*="language-"], pre code[class*="lang-"]'`
- [x] A.3.3.3 Add console.debug for highlighting summary
- [x] A.3.3.4 Add console.warn when block count exceeds MAX_BLOCKS
- [x] A.3.3.5 Handle DOMContentLoaded vs already-loaded document

---

## A.4 Installer/Uninstaller Updates

### A.4.1 Update Installer

**File:** `install.ps1`

- [x] A.4.1.1 Add `Copy-Item` for `highlight.min.js`
- [x] A.4.1.2 Add `Copy-Item` for `highlight-theme.css`
- [x] A.4.1.3 Add both files to `$files` array in `Set-ReadOnlyAcl`

### A.4.2 Update Uninstaller

- [x] A.4.2.1 Verify existing `Remove-Item -Recurse` removes all files

---

## A.5 Unit Tests

**File:** `tests/MarkdownViewer.Tests.ps1`

- [x] A.5.1.1 Test: CSP includes `file:` in script-src
- [x] A.5.1.2 Test: CSP includes `file:` in style-src
- [x] A.5.1.3 Test: CSP does NOT contain `https:` in script-src
- [x] A.5.1.4 Test: CSP does NOT contain `'unsafe-inline'` in script-src
- [x] A.5.2.1 Test: highlight.min.js exists
- [x] A.5.2.2 Test: highlight-theme.css exists
- [x] A.5.2.3 Test: highlight-theme.css contains transparent background
- [x] A.5.2.4 Test: highlight-theme.css contains light mode rules
- [x] A.5.2.5 Test: highlight-theme.css contains dark mode rules
- [x] A.5.3.1 Test: script.js contains `LANG_MAP`
- [x] A.5.3.2 Test: script.js contains hljs undefined guard
- [x] A.5.3.3 Test: script.js contains `MAX_BLOCK_SIZE` (102400)
- [x] A.5.3.4 Test: script.js contains `MAX_BLOCKS` (500)
- [x] A.5.3.5 Test: script.js does NOT contain `highlightAuto`
- [x] A.5.3.6-10 Test: LANG_MAP language alias mappings
- [x] A.5.4.1-2 Test: installer copies highlight assets

---

## A.6 Documentation Updates

- [x] A.6.1.1 Update README.md with syntax highlighting section
- [x] A.6.2.1-5 Update architecture documentation

---

# Phase B: MSIX Packaging and Host Launcher

## B.1 Repository Structure Reorganization

**Goal:** Separate cross-platform engine from Windows-specific launchers and installers.

**Status: COMPLETE**

### B.1.1 Create Source Directory Structure

- [x] B.1.1.1 Create `src/core/` directory
- [x] B.1.1.2 Create `src/core/icons/` directory
- [x] B.1.1.3 Create `src/win/` directory
- [x] B.1.1.4 Create `src/host/MarkdownViewerHost/` directory

### B.1.2 Move Core Engine Files

- [x] B.1.2.1 Move `payload/Open-Markdown.ps1` → `src/core/Open-Markdown.ps1`
- [x] B.1.2.2 Move `payload/script.js` → `src/core/script.js`
- [x] B.1.2.3 Move `payload/style.css` → `src/core/style.css`
- [x] B.1.2.4 Move `payload/highlight.min.js` → `src/core/highlight.min.js`
- [x] B.1.2.5 Move `payload/highlight-theme.css` → `src/core/highlight-theme.css`
- [x] B.1.2.6 Move icon → `src/core/icons/markdown.ico`
- [x] B.1.2.7 Copy icon also as `src/core/icons/markdown-light.ico`

### B.1.3 Move Windows-Specific Files

- [x] B.1.3.1 Move `payload/MarkdownViewer.psm1` → `src/win/MarkdownViewer.psm1`
- [x] B.1.3.2 Move `payload/viewmd.vbs` → `src/win/viewmd.vbs`
- [x] B.1.3.3 Move `uninstall.vbs` → `src/win/uninstall.vbs`

### B.1.4 Create Installer Directories

- [x] B.1.4.1 Create `installers/win-adhoc/` directory
- [x] B.1.4.2 Create `installers/win-msix/` directory
- [x] B.1.4.3 Create `installers/win-msix/Package/` directory
- [x] B.1.4.4 Create `installers/win-msix/Package/Assets/` directory

### B.1.5 Move Installer Files

- [x] B.1.5.1 Copy `INSTALL.cmd` → `installers/win-adhoc/INSTALL.cmd`
- [x] B.1.5.2 Copy `UNINSTALL.cmd` → `installers/win-adhoc/UNINSTALL.cmd`
- [x] B.1.5.3 Copy `install.ps1` → `installers/win-adhoc/install.ps1`
- [x] B.1.5.4 Copy `uninstall.ps1` → `installers/win-adhoc/uninstall.ps1`

### B.1.6 Update Installer Paths

- [x] B.1.6.1 Update `install.ps1` to reference `src/core/` for engine files
- [x] B.1.6.2 Update `install.ps1` to reference `src/win/` for Windows files
- [x] B.1.6.3 Update `uninstall.ps1` paths (added $NoWait parameter)
- [x] B.1.6.4 Update `INSTALL.cmd` to use relative path to `install.ps1`
- [x] B.1.6.5 Update `UNINSTALL.cmd` to use relative path to `uninstall.ps1`

### B.1.7 Clean Up Legacy Files

- [ ] B.1.7.1 Remove `payload/` directory after migration (manual step)
- [ ] B.1.7.2 Remove root-level installer files (manual step)
- [ ] B.1.7.3 Remove root-level `Program.cs` (manual step)
- [ ] B.1.7.4 Remove root-level `MDViewer.csproj` (manual step)

> **Note:** Legacy files at root still exist for reference. Remove them manually when ready to finalize migration.

---

## B.2 Host Application Development

**Status: COMPLETE (Simplified)**

### B.2.1 Create Host Project

- [x] B.2.1.1 Create `MarkdownViewerHost.csproj` with:
  - OutputType: WinExe (GUI subsystem, no console)
  - TargetFramework: net10.0-windows10.0.19041.0
  - Simplified to avoid Windows App SDK Pri generation issues

### B.2.2 Implement Activation Handler

- [x] B.2.2.1 Implement `Main()` entry point
- [x] B.2.2.2 Handle command-line args (Windows passes file/protocol as args)
- [x] B.2.2.3 Process each argument (supports multi-file)

### B.2.3-B.2.5 Implement Path Normalization and Process Launcher

- [x] B.2.3.1-B.2.5.3 All implemented in `LaunchEngine()` method:
  - Paths passed unchanged (Engine owns parsing)
  - Uses `ProcessStartInfo.ArgumentList` (structured, no concatenation)
  - `UseShellExecute = false`, `CreateNoWindow = true`
  - Exits immediately after launch

### B.2.6 Error Handling

- [x] B.2.6.1-3 Errors caught silently, Engine owns user-facing dialogs

---

## B.3 MSIX Package Definition

**Status: COMPLETE**

### B.3.1 Create AppxManifest.xml

- [x] B.3.1.1-6 All implemented in `installers/win-msix/Package/AppxManifest.xml`:
  - Package Identity with placeholder publisher
  - File type associations (.md, .markdown)
  - Protocol association (mdview)
  - Visual elements configured

### B.3.2 Create Visual Assets

- [ ] B.3.2.1-7 PNG assets need to be created from source icon
  - README.md added with size requirements and conversion instructions

### B.3.3 Create Build Script

- [x] B.3.3.1-5 Implemented in `installers/win-msix/build.ps1`:
  - Build parameters (Configuration, Architecture, Version)
  - Stages Host EXE, engine files, bundled pwsh
  - Creates MSIX via makeappx.exe

---

## B.4 Bundled PowerShell Strategy

**Status: DOCUMENTED**

- [x] B.4.1.1-B.4.3.2 Strategy documented in build.ps1:
  - Can copy from system pwsh or use provided zip
  - Full runtime (trimming deferred per spec)

---

## B.5 Engine Validation Under Packaged Execution

**Status: DEFERRED (Manual Testing Required)**

- [ ] B.5.1-B.5.3 Manual testing required after MSIX package is built and installed

---

## B.6 Unit Tests

**Status: COMPLETE**

### B.6.1 Host EXE Unit Tests

- [x] B.6.1.1-7 Implemented in `tests/MarkdownViewerHost.Tests/`:
  - 12 xUnit tests covering argument handling, path resolution, process config
  - All tests pass

### B.6.2 Update Existing PowerShell Tests

- [x] B.6.2.1-4 Updated paths in `tests/MarkdownViewer.Tests.ps1`:
  - Module path: `src/win/MarkdownViewer.psm1`
  - Asset paths: `src/core/`
  - Installer paths: `installers/win-adhoc/`
  - All 170 tests pass

---

## B.7 Documentation Updates

**Status: COMPLETE**

- [x] B.7.1.1-3 README.md updated with MSIX option and new structure
- [x] B.7.2.1-5 Architecture doc updated with Host EXE and MSIX details

---

## B.8 Final Validation

**Status: IN PROGRESS**

### B.8.1 Build Verification

- [x] B.8.1.1 PowerShell tests: 170 pass
- [x] B.8.1.2 Host EXE builds successfully
- [x] B.8.1.3 Host EXE tests: 12 pass
- [ ] B.8.1.4 MSIX package build (requires Windows SDK)
- [ ] B.8.1.5 Sideload testing (manual)

### B.8.2 Ad-hoc Installer Verification

- [ ] B.8.2.1-4 Manual testing required from new location

---

## Implementation Order

1. **Phase B.1** (Repository Restructure) - Foundation for all other work
2. **Phase B.2** (Host Application) - Core MSIX requirement
3. **Phase B.3** (MSIX Package Definition) - Packaging infrastructure
4. **Phase B.4** (Bundled PowerShell) - Runtime dependency
5. **Phase B.6** (Unit Tests) - Validate implementation
6. **Phase B.5** (Engine Validation) - Packaged execution testing
7. **Phase B.7** (Documentation) - User and developer docs
8. **Phase B.8** (Final Validation) - End-to-end verification

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Windows App SDK compatibility | Test with latest stable SDK version |
| Bundled pwsh size (~100MB) | Accept for initial release; trim later |
| Path resolution in packaged context | Test $PSScriptRoot early in development |
| CSP blocking file: URLs from WindowsApps | Verify CSP allows any local file: path |
| Breaking existing ad-hoc installer | Run full test suite after restructure |

---

## Rollback Plan

If critical issues are found post-release:
1. Ad-hoc installer remains available as fallback
2. MSIX can be unpublished from Store
3. Revert repository structure if needed (branches preserved)

---

## Success Criteria

1. MSIX installs and registers file/protocol associations
2. Double-click `.md` opens rendered in browser (no console flash)
3. `mdview:` protocol links work from rendered HTML
4. All 170 existing unit tests pass
5. New Host EXE unit tests pass
6. Documentation updated for both install methods

---

# Phase C: Enhancement of MSIX Packaging and Host Launcher

## Overview

This phase addresses feedback from the MSIX packaging review and implements the remaining items needed for a production-ready Microsoft Store submission.

**Key Requirements (from [msix-project-additional-feedback.md](msix-project-additional-feedback.md)):**
- No-args UX: Show helpful info when launched from Start Menu (not via file/protocol)
- Multi-architecture support: Build for both x64 and ARM64
- Automated signing: Streamline dev-signing workflow
- Automated asset generation: Generate MSIX PNG assets from source ICO
- Pinned PowerShell download: Download specific pwsh version with integrity verification

---

## C.1 No-Args UX (Launch from Start Menu)

**Goal:** When the host is launched from Start Menu with no file/protocol activation, show a helpful "How to use" dialog instead of exiting silently.

**Files:** `src/host/MarkdownViewerHost/Program.cs`

### C.1.1 Implement Help Dialog

- [x] C.1.1.1 Add `ShowHelpDialog()` method using Windows MessageBox API
- [x] C.1.1.2 Display message explaining how to use the app:
  - "Use Open With on a .md file"
  - "Set as default for .md/.markdown files"
- [x] C.1.1.3 Include button to open Windows Default Apps settings (ms-settings:defaultapps)
- [x] C.1.1.4 Dialog must work without requiring pwsh (host-only)

### C.1.2 Integrate with Main Entry Point

- [x] C.1.2.1 Call `ShowHelpDialog()` when `args.Length == 0`
- [x] C.1.2.2 Ensure host exits cleanly after dialog is dismissed

### C.1.3 Unit Tests

- [x] C.1.3.1 Test: Empty args triggers help path (mock dialog)
- [x] C.1.3.2 Test: Non-empty args skips help dialog

---

## C.2 Multi-Architecture Support (x64 + ARM64)

**Goal:** Build MSIX packages for both x64 and ARM64 architectures. Optionally create an MSIX bundle.

**Files:** `installers/win-msix/build.ps1`

### C.2.1 Update Build Script for Multi-Arch

- [x] C.2.1.1 Add `-BuildAll` switch to build both x64 and ARM64
- [x] C.2.1.2 Ensure manifest ProcessorArchitecture is set correctly per build
- [x] C.2.1.3 Output separate MSIX files: `MarkdownViewer_<version>_x64.msix`, `MarkdownViewer_<version>_arm64.msix`

### C.2.2 Add MSIX Bundle Support

- [x] C.2.2.1 Add `-Bundle` switch to create `.msixbundle`
- [x] C.2.2.2 Use `makeappx bundle` to combine x64 and ARM64 packages
- [x] C.2.2.3 Output: `MarkdownViewer_<version>.msixbundle`

### C.2.3 PowerShell Runtime Per Architecture

- [x] C.2.3.1 Support downloading ARM64 PowerShell for ARM64 builds
- [x] C.2.3.2 Ensure correct architecture pwsh is bundled per target

---

## C.3 Automated Dev Signing

**Goal:** Automate self-signed certificate creation and MSIX signing for dev/sideload testing.

**Files:** `installers/win-msix/sign.ps1` (new)

### C.3.1 Create Signing Script

- [x] C.3.1.1 Create `sign.ps1` with certificate management
- [x] C.3.1.2 Implement `New-DevCertificate` function:
  - Create self-signed code signing cert in CurrentUser\My
  - Export to CurrentUser\TrustedPeople for local trust
  - Subject matches manifest Publisher (CN=MarkdownViewer)
- [x] C.3.1.3 Implement `Sign-MsixPackage` function:
  - Locate signtool.exe from Windows SDK
  - Sign MSIX using dev certificate
- [x] C.3.1.4 Add `-CreateCertOnly` switch to create/refresh dev certificate
- [x] C.3.1.5 Add `-Sign` switch to sign existing MSIX

### C.3.2 Integrate with Build Script

- [x] C.3.2.1 Add `-Sign` parameter to `build.ps1`
- [x] C.3.2.2 Call `sign.ps1` after package creation when `-Sign` specified

### C.3.3 Documentation

- [x] C.3.3.1 Document dev signing workflow in developer-guide.md
- [x] C.3.3.2 Document Store signing (Microsoft re-signs at submission)

---

## C.4 Automated MSIX Asset Generation

**Goal:** Automatically generate all required PNG assets from the source ICO file.

**Files:** `installers/win-msix/build.ps1` or new `scripts/Convert-IcoToPng.ps1`

### C.4.1 Enhance Asset Generation

- [ ] C.4.1.1 Create robust PNG generation from ICO:
  - Option 1: Use ImageMagick if available
  - Option 2: Use .NET System.Drawing (cross-platform fallback)
- [ ] C.4.1.2 Generate all required sizes:
  - Square44x44Logo.png (and scale variants: 100%, 125%, 150%, 200%, 400%)
  - Square150x150Logo.png (and scale variants)
  - Wide310x150Logo.png (and scale variants)
  - StoreLogo.png (50x50)
- [ ] C.4.1.3 Generate file association badge icons (with plating)
- [ ] C.4.1.4 Support transparent backgrounds

### C.4.2 Integrate with Build

- [ ] C.4.2.1 Generate assets automatically during build if missing
- [ ] C.4.2.2 Skip generation if assets already exist (allow manual override)
- [ ] C.4.2.3 Add `-RegenerateAssets` switch to force regeneration

---

## C.5 Pinned PowerShell Download with Integrity Verification

**Goal:** Download a specific PowerShell version instead of copying system pwsh, with SHA256 verification.

**Files:** `installers/win-msix/build.ps1`

### C.5.1 Define PowerShell Version Configuration

- [x] C.5.1.1 Create `pwsh-versions.json` with pinned versions and hashes:
  ```json
  {
    "version": "7.5.1",
    "archives": {
      "x64": {
        "url": "https://github.com/PowerShell/PowerShell/releases/download/...",
        "sha256": "..."
      },
      "arm64": {
        "url": "https://github.com/PowerShell/PowerShell/releases/download/...",
        "sha256": "..."
      }
    }
  }
  ```
- [x] C.5.1.2 Document how to update the pinned version

### C.5.2 Implement Download with Verification

- [x] C.5.2.1 Add `Get-PwshRuntime` function to build.ps1:
  - Download from GitHub releases if not cached
  - Verify SHA256 hash before extraction
  - Cache in user temp or build cache directory
- [x] C.5.2.2 Add `-DownloadPwsh` switch to force download
- [x] C.5.2.3 Fall back to system pwsh if download fails (with warning)

### C.5.3 Cache Management

- [x] C.5.3.1 Cache downloaded zips in `$env:TEMP\MarkdownViewer-BuildCache`
- [x] C.5.3.2 Skip download if cached file exists and hash matches

---

## C.6 Documentation Updates

**Goal:** Update developer documentation with new build options and workflows.

**Files:** `dev/docs/developer-guide.md`, `README.md`

### C.6.1 Developer Guide Updates

- [x] C.6.1.1 Document new build.ps1 parameters:
  - `-BuildAll`, `-Bundle`, `-Sign`, `-DownloadPwsh`
- [x] C.6.1.2 Document dev signing workflow (create cert, sign, install)
- [x] C.6.1.3 Document how to update pinned PowerShell version
- [ ] C.6.1.4 Document how to change app name (for Store availability)
- [ ] C.6.1.5 Document ARM64 testing requirements

### C.6.2 README Updates

- [ ] C.6.2.1 Update MSIX installation section with signing info
- [ ] C.6.2.2 Note ARM64 support

---

## C.7 Unit Tests

**Goal:** Add tests for new functionality.

**Files:** `tests/MarkdownViewerHost.Tests/HostTests.cs`, `tests/MarkdownViewer.Tests.ps1`

### C.7.1 Host Tests

- [x] C.7.1.1 Test: No-args path is detected correctly
- [x] C.7.1.2 Test: Args path skips no-args handling

### C.7.2 Build Script Tests

- [ ] C.7.2.1 Test: Version parsing from pwsh-versions.json
- [ ] C.7.2.2 Test: SHA256 verification logic (pure function test)

---

## C.8 Final Validation

**Goal:** Verify all enhancements work correctly.

### C.8.1 Build Verification

- [ ] C.8.1.1 x64 MSIX builds successfully
- [ ] C.8.1.2 ARM64 MSIX builds successfully
- [ ] C.8.1.3 MSIX bundle creates correctly
- [ ] C.8.1.4 Signed MSIX installs without Developer Mode

### C.8.2 Functional Verification

- [ ] C.8.2.1 No-args launch shows help dialog with Default Apps link
- [ ] C.8.2.2 File activation works (double-click .md)
- [ ] C.8.2.3 Protocol activation works (mdview: links)
- [ ] C.8.2.4 All existing tests pass (175 Pester + 12 xUnit)

### C.8.3 Architecture Verification

- [ ] C.8.3.1 x64 MSIX runs correctly on x64 Windows
- [ ] C.8.3.2 ARM64 MSIX runs correctly on ARM64 Windows (if available)

---

## Implementation Order

1. **C.1** (No-Args UX) - Critical UX gap
2. **C.4** (Asset Generation) - Enables proper icons
3. **C.2** (Multi-Arch) - ARM64 support
4. **C.5** (Pinned pwsh) - Deterministic builds
5. **C.3** (Dev Signing) - Streamlined testing
6. **C.6** (Documentation) - Developer enablement
7. **C.7** (Tests) - Quality assurance
8. **C.8** (Validation) - Final verification

---

## Success Criteria (Phase C)

1. Launch from Start Menu shows helpful dialog
2. Both x64 and ARM64 MSIX packages build successfully
3. MSIX bundle can be created
4. Dev signing is automated (one command)
5. PNG assets are generated automatically from ICO
6. PowerShell version is pinned with hash verification
7. Documentation covers all new features
8. All unit tests pass

---

# Phase D: MSBuild-Driven WAP Packaging Pipeline

## Overview

This phase replaces the current `build.ps1`-based packaging with a proper MSBuild-driven pipeline using a Windows Application Packaging Project (WAP). The WAP project becomes the authoritative packager, with a `stage.ps1` script handling file composition.

**Key Documents:**
- [msix-staging-wap-msbuild-packaging.md](msix-staging-wap-msbuild-packaging.md) - Detailed design specification

**Goals:**
1. Single build entrypoint: `msbuild MarkdownViewer.wapproj` produces MSIX
2. No manual staging: MSBuild invokes `stage.ps1` automatically
3. Deterministic layout: Host EXE + engine + pwsh + assets always in correct locations
4. Deterministic runtime: Pinned pwsh downloaded and verified
5. Deterministic assets: Generated from ICO and satisfy manifest references
6. Automated signing: Dev build can produce signed MSIX

---

## D.1 Repository Structure Updates

**Goal:** Reorganize `installers/win-msix/` to match the target layout.

### D.1.1 Rename and Reorganize Files

- [x] D.1.1.1 Rename `WapProjTemplate1.wapproj` → `MarkdownViewer.wapproj`
- [x] D.1.1.2 Create `build/` subdirectory for staging infrastructure
- [x] D.1.1.3 Move pwsh download logic to `build/stage.ps1`
- [x] D.1.1.4 Move `pwsh-versions.json` to `build/pwsh-versions.json`
- [x] D.1.1.5 Rename `Images/` → `Assets/` to match manifest references
- [x] D.1.1.6 Update manifest to reference `Assets\` instead of `Images\`

### D.1.2 Update Solution File

- [x] D.1.2.1 Add WAP project to `MarkdownViewer.slnx` with correct Type GUID
- [x] D.1.2.2 Ensure solution builds host EXE before WAP project

---

## D.2 Create Staging Script

**Goal:** Create `build/stage.ps1` as the authoritative file composition script.

**File:** `installers/win-msix/build/stage.ps1`

### D.2.1 Script Parameters

- [x] D.2.1.1 `-Configuration` (Debug/Release)
- [x] D.2.1.2 `-Platform` (x64/ARM64)
- [x] D.2.1.3 `-HostOutputDir` (path to host build output)
- [x] D.2.1.4 `-CoreDir` (path to src/core)
- [x] D.2.1.5 `-StagingDir` (output directory for staged files)
- [x] D.2.1.6 `-SkipPwsh` (skip pwsh bundling for dev)

### D.2.2 Staging Operations

- [x] D.2.2.1 **Clean staging directory** - Remove stale files
- [x] D.2.2.2 **Copy host output** - `MarkdownViewerHost.exe` + deps to staging root
- [x] D.2.2.3 **Copy engine payload** to `app\`:
  - `Open-Markdown.ps1`
  - `script.js`
  - `style.css`
  - `highlight.min.js`
  - `highlight-theme.css`
  - `icons/` directory
- [x] D.2.2.4 **Download/unpack pwsh** to `pwsh\`:
  - Use pinned version from `pwsh-versions.json`
  - Verify SHA256 hash
  - Skip if `-SkipPwsh` specified
- [x] D.2.2.5 **Generate MSIX assets** to `Assets\`:
  - Use ImageMagick if available
  - Generate all required PNG sizes from ICO
  - Skip generation if assets already exist (unless forced)

### D.2.3 Validation

- [x] D.2.3.1 Verify `MarkdownViewerHost.exe` exists in staging root
- [x] D.2.3.2 Verify `app\Open-Markdown.ps1` exists
- [x] D.2.3.3 Verify `pwsh\pwsh.exe` exists (unless `-SkipPwsh`)
- [x] D.2.3.4 Verify all manifest-referenced assets exist
- [x] D.2.3.5 Fail build if any required file is missing

---

## D.3 Create MSBuild Integration

**Goal:** Wire `stage.ps1` into the WAP build via MSBuild targets.

### D.3.1 Create Directory.Build.targets

**File:** `installers/win-msix/build/Directory.Build.targets`

- [x] D.3.1.1 Define `<StagingOutputDir>` property (e.g., `$(IntermediateOutputPath)Staging\`)
- [x] D.3.1.2 Define `<StagePayload>` target that runs before packaging
- [x] D.3.1.3 Invoke `pwsh -File stage.ps1` with correct parameters:
  - Pass `$(Configuration)`, `$(Platform)`
  - Pass host output directory
  - Pass core payload directory
  - Pass staging output directory
- [x] D.3.1.4 Set target dependencies so staging runs after host build

### D.3.2 Update WAP Project

**File:** `installers/win-msix/MarkdownViewer.wapproj`

- [x] D.3.2.1 Add project reference to `MarkdownViewerHost.csproj`
- [x] D.3.2.2 Configure to package from staging directory
- [x] D.3.2.3 Import `build/Directory.Build.targets`
- [x] D.3.2.4 Remove hardcoded asset `<Content>` items (will come from staging)
- [x] D.3.2.5 Add dynamic `<Content>` items from staged payload

---

## D.4 Update Manifest and Assets

**Goal:** Ensure manifest correctly references staged assets and host executable.

### D.4.1 Update Package.appxmanifest

- [x] D.4.1.1 Verify `Executable="MarkdownViewerHost.exe"` is correct
- [x] D.4.1.2 Update asset references to use `Assets\` (not `Images\`)
- [x] D.4.1.3 Ensure `ProcessorArchitecture` is handled per-build (or use neutral)

### D.4.2 Asset Generation

- [x] D.4.2.1 Generate required PNGs:
  - `Square44x44Logo.png` (44x44)
  - `Square150x150Logo.png` (150x150)
  - `Wide310x150Logo.png` (310x150)
  - `StoreLogo.png` (50x50)
- [ ] D.4.2.2 Optionally generate scale variants (scale-125, scale-150, scale-200)
- [x] D.4.2.3 Support transparent backgrounds

---

## D.5 Signing Integration

**Goal:** Integrate dev signing into the WAP build.

### D.5.1 Add Post-Build Signing Target

- [x] D.5.1.1 Add `<SignPackage>` target that runs after packaging
- [x] D.5.1.2 Invoke `sign.ps1` to sign produced MSIX
- [x] D.5.1.3 Make signing conditional on `$(SignMsix)` property
- [ ] D.5.1.4 Document how to build signed: `msbuild /p:SignMsix=true`

---

## D.6 Bundle Support

**Goal:** Support creating MSIX bundle from x64 + ARM64 packages.

### D.6.1 Add Bundle Target

- [ ] D.6.1.1 Add `<CreateBundle>` target that runs after both arch builds
- [ ] D.6.1.2 Use `makeappx bundle` to combine packages
- [ ] D.6.1.3 Output to `output/MarkdownViewer_<version>.msixbundle`
- [ ] D.6.1.4 Document bundle build workflow

> **Note:** Bundle creation deferred - can be done manually or via build.ps1 until WAP-native bundle support is added.

---

## D.7 Remove Legacy build.ps1

**Goal:** Remove `build.ps1` once the new pipeline is validated.

**Prerequisite:** Visual Studio with "Windows Application Packaging Project" workload installed (provides DesktopBridge SDK).

### D.7.1 Validation Checklist

- [ ] D.7.1.1 WAP build produces x64 MSIX
- [ ] D.7.1.2 WAP build produces ARM64 MSIX
- [ ] D.7.1.3 Signed MSIX installs and runs
- [ ] D.7.1.4 File activation works
- [ ] D.7.1.5 Protocol activation works
- [ ] D.7.1.6 No-args launch shows help dialog
- [ ] D.7.1.7 All tests pass

### D.7.2 Cleanup

- [ ] D.7.2.1 Delete `build.ps1` from `installers/win-msix/`
- [ ] D.7.2.2 Update documentation to reference WAP build
- [ ] D.7.2.3 Update CI/CD scripts if any

---

## D.8 Documentation Updates

**Goal:** Document the new build pipeline.

### D.8.1 Developer Guide Updates

- [ ] D.8.1.1 Document MSBuild build commands:
  - `msbuild MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release`
  - `msbuild MarkdownViewer.wapproj /p:Platform=ARM64 /p:Configuration=Release`
- [ ] D.8.1.2 Document signing: `/p:SignMsix=true`
- [ ] D.8.1.3 Document bundle creation workflow
- [ ] D.8.1.4 Document staging script for advanced scenarios

### D.8.2 Update README

- [ ] D.8.2.1 Update MSIX build instructions for WAP project
- [ ] D.8.2.2 Remove references to build.ps1

---

## D.9 Unit Tests

**Goal:** Test the staging script.

### D.9.1 Staging Script Tests

**File:** `tests/pwsh/Stage.Tests.ps1`

- [x] D.9.1.1 Test: Staging creates correct directory structure
- [x] D.9.1.2 Test: Host EXE is copied to staging root
- [x] D.9.1.3 Test: Engine files are copied to `app\`
- [x] D.9.1.4 Test: Pwsh is downloaded and extracted to `pwsh\`
- [x] D.9.1.5 Test: SHA256 verification rejects bad hashes
- [x] D.9.1.6 Test: Validation fails if required files missing
- [x] D.9.1.7 Test: `-SkipPwsh` skips pwsh bundling

> **Note:** 52 tests created in Stage.Tests.ps1 covering script structure, parameters, functions, staging logic, asset generation, validation, and Directory.Build.targets.

---

## Implementation Order

1. **D.1** (Repo Structure) - ✅ Complete
2. **D.2** (Staging Script) - ✅ Complete
3. **D.3** (MSBuild Integration) - ✅ Complete
4. **D.4** (Manifest/Assets) - ✅ Complete
5. **D.5** (Signing) - ✅ Complete
6. **D.6** (Bundle) - Deferred (use build.ps1 for now)
7. **D.9** (Tests) - ✅ Complete (52 tests)
8. **D.7** (Remove build.ps1) - Pending (needs DesktopBridge workload)
9. **D.8** (Documentation) - Pending

---

## Success Criteria (Phase D)

1. `msbuild MarkdownViewer.wapproj` produces MSIX without manual steps - **Pending** (needs DesktopBridge)
2. Staging runs automatically as part of build - ✅ Configured in Directory.Build.targets
3. Both x64 and ARM64 packages build successfully - **Pending**
4. Signed packages install and run correctly - **Pending**
5. Bundle creation works - Deferred to build.ps1
6. `build.ps1` is removed - **Pending** (keep as fallback until WAP validated)
7. All tests pass - ✅ 255 Pester + 20 xUnit = 275 tests passing
8. Documentation is updated - **Pending**

---

## Prerequisites for WAP Build

To build the WAP project, you need Visual Studio with the **Windows Application Packaging Project** workload installed:

1. Open Visual Studio Installer
2. Select "Modify" on your VS installation
3. Under "Individual components", search for and install:
   - "MSIX Packaging Tools" (or "Windows 10 SDK" with Desktop Bridge)
   - The DesktopBridge SDK provides `Microsoft.DesktopBridge.props` and `.targets`

Alternatively, use `build.ps1` which uses `makeappx.exe` directly without requiring the WAP SDK.
