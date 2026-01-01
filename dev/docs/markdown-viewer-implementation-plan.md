# Markdown Viewer Implementation Plan

## Overview

This document outlines the implementation plan for Markdown Viewer features:
- **Phase A (Complete):** highlight.js syntax highlighting integration
- **Phase B (Current):** MSIX packaging and Host launcher for Microsoft Store distribution

**Key Documents:**
- [markdown-viewer-architecture.md](markdown-viewer-architecture.md) - Architecture overview
- [msix-packaging-and-host-launcher-specification.md](msix-packaging-and-host-launcher-specification.md) - MSIX tech spec
- [msix-activation-matrix.md](msix-activation-matrix.md) - Activation behavior contract

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
