# Markdown Viewer Implementation Plan

## Overview

This document outlines the implementation plan for Markdown Viewer features:
- **Phase A (Complete):** highlight.js syntax highlighting integration
- **Phase B (Complete):** MSIX packaging and Host launcher for Microsoft Store distribution
- **Phase C (Current):** Enhancement of MSIX Packaging and Host Launcher
- **Phase D (In Progress):** MSBuild-Driven WAP Packaging Pipeline
- **Phase E (Complete):** Fragment Navigation (`_fragment` App Contract & Scrolling)
- **Phase F (Planned):** Offline KaTeX math typesetting

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

- [x] C.4.1.1 Create robust PNG generation from ICO:
  - Option 1: Use ImageMagick if available ✅
  - Option 2: Use .NET System.Drawing (cross-platform fallback) ✅
- [x] C.4.1.2 Generate all required sizes:
  - Square44x44Logo.png (44x44) ✅
  - Square150x150Logo.png (150x150) ✅
  - Wide310x150Logo.png (310x150) ✅
  - StoreLogo.png (50x50) ✅
  - Note: Scale variants deferred - not required for basic MSIX
- [ ] C.4.1.3 Generate file association badge icons (with plating)
- [x] C.4.1.4 Support transparent backgrounds

### C.4.2 Integrate with Build

- [x] C.4.2.1 Generate assets automatically during build if missing
- [x] C.4.2.2 Skip generation if assets already exist (allow manual override)
- [x] C.4.2.3 Add `-ForceRegenAssets` switch to force regeneration

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
  - `Square44x44Logo.png` (44x44) ✅
  - `Square150x150Logo.png` (150x150) ✅
  - `Wide310x150Logo.png` (310x150) ✅
  - `StoreLogo.png` (50x50) ✅
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

- [x] D.7.1.1 WAP build produces x64 MSIX
- [ ] D.7.1.2 WAP build produces ARM64 MSIX
- [ ] D.7.1.3 Signed MSIX installs and runs
- [ ] D.7.1.4 File activation works
- [ ] D.7.1.5 Protocol activation works
- [ ] D.7.1.6 No-args launch shows help dialog
- [x] D.7.1.7 All tests pass

### D.7.2 Cleanup

- [ ] D.7.2.1 Delete `build.ps1` from `installers/win-msix/`
- [ ] D.7.2.2 Update documentation to reference WAP build
- [ ] D.7.2.3 Update CI/CD scripts if any

---

## D.8 Documentation Updates

**Goal:** Document the new build pipeline.

### D.8.1 Developer Guide Updates

- [x] D.8.1.1 Document MSBuild build commands:
  - `msbuild MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release`
  - `msbuild MarkdownViewer.wapproj /p:Platform=ARM64 /p:Configuration=Release`
- [x] D.8.1.2 Document signing: `/p:SignMsix=true`
- [ ] D.8.1.3 Document bundle creation workflow
- [x] D.8.1.4 Document staging script for advanced scenarios

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

1. `msbuild MarkdownViewer.wapproj` produces MSIX without manual steps - ✅ **Complete**
2. Staging runs automatically as part of build - ✅ Configured in Directory.Build.targets
3. Both x64 and ARM64 packages build successfully - **Pending** (ARM64 untested)
4. Signed packages install and run correctly - **Pending**
5. Bundle creation works - Deferred to build.ps1
6. `build.ps1` is removed - **Pending** (keep as fallback until WAP validated)
7. All tests pass - ✅ 80 Pester + 20 xUnit = 100 tests passing
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

---

# Phase E: Fragment Navigation (`_fragment` App Contract & Scrolling) (Complete)

## Overview

Standardize fragment delivery for `mdview:` protocol links across all platforms using a `_fragment` query parameter. This removes dependence on `#fragment` surviving portal/scheme-handler boundaries and provides a clean, deterministic contract that works for click navigation, paste-in-address-bar, terminal launches, and file associations.

**Goals:**
1. `mdview:` links carry the fragment as `?_fragment=<id>` (survives portal/shell stripping of `#`)
2. `Open-Markdown.ps1` recovers `_fragment` from the query and delivers it to the rendered HTML as `?_fragment=`
3. `script.js` scrolls to the target element on page load via `?_fragment=` on the HTML URL
4. All platforms use the same code paths — no platform gating
5. No localStorage fallback — strict contract only (add later only if a real browser drops query strings on `file:` URLs)

**Non-goals (explicitly dropped):**
- Backward compatibility with `mdview:…#fragment` inputs (HTML is transient, short-lived)
- localStorage-based fragment passing (removed — adds complexity, collision risk, and test burden)

**Key files:**
| File | Role |
|------|------|
| `src/core/script.js` | Encodes `_fragment` into `mdview:` links; scrolls on load via query param; removes `_fragment` from URL after scroll |
| `src/core/Open-Markdown.ps1` | Parses `_fragment` from incoming URI; passes it to HTML URL via `Start-DefaultBrowser` |
| `tests/MarkdownViewer.Tests.ps1` | Pester tests for `_fragment` parsing in Open-Markdown |
| `tests/pwsh/BrowserLaunch.Tests.ps1` | Tests for fragment launch integration |
| `dev/docs/markdown-viewer-architecture.md` | Architecture doc updated with `_fragment` contract |

---

## `_fragment` Contract Rules

These rules are the single source of truth for fragment handling. All phases implement these rules.

1. **Value:** `_fragment` carries the **raw element id without leading `#`**.
2. **Encoding (producer):** JS uses `encodeURIComponent(id)`; PowerShell uses `[Uri]::EscapeDataString($id)`.
3. **Decoding (consumer):** PowerShell uses `[Uri]::UnescapeDataString($val)`; JS uses `URLSearchParams` (auto-decodes).
4. **Empty value:** If the decoded value is empty, ignore — no scroll.
5. **Existing query strings:** If the resolved URL already contains `?…`, append `&_fragment=…`. If it already contains `_fragment`, overwrite it.
6. **`#hash` on input:** If the source href has `#fragment`, strip it and move the value to `?_fragment=`. Do **not** preserve or pass through `#hash`.
7. **Launch rule:** When `_fragment` is present, the HTML **must** be opened as a URL (`file:///…?_fragment=…`) via `Start-DefaultBrowser`, never as a filesystem path via `Start-Process`. On Windows, `Start-Process $path` with `?` in the string is treated as part of the filename and fails.

---

## E.1 Encode `_fragment` in `mdview:` Links (script.js)

**File:** `src/core/script.js` — `rewriteMarkdownLinks()` function

### E.1.1 Move fragment from `#` to `?_fragment=` in rewritten links

- [x] E.1.1.1 When a local `.md` link has a `#fragment`, strip the hash from the resolved URL and append `?_fragment=<encoded-id>` instead
- [x] E.1.1.2 Handle existing query strings: if the resolved `file:` URL already has `?…`, append `&_fragment=…` instead of `?_fragment=…`
- [x] E.1.1.3 If the resolved URL already has a `_fragment` param, overwrite it (single source of truth)
- [x] E.1.1.4 Remove the existing localStorage `click` event listener that stores `mdview_scroll` — no longer needed
- [x] E.1.1.5 Remove the existing localStorage `mdview_scroll` consumer (scroll-on-load block) — replaced by `_fragment` query param scroll

### E.1.2 Smoke tests (Pester — script.js content)

- [x] E.1.2.1 Test: `script.js` contains `_fragment` string
- [x] E.1.2.2 Test: `script.js` contains `encodeURIComponent`
- [x] E.1.2.3 Test: `script.js` does NOT contain `localStorage.setItem("mdview_scroll"`

---

## E.2 Parse `_fragment` in Open-Markdown.ps1

**File:** `src/core/Open-Markdown.ps1` — URI parsing block

### E.2.1 Extract `_fragment` from the query string

- [x] E.2.1.1 After stripping the `mdview:` prefix and parsing as `[Uri]`, extract `_fragment` from `$u.Query`
- [x] E.2.1.2 Strip the query string from the URI before extracting `$u.LocalPath`
- [x] E.2.1.3 Remove the existing `$frag = $u.Fragment` fallback
- [x] E.2.1.4 Remove the `$hash = $raw.IndexOf('#')` fallback for literal paths with `#`

### E.2.2 Unit tests (Pester)

- [x] E.2.2.1 Test: `mdview:file:///path/doc.md?_fragment=section-1` → `$frag` = `#section-1`
- [x] E.2.2.2 Test: `mdview:file:///path/doc.md?_fragment=Section%20%231` → URL-decoded correctly
- [x] E.2.2.3 Test: `mdview:file:///C:/docs/spec.md?_fragment=intro` → Windows path handled
- [x] E.2.2.4 Test: No fragment → `$frag` = `''`
- [x] E.2.2.5 Test: Empty `_fragment=` → `$frag` = `''`
- [x] E.2.2.6 Test: Both `?_fragment=foo` and `#bar` → `_fragment` wins

---

## E.3 Deliver Fragment to HTML & Scroll on Load

### E.3.1 Open HTML as URL with `_fragment` (Open-Markdown.ps1)

- [x] E.3.1.1 When `$frag` is non-empty, launch via `Start-DefaultBrowser` with HTML URL + `?_fragment=<encoded>`
- [x] E.3.1.2 When `$frag` is empty and on Windows, keep `Start-Process $outLocal` (existing behavior)
- [x] E.3.1.3 When `$frag` is empty and on Linux, keep `Start-DefaultBrowser -Url $uLocal` (existing behavior)

### E.3.2 Scroll to `_fragment` on page load (script.js)

- [x] E.3.2.1 Read `_fragment` from HTML page's URL via `URLSearchParams`
- [x] E.3.2.2 After DOM ready and `fixMismatchedAnchors()`, scroll to element via `scrollIntoView()`
- [x] E.3.2.3 Add retry loop (3 attempts, 200ms apart) for late DOM injection by highlight.js
- [x] E.3.2.4 After successful scroll, clean address bar with `history.replaceState`

### E.3.3 Smoke tests

- [x] E.3.3.1 Test: `script.js` contains `URLSearchParams`
- [x] E.3.3.2 Test: `script.js` contains `history.replaceState`

---

## E.4 Test Suite & Regressions

- [x] E.4.1 Run `Invoke-Pester tests -Output Minimal` — all existing tests pass (307 passed, 0 failed)
- [ ] E.4.2 Run xUnit host tests if dotnet SDK is available (optional)
- [x] E.4.3 Fix any regressions introduced by the changes

---

## E.5 Documentation Updates

**File:** `dev/docs/markdown-viewer-architecture.md`

- [x] E.5.1 Add "Fragment Handling (`_fragment` Contract)" section
- [x] E.5.2 Document contract rules (encoding, decoding, precedence, launch rule)
- [x] E.5.3 Update data-flow diagram to show `_fragment` query-param path
- [x] E.5.4 Remove/update references to `#fragment` being passed through `mdview:` links
- [x] E.5.5 Remove/update references to localStorage-based fragment passing

---

## E.6 Snap Rebuild & Manual Verification (Linux)

- [x] E.6.1 Rebuild snap: `cd installers/linux-snap && ./build.sh arm64`
- [x] E.6.2 Install: `sudo snap install output/markdownviewer_1.2.0_arm64.snap --dangerous`
- [ ] E.6.3 Manual test: open markdown with TOC links → verify scroll (requires desktop environment)

---

## Data Flow (End-to-End)

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
        │  strip query → resolve file path → /path/docs/spec.md
        │  render markdown → viewmd_spec_ABCD1234.html
        ▼
Start-DefaultBrowser (always URL, never path when fragment present):
  file:///home/user/MarkView/viewmd_spec_ABCD1234.html?_fragment=section-1
        │
        ▼
Browser loads HTML, script.js runs:
  1. fixMismatchedAnchors()
  2. URLSearchParams → _fragment = "section-1"
  3. document.getElementById("section-1").scrollIntoView()
  4. history.replaceState() — clean address bar
```

---

## Risk Mitigation (Phase E)

| Risk | Mitigation |
|------|------------|
| `?_fragment` on `file:` URL rejected by browser CSP | `base-uri file:` already allows file: URLs with query strings |
| `_fragment` value contains special chars | `encodeURIComponent` in JS, `[Uri]::EscapeDataString` in PS; consumer URL-decodes once |
| Late DOM (highlighting adds elements after scroll) | Retry loop with setTimeout (3 attempts, 200ms apart) |
| Windows `Start-Process` misinterprets `?` in path | Contract rule: when `_fragment` present, always use `Start-DefaultBrowser` (URL), never `Start-Process` (path) |
| Source URL already has query string | JS checks for existing `?` and uses `&_fragment=` accordingly |
| `System.Web.HttpUtility` not available | Query parsing uses regex + `[Uri]::UnescapeDataString` (both in .NET BCL, always available) |

---

## Success Criteria (Phase E)

1. Clicking a `[link](other.md#section)` in rendered HTML scrolls to `#section` in the target doc
2. Pasting `mdview:file:///path/doc.md?_fragment=section` in a terminal opens and scrolls correctly
3. No-fragment links continue to work (no regression)
4. All Pester tests pass
5. Snap + Firefox on Linux scrolls to correct section
6. Windows ad-hoc install scrolls to correct section
7. Architecture doc reflects the `_fragment` contract

---

# Phase F: Offline KaTeX Math Typesetting (Implemented; Manual Browser Matrix Pending)

## Overview

Add client-side math typesetting with a locally bundled, pinned KaTeX distribution. `ConvertFrom-Markdown` already recognizes Markdig mathematics and emits these intermediate forms:

| Markdown | Converter output | Viewer behavior |
|---|---|---|
| `$E = mc^2$` | `<span class="math">\(E = mc^2\)</span>` | Render as inline math |
| `$$E = mc^2$$` | `<div class="math">\[E = mc^2\]</div>` | Render as display math |

This phase starts after Markdown parsing and HTML sanitization. It typesets only converter-emitted `.math` elements; it does not scan the whole document for dollar-sign delimiters and does not change PowerShell or Markdig parsing behavior.

**Implementation status (2026-08-09):** The runtime, conditional asset flow,
browser module, package definitions, automated tests, fixture, and documentation
are implemented. Pester discovered 619 tests (503 passed, 116 platform/package
skips), the 44 native-host tests passed, and a fresh Windows staged-payload
integration run passed with all 60 KaTeX font files. The remaining unchecked
items require real supported-browser or non-Windows package testing. The
available in-app browser blocks local `file:` navigation by policy, so those
manual results are intentionally not inferred from source-level checks.

**Goals:**

1. Render inline and display math in the default browser on Windows, Linux, and macOS.
2. Remain fully offline: no CDN, remote font, telemetry, or runtime package-manager access.
3. Preserve the existing sanitizer and strict Content Security Policy (CSP).
4. Load and copy KaTeX assets only when the sanitized converter output contains math nodes.
5. Degrade to readable TeX without breaking the rest of the document when KaTeX is missing or an expression fails.
6. Keep the implementation build-tool-free: ship the official browser distribution without adding Node.js/npm as a runtime or repository build prerequisite.

**Non-goals:**

- Changing the Markdown dialect, math delimiter rules, or `ConvertFrom-Markdown` pipeline.
- Fixing currency dollar signs that PowerShell currently misinterprets as math; track that separately in [PowerShell/PowerShell#27792](https://github.com/PowerShell/PowerShell/issues/27792).
- Adding KaTeX auto-render, MathJax, equation numbering policy, custom macros, or a math enable/disable setting in the first version.
- Supporting TeX commands that require trusted HTML, external resources, or network access.

**Upstream references:**

- [KaTeX browser integration](https://katex.org/docs/browser.html)
- [KaTeX rendering options](https://katex.org/docs/options)
- [KaTeX security guidance](https://katex.org/docs/security)
- [KaTeX font layout](https://katex.org/docs/font)

**Key files:**

| File | Role |
|---|---|
| `src/core/vendor/katex/` | Pinned KaTeX browser distribution, fonts, provenance, and license |
| `src/core/Open-Markdown.ps1` | Detect math output, prepare asset URLs, extend CSP, and assemble HTML |
| `src/core/MarkdownViewer.Shared.psm1` | Testable cross-platform math detection and immutable bundle-copy helpers |
| `src/core/script.js` | Typeset converter-emitted `.math` elements after DOM load |
| `src/core/style.css` | Overflow, spacing, print, and fallback presentation |
| `tests/pwsh/MathSupport.Tests.ps1` | Core, security, asset, and HTML integration tests |
| `tests/math-test.md` | Manual cross-platform rendering fixture |
| `THIRD-PARTY-LICENSES.md` | KaTeX version, provenance, and MIT license notice |

---

## F.1 Dependency, Syntax Contract, and Reproducer Tests

### F.1.1 Pin and vendor KaTeX

- [x] MATH-01 Pin KaTeX `v0.18.3` and record the upstream release URL and asset hashes in `src/core/vendor/katex/README.md`
- [x] MATH-02 Vendor the official `katex.min.js`, `katex.min.css`, and every font referenced by that stylesheet while preserving the sibling `fonts/` layout
- [x] MATH-03 Exclude auto-render, source maps, demos, contrib extensions, package-manager metadata, and unreferenced font formats from the runtime payload
- [x] MATH-04 Verify the vendored JavaScript exposes the browser-global `katex` API and contains no CDN or other runtime network dependency
- [x] MATH-05 Add KaTeX's version, source, purpose, and MIT license text to `THIRD-PARTY-LICENSES.md`; include the notice in every packaged distribution

### F.1.2 Lock down the converter contract before implementation

- [x] MATH-06 Add Pester reproducer tests for PowerShell's inline output: `$x^2$` becomes a `span.math` containing `\(...\)`
- [x] MATH-07 Add Pester reproducer tests for PowerShell's display output: `$$x^2$$` becomes a `div.math` containing `\[...\]`
- [x] MATH-08 Verify sanitization preserves the converter's `span.math` and `div.math` elements and their encoded TeX text
- [x] MATH-09 Verify code blocks and ordinary elements are not selected by the viewer's math stage; KaTeX must never reparse `document.body`

---

## F.2 Cross-Platform Asset Delivery and CSP

### F.2.1 Add a content-addressed directory-copy helper

KaTeX CSS resolves fonts relative to `katex.min.css`, so the stylesheet and its `fonts/` sibling must move as one unit. Copy the complete runtime bundle beside generated HTML on every platform. This avoids `file:` cross-directory differences between browsers while retaining the existing POSIX strategy of immutable, content-hashed output assets.

- [x] MATH-10 Add `Copy-MarkViewOutputAssetBundle` to `MarkdownViewer.Shared.psm1`
- [x] MATH-11 Compute a deterministic SHA-256 bundle identity from sorted relative paths plus file bytes; name the output directory `katex.<12-hex>/`
- [x] MATH-12 Copy through a unique sibling temporary directory and atomically rename it; if a concurrent renderer wins the race, validate and reuse the completed destination
- [x] MATH-13 Preserve relative paths, reject files that resolve outside the source bundle, and validate `katex.min.js`, `katex.min.css`, and referenced fonts before returning URLs
- [x] MATH-14 Skip copying when the matching immutable bundle already exists; never overwrite a bundle a browser may have open

### F.2.2 Detect math and conditionally assemble assets

- [x] MATH-15 Add a testable helper that detects a `math` class token on sanitized `span` or `div` output; do not infer syntax from raw Markdown
- [x] MATH-16 Add a `KaTeXRootPath` parameter to `Open-Markdown.ps1`, defaulting to `src/core/vendor/katex/`
- [x] MATH-17 Only when math is present and the bundle is complete, copy/resolve the bundle and add the KaTeX stylesheet and deferred script to both local-image and remote-image HTML variants
- [x] MATH-18 Place `katex.min.css` in `<head>` and the deferred `katex.min.js` before the nonce-protected viewer script, matching the existing highlight.js load pattern
- [x] MATH-19 Omit all KaTeX markup and output-bundle work for documents without math
- [x] MATH-20 If the installed bundle is missing or incomplete, leave the original TeX visible, log a diagnostic, and continue rendering the page

### F.2.3 Extend CSP narrowly

- [x] MATH-21 Add `font-src file:` to `New-Csp`; keep `default-src 'none'`, `connect-src 'none'`, nonce requirements, and all existing sanitizer rules unchanged
- [ ] MATH-22 Verify KaTeX loads with the CSP on `file:` pages without adding `unsafe-inline`, `unsafe-eval`, `https:`, `data:` scripts, or network connections
- [x] MATH-23 Add regression tests proving Markdown-authored `<script>`, `<link>`, and `<style>` elements are still stripped before application-owned KaTeX tags are assembled

---

## F.3 Browser Typesetting and Presentation

### F.3.1 Render only converter-emitted math nodes

- [x] MATH-24 Add an isolated math module to `script.js` that runs once after DOM readiness and selects only `span.math` and `div.math`
- [x] MATH-25 Read source with `textContent`, accept only the converter wrappers `\(...\)` and `\[...\]`, remove exactly one outer wrapper pair, and derive `displayMode` from that pair
- [x] MATH-26 Call `katex.render(source, element, options)` directly; do not include or call KaTeX auto-render
- [x] MATH-27 Render with explicit safe options: `output: "htmlAndMathml"`, `throwOnError: false`, `strict: "warn"`, `trust: false`, `maxSize: 10`, `maxExpand: 1000`, and `globalGroup: false`
- [x] MATH-28 Add document limits consistent with syntax highlighting: process at most 1,000 math nodes and skip any expression over 100 KB, leaving skipped source readable
- [x] MATH-29 Make processing idempotent and mark successfully processed nodes so duplicate DOM initialization cannot render them twice

### F.3.2 Failure behavior and styling

- [x] MATH-30 If `window.katex` is unavailable, leave all source nodes untouched and emit one console warning
- [x] MATH-31 Preserve the original text before each render; on an unexpected exception restore it with `textContent`, never with `innerHTML`
- [x] MATH-32 Add viewer CSS for horizontally scrollable long display equations, inline alignment, readable unrendered fallback text, and print output
- [ ] MATH-33 Verify KaTeX inherits foreground color and remains legible across every light/dark theme variation without modifying the upstream KaTeX stylesheet
- [ ] MATH-34 Verify generated MathML remains in the accessibility tree and does not interfere with copy/paste, fragment scrolling, or syntax highlighting

---

## F.4 Installer and Package Integration

### F.4.1 Windows ad-hoc and MSIX

- [x] MATH-35 Update `installers/win-adhoc/install.ps1` to copy `vendor/katex/` recursively and apply the existing read-only policy to its files
- [x] MATH-36 Update `installers/win-msix/build/stage.ps1` to stage and validate the complete KaTeX directory
- [x] MATH-37 Update both legacy staging paths in `installers/win-msix/build.ps1`; preserve the directory hierarchy in the MSIX
- [x] MATH-38 Extend staged-payload and MSIX-content tests to verify JavaScript, CSS, fonts, provenance, and license files

### F.4.2 Linux Snap

- [x] MATH-39 Update `installers/linux-snap/build.sh` to copy the KaTeX directory recursively into `staged/app/vendor/katex/`
- [x] MATH-40 Extend `SnapBuild.Tests.ps1` and the bundled-PowerShell verification flow to assert that KaTeX assets survive staging and strict confinement

### F.4.3 macOS DMG

- [x] MATH-41 Update `installers/macos-dmg/build.sh` to copy the KaTeX directory recursively into the app resources
- [x] MATH-42 Extend `MacBundle.Tests.ps1` and DMG verification to assert that KaTeX assets are present before signing and notarization

---

## F.5 Automated and Manual Verification

### F.5.1 Unit and integration tests

- [x] MATH-43 Add `tests/pwsh/MathSupport.Tests.ps1` with unit tests for math-node detection, stable bundle hashing, nested-font copying, cache reuse, incomplete bundles, and concurrent-copy behavior
- [x] MATH-44 Add HTML-assembly tests proving math documents contain local KaTeX tags in the correct order and non-math documents contain none
- [x] MATH-45 Add CSP tests for `font-src file:` and for the continued absence of network, unsafe-inline, and unsafe-eval permissions
- [x] MATH-46 Add `script.js` contract tests for selector scope, delimiter validation, safe options, resource limits, idempotence, and missing-library fallback
- [x] MATH-47 Add packaging tests for the Windows ad-hoc payload, MSIX staging, Snap staging, and macOS app resources
- [x] MATH-48 Run the complete Pester 5.7.1 suite and the existing host tests; fix all regressions

### F.5.2 Browser fixture and platform matrix

- [x] MATH-49 Add `tests/math-test.md` covering inline/display expressions, fractions, roots, sums, matrices, Unicode, invalid TeX, long equations, math beside links, and TeX-looking text inside code fences
- [ ] MATH-50 Verify packaged Windows output in Edge, Chrome, and Firefox, including a path containing spaces and non-ASCII characters
- [x] MATH-51 Verify the Snap with Firefox under strict confinement and confirm fonts load from the content-addressed output directory
- [x] MATH-52 Verify the signed macOS app with Safari and Chrome and confirm no quarantine/signing regression from the added resources
- [ ] MATH-53 With browser developer tools, verify a math document makes no network requests and a non-math document does not request or copy KaTeX assets
- [ ] MATH-54 Temporarily remove/corrupt a KaTeX asset in a development copy and verify the page remains usable with readable TeX fallback

---

## F.6 Documentation

- [x] MATH-55 Update `README.md` with supported inline (`$...$`) and display (`$$...$$`) syntax, examples, offline behavior, and fallback behavior
- [x] MATH-56 Document the current PowerShell dollar-sign parsing limitation and link to PowerShell/PowerShell#27792 without making math support depend on that fix
- [x] MATH-57 Update `markdown-viewer-architecture.md` with the post-sanitization KaTeX stage, asset-bundle flow, CSP font rule, and trust boundary
- [x] MATH-58 Update `developer-guide.md` with the pinned-version update procedure, required files, hash/provenance checks, packaging checks, and manual browser fixture
- [x] MATH-59 Document that KaTeX auto-render is intentionally excluded because Markdown parsing remains the responsibility of `ConvertFrom-Markdown`

---

## Data Flow (Phase F)

```
Markdown source
    |
    v
Repair-MarkdownLinks -> ConvertFrom-Markdown
    |                    emits span.math / div.math with \(...\) / \[...\]
    v
Invoke-HtmlSanitization -> Repair-HtmlLinks
    |
    +-- no math nodes ------------------------------+
    |                                               |
    +-- math nodes                                  |
          |                                         |
          v                                         |
    Copy/reuse katex.<content-hash>/ beside HTML    |
          |                                         |
          v                                         v
    Assemble local CSS + deferred JS             Assemble page
          |                                         |
          +----------------------+------------------+
                                 v
                         Browser loads local page
                                 |
                         DOMContentLoaded
                                 |
                  script.js selects only .math nodes
                                 |
                  katex.render(..., trust: false)
                                 |
                      HTML + accessible MathML
```

---

## Risk Mitigation (Phase F)

| Risk | Mitigation |
|---|---|
| KaTeX reparses currency or code as math | Never use auto-render or scan body text; process only converter-emitted `.math` nodes |
| CSS loads but fonts do not | Keep the stock CSS and referenced `fonts/` tree together in one content-addressed directory beside the generated HTML |
| Untrusted TeX creates links, images, attributes, or excessive layout | Use `trust: false`, finite `maxSize`/`maxExpand`, node/source caps, and the existing no-network CSP |
| Client-generated KaTeX DOM is not passed through the Markdown sanitizer | Use KaTeX's DOM API with safe options; never inject error/source strings with `innerHTML`; retain CSP defense-in-depth |
| Missing or invalid assets break the page | Validate the bundle before emitting tags and keep converter output visible as fallback |
| Concurrent viewers partially copy a multi-file bundle | Copy to a unique temporary directory, atomically rename, and validate an existing winning destination |
| Dependency update silently changes files or license | Pin the version, record source and hashes, keep the MIT notice, and test the required asset inventory |
| Package size grows unexpectedly | Ship only the minified runtime, stylesheet, referenced fonts, provenance, and license; exclude auto-render and development files |
| Math-free documents pay a startup cost | Detect sanitized math nodes before copying or linking any KaTeX asset |
| PowerShell changes its math wrapper contract | Converter-contract tests fail before browser behavior silently regresses |

---

## Implementation Order (Phase F)

1. **MATH-06 through MATH-09:** Lock down converter and sanitizer behavior with reproducer tests.
2. **MATH-01 through MATH-05:** Vendor the pinned, licensed, minimal KaTeX distribution.
3. **MATH-10 through MATH-23:** Implement and test bundle delivery, conditional HTML assembly, and CSP.
4. **MATH-24 through MATH-34:** Implement browser typesetting, limits, fallback behavior, and styling.
5. **MATH-35 through MATH-42:** Integrate and validate all installers/packages.
6. **MATH-43 through MATH-54:** Complete automated tests and the cross-platform browser matrix.
7. **MATH-55 through MATH-59:** Update user, architecture, dependency, and maintenance documentation.

---

## Success Criteria (Phase F)

1. Inline `$...$` and display `$$...$$` expressions render with locally bundled KaTeX on supported Windows, Linux, and macOS browsers.
2. The viewer processes only `.math` elements produced before page assembly; it never auto-detects delimiters in ordinary DOM text.
3. Rendered equations include visual HTML and accessible MathML.
4. Math documents make no network requests, and the CSP remains strict with only `font-src file:` added.
5. Non-math documents neither copy nor load KaTeX assets.
6. Invalid expressions, missing assets, and configured resource-limit violations leave readable source without breaking themes, links, images, code highlighting, or fragment navigation.
7. KaTeX JavaScript, CSS, fonts, provenance, and licensing are present and usable in Windows ad-hoc/MSIX, Linux Snap, and macOS DMG payloads.
8. All automated tests pass, and the platform/browser manual matrix is complete.

---

# Phase G: MarkView 1.4.0 Math Release (Planned)

## Release Recommendation

Use **1.4.0** for the first public release containing offline KaTeX math
typesetting. Math support is an additive, user-visible capability across all
supported platforms, so a minor version communicates the scope more accurately
than a 1.3.x patch. It does not introduce a compatibility break that would
justify 2.0.0.

Planning snapshot as of 2026-08-13:

| Surface | Current public version | 1.4.0 target |
|---|---:|---:|
| Windows Microsoft Store | 1.3.1 | 1.4.0.0, x64, unsigned Store submission |
| macOS GitHub DMG | 1.3.0 | 1.4.0, Apple Silicon, signed/notarized/stapled |
| Snap Store | 1.3.0 revision 2 | 1.4.0, amd64 and arm64 |
| GitHub release routing page | v1.3.1 | v1.4.0 with the macOS DMG and platform links |

The release should be cut from one reviewed release-candidate commit. Generated
packages, local signing certificates, Store credentials, Snap credentials, and
notarization material must remain outside version control.

## Release Invariants

- The canonical source version is `1.4.0`; the Windows package version is
  `1.4.0.0`.
- The locally signed Windows MSIX is a QA artifact only. The Microsoft Store
  submission must be rebuilt unsigned and must not contain `AppxSignature.p7x`.
- Windows Store remains x64, macOS remains arm64, and Snap ships both amd64 and
  arm64.
- KaTeX JavaScript, CSS, fonts, provenance, and license files must be present in
  every packaged payload and must work offline.
- Existing public tags are immutable. Create `v1.4.0-windows`,
  `v1.4.0-macos`, and `v1.4.0-linux` only after each channel is public, then
  create canonical `v1.4.0` after all channels are verified.
- Manual platform/browser tasks are closed only with recorded results from the
  packaged app, not from source-tree inspection alone.

---

## G.1 Release-Candidate Readiness

- [x] **REL140-01** — Review the complete math-support diff and confirm that it
  contains only intended source, tests, documentation, and vendored KaTeX
  assets.
- [x] **REL140-02** — Confirm generated MSIX, DMG, Snap, staging, signing, and
  test-output files are ignored and absent from the candidate commit.
- [x] **REL140-03** — Run the full PowerShell/Pester and .NET host test suites
  from a clean checkout and record the totals.
- [x] **REL140-04** — Commit the math feature as a standalone reviewed change
  before making release-only version and metadata changes (`2702452`).
- [x] **REL140-05** — Record the clean math-feature baseline commit SHA
  (`2702452`) on which the 1.4.0 release-only changes are based.
- [ ] **REL140-06** — Complete `MATH-22` browser validation for conditional
  asset loading and zero-network behavior.
- [ ] **REL140-07** — Complete `MATH-33` and `MATH-34` packaged-app validation
  for fallback behavior, overflow, and theme styling.
- [ ] **REL140-08** — Complete `MATH-50` through `MATH-54` on the supported
  Windows, Linux, and macOS browser matrix, including accessibility and
  regression checks.

## G.2 Version, Metadata, and Release Notes

- [x] **REL140-09** — Change the canonical project version from 1.3.1 to 1.4.0.
- [x] **REL140-10** — Run `dev/scripts/Test-VersionConsistency.ps1 -Fix` and
  review every propagated version change.
- [x] **REL140-11** — Run version consistency validation without `-Fix` and
  require all references to report 1.4.0 or 1.4.0.0 as appropriate.
- [x] **REL140-12** — Verify the Windows identity and manifest version resolve
  to 1.4.0.0 and all release artifact names resolve to 1.4.0.
- [x] **REL140-13** — Add an Unreleased 1.4.0 changelog section covering
  offline math typesetting, safe fallback behavior, accessibility output, and
  packaged KaTeX assets; replace Unreleased with the actual publication date
  during closeout.
- [x] **REL140-14** — Prepare common release notes plus channel-specific Store
  descriptions; keep claims limited to completed and verified behavior.
- [ ] **REL140-15** — Update Snap and Microsoft Store metadata/screenshots only
  where the new math capability materially changes the listing.
- [ ] **REL140-16** — Prepare the draft GitHub 1.4.0 routing release, including
  Store/Snap links and a checksum only for the GitHub-hosted macOS DMG.
- [x] **REL140-51** — Commit the reviewed 1.4.0 version and release metadata,
  then record the clean release-candidate SHA used for every platform package.

## G.3 Cross-Platform Quality Gates

- [x] **REL140-17** — Run the complete Windows test matrix, including all
  Pester tests and the native-host xUnit suite.
- [ ] **REL140-18** — Run the Linux tests on Ubuntu 24.04 for amd64.
- [ ] **REL140-19** — Run the Linux tests on Ubuntu 24.04 for arm64.
- [ ] **REL140-20** — Run the macOS tests on an Apple Silicon host.
- [ ] **REL140-21** — Inspect each package for the pinned KaTeX JavaScript,
  stylesheet, referenced font set, provenance record, and MIT license.
- [ ] **REL140-22** — Open the math fixture from each installed package and
  verify inline math, display math, Unicode, matrices, malformed input,
  currency exclusions, inline/fenced code exclusions, and long-expression
  overflow.
- [ ] **REL140-23** — Verify math and non-math documents in light and dark
  themes with no network access.
- [ ] **REL140-24** — Verify accessible MathML is exposed and ordinary text
  selection, copying, links, fragments, and syntax highlighting still work.

## G.4 Windows Store Release

- [x] **REL140-25** — Build a locally signed x64 1.4.0.0 MSIX from the exact
  release-candidate commit for installation testing.
- [x] **REL140-26** — Validate the signed QA package signature, version,
  identity, architecture, runtime contents, KaTeX contents, and staged tests.
- [x] **REL140-27** — Install the QA MSIX and test file activation, command-line
  activation, theme switching, math rendering, offline behavior, and
  uninstall/reinstall.
- [ ] **REL140-28** — Run the applicable Windows App Certification Kit checks
  and record any advisory-only exceptions.
- [x] **REL140-29** — Delete or isolate the signed QA output, then make a fresh
  unsigned x64 Store build from the same release-candidate commit.
- [x] **REL140-30** — Prove the Store artifact is unsigned, is 1.4.0.0, has the
  expected identity, and contains no `AppxSignature.p7x`.
- [x] **REL140-31** — Submit the minimal artifact set for product
  `9MSWK3Q0JZ5N`, monitor certification, and use manual publication unless an
  intentional coordinated time is chosen.
- [x] **REL140-32** — After public availability, install from the Store, repeat
  the math smoke test, record the public version, and create
  `v1.4.0-windows`.

Windows publication evidence (2026-08-14 UTC): Partner Center reports
Submission 4 updated and available in Microsoft Store. A fresh product
`9MSWK3Q0JZ5N` install reported x64 version 1.4.0.0, `SignatureKind: Store`,
and status OK. Registered `mdview:` protocol activation reached the packaged
host, produced ten math nodes with local KaTeX JavaScript, CSS, and 60 fonts,
and retained the no-network CSP. The submitted MSIX was independently
confirmed unsigned with no `AppxSignature.p7x`; `v1.4.0-windows` records its
release-candidate commit `c29ac9c`. Local WACK task REL140-28 remains an
advisory follow-up; Microsoft Store certification and publication passed.

## G.5 macOS DMG Release

- [x] **REL140-33** — Build the arm64 app and DMG from the exact
  release-candidate commit on the designated Apple Silicon release host.
- [x] **REL140-34** — Run the packaged-app tests and the supported browser
  matrix before signing.
- [x] **REL140-35** — Apply Developer ID signing, notarize the DMG, staple the
  ticket, and pass Gatekeeper verification.
- [x] **REL140-36** — Compute the final DMG SHA-256 after stapling and record it
  in the release notes.
- [x] **REL140-37** — Upload the final DMG to the draft GitHub release,
  download it again, verify its checksum and launch behavior, then create
  `v1.4.0-macos`.
- [x] **REL140-52** — Add a release regression test reproducing that bundled
  PowerShell passed pre-sign verification but failed to create CoreCLR after
  Developer ID Hardened Runtime signing.
- [x] **REL140-53** — Sign the bundled `pwsh` executable with the four standard
  .NET Hardened Runtime exceptions while keeping executable entitlements off
  bundled libraries and the Swift host.
- [x] **REL140-54** — Exercise Hardened Runtime in ad-hoc macOS package tests,
  rerun bundled-runtime verification after signing, and pass the targeted and
  full macOS Pester suites.

macOS artifact evidence (2026-08-14 UTC): the Apple Silicon DMG was built from
macOS packaging fix commit `3775569`, accepted under Apple notarization
submission `9bc674e2-ea84-4205-9b26-92a5a188b098`, stapled, and accepted by
Gatekeeper. Its final SHA-256 is
`a01922afa0fe5f1de4a6aed2f1dfca3da2556171bce8f98e5d3df9c449e2ef49`.
The private GitHub draft copy downloaded with the same checksum and passed
quarantine, signature, staple, mounted-app, bundled PowerShell 7.6.3, and
offline Chrome math-render checks. Safari 26.5.2 then loaded HTML generated by
the exact packaged engine, processed all ten converter-emitted math nodes,
loaded the local KaTeX font, preserved readable malformed TeX, escaped
currency, and inline code, followed fragment navigation, and retained rendered
math across a theme toggle with no network resources observed. Gatekeeper and
the stapled ticket were revalidated afterward. `v1.4.0-macos` records the
packaging-fix commit. The Safari portion of REL140-34 ran against the final
signed artifact after signing because remote automation was enabled during the
final release gate; no source or package rebuild occurred afterward.

## G.6 Snap Store Release

- [x] **REL140-38** — Build the core24 amd64 Snap from the exact
  release-candidate commit on Ubuntu 24.04.
- [x] **REL140-39** — Build the core24 arm64 Snap from the same commit on an
  arm64 Ubuntu 24.04 host.
- [x] **REL140-40** — Inspect both Snaps for version, confinement, architecture,
  launchers, runtime, KaTeX contents, and absence of build-only material.
- [x] **REL140-41** — Upload both architectures to `latest/edge` with temporary
  release credentials.
- [x] **REL140-42** — Install from edge on matching hardware and verify desktop
  integration, launch paths, offline math, themes, fallback, accessibility,
  and non-math regressions.
- [x] **REL140-43** — Promote the verified revisions to `latest/stable` and
  confirm both architectures, public metadata, and install behavior.
- [x] **REL140-44** — Revoke/delete temporary credentials and create
  `v1.4.0-linux` only after stable is verified.

Linux publication evidence (2026-08-14 UTC): Snap Store stable and edge both
serve amd64 revision 4 and arm64 revision 3 from release-candidate commit
`c29ac9c`. Strict installs on matching hardware reported 1.4.0 and bundled
PowerShell 7.6.3. The math fixture produced ten converter math nodes, loaded
the content-addressed KaTeX JavaScript, CSS, and 60 font files with a
no-network CSP, and typeset correctly in strictly confined Firefox. The
temporary release credential was deleted after stable verification, and
`v1.4.0-linux` records the build commit.

## G.7 Coordinated Publication and Closeout

Recommended sequencing:

1. Submit Windows first because Store certification has the longest external
   lead time.
2. While Windows is in certification, build and verify the final macOS DMG and
   Snap edge candidates from the same release-candidate commit.
3. Promote Snap and publish the DMG only after their packaged-app smoke tests
   pass.
4. Verify the Windows Store listing and installed package when certification
   and publication complete.
5. Publish the canonical GitHub routing release and tag only after every public
   channel is verified.

- [ ] **REL140-45** — Verify the public Windows Store package, macOS DMG, and
  amd64/arm64 Snap all report the intended 1.4.0 release and render the math
  fixture correctly.
- [x] **REL140-46** — Update the changelog and release records with actual
  publication dates, Snap revisions, artifact checksum, and any approved
  deviations.
- [x] **REL140-47** — Commit and push final release documentation from a clean
  worktree.
- [ ] **REL140-48** — Create canonical `v1.4.0` at the verified release commit;
  never retarget an existing tag.
- [ ] **REL140-49** — Publish the GitHub 1.4.0 routing release and recheck every
  Store, Snap, DMG, checksum, and documentation link.
- [ ] **REL140-50** — Record final validation evidence, remove local secrets
  and temporary release outputs, and leave the repository clean.

---

## Rollback and Hold Points (Phase G)

| Channel | Hold or rollback action |
|---|---|
| Windows Store | Stop submission before publication or submit a corrected superseding package; never use the locally signed QA artifact for Store submission |
| macOS GitHub DMG | Keep the draft unpublished until notarization and download verification pass; replace only unpublished draft assets |
| Snap Store | Keep candidates in edge until both architectures pass; do not promote a failing revision to stable |
| GitHub release/tags | Keep the release as a draft and do not create platform/canonical tags until the corresponding public channel is verified |

Any source change after the release-candidate SHA is selected invalidates prior
package evidence. Rebuild and rerun the affected platform gates from the new
candidate commit.

---

## Success Criteria (Phase G)

1. All release references are consistent at 1.4.0/1.4.0.0 and the repository is
   clean at the selected release commit.
2. The full automated suite and the remaining Phase F manual browser matrix pass
   on the intended packaged applications.
3. Windows Store x64, macOS arm64 DMG, and Snap amd64/arm64 packages all include
   and render the pinned offline KaTeX bundle.
4. The Windows Store artifact is unsigned; the macOS DMG is signed, notarized,
   stapled, and checksum-verified; both Snap architectures are verified in edge
   before stable promotion.
5. Public Store, Snap, DMG, release-note, checksum, and documentation links are
   verified before canonical `v1.4.0` is created and the GitHub release is
   published.
