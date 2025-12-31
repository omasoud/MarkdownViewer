# highlight.js Integration Implementation Plan

## Overview

This document outlines the implementation plan for the highlight.js syntax highlighting feature as specified in:
- [highlight-integration-spec.md](highlight-integration-spec.md)
- [highlight-integration-spec-addendum.md](highlight-integration-spec-addendum.md)

**Key Goals:**
- Shared local assets (not inlined into HTML) for efficient multi-tab usage
- No auto-detection (class-only highlighting to avoid CPU spikes)
- Theme integration with existing light/dark/variation system
- Strict CSP maintained with `file:` addition for local scripts/styles

---

## Phase 1: Asset Preparation

### 1.1 Generate Combined Theme CSS

**File:** `payload/highlight-theme.css` (new)

- [x] 1.1.1 Copy `dev/scripts/highlight-theme-tomorrow.css` to `payload/highlight-theme.css`
- [x] 1.1.2 Verify CSS contains reset block with `background: transparent`
- [x] 1.1.3 Verify CSS contains `:root[data-theme="light"]` scoped rules
- [x] 1.1.4 Verify CSS contains `:root[data-theme="dark"]` scoped rules

### 1.2 Prepare highlight.js Bundle

**File:** `payload/highlight.min.js` (new)

- [x] 1.2.1 Copy `dev/scripts/highlight.min.js` to `payload/highlight.min.js`
- [x] 1.2.2 Verify bundle is UMD build (defines `window.hljs`)

---

## Phase 2: CSP and HTML Infrastructure

### 2.1 Update CSP Generation

**File:** `payload/Open-Markdown.ps1`

**Changes to `New-Csp` function:**
- [x] 2.1.1 Add `file:` to `style-src` directive: `"style-src 'nonce-$nonce' file:"`
- [x] 2.1.2 Add `file:` to `script-src` directive: `"script-src 'nonce-$nonce' file:"`
- [x] 2.1.3 Add comment documenting security tradeoff (sanitization strips all script/link/style tags)

### 2.2 Add Asset Path Handling

**File:** `payload/Open-Markdown.ps1`

**Changes:**
- [x] 2.2.1 Add `$HighlightJsPath` variable with default `(Join-Path $PSScriptRoot 'highlight.min.js')`
- [x] 2.2.2 Add `$HighlightThemePath` variable with default `(Join-Path $PSScriptRoot 'highlight-theme.css')`
- [x] 2.2.3 Generate `file:///` URLs for both assets using Uri class
- [x] 2.2.4 Check if asset files exist before including references

### 2.3 Update HTML Template

**File:** `payload/Open-Markdown.ps1`

**Changes to `Write-Doc` function:**
- [x] 2.3.1 Add `<link rel="stylesheet" href="$highlightThemeUri">` after nonce'd style block
- [x] 2.3.2 Add `<script src="$highlightJsUri" defer></script>` before nonce'd script
- [x] 2.3.3 Only include highlight assets if both files exist (graceful degradation)
- [x] 2.3.4 Ensure NO query strings on asset URLs (breaks caching)

**Expected HTML structure (within `<head>/<body>`):**
```html
<style nonce="...">/* viewer CSS */</style>
<link rel="stylesheet" href="file:///...highlight-theme.css">
</head>
<body>
...
<script src="file:///...highlight.min.js" defer></script>
<script nonce="...">/* viewer JS */</script>
```

---

## Phase 3: JavaScript Highlighting Module

### 3.1 Create Highlighting IIFE

**File:** `payload/script.js`

**Add new IIFE at end of file:**
- [x] 3.1.1 Add configuration constants: `MAX_BLOCK_SIZE = 102400`, `MAX_BLOCKS = 500`
- [x] 3.1.2 Add `LANG_MAP` object with all alias mappings from spec (30+ entries)
- [x] 3.1.3 Add guard: check `typeof hljs === 'undefined'` and return early with console.warn
- [x] 3.1.4 Add `highlighted = false` flag to prevent re-execution

### 3.2 Helper Functions

**File:** `payload/script.js`

- [x] 3.2.1 Implement `getLanguageClass(codeEl)` - extracts language from class list
- [x] 3.2.2 Implement `normalizeLanguage(lang)` - maps alias via LANG_MAP
- [x] 3.2.3 Implement `shouldHighlight(codeEl)` - checks language class, size limit, plaintext
- [x] 3.2.4 Implement `highlightBlock(codeEl)` - normalizes class, calls hljs.highlightElement in try/catch

### 3.3 Main Function

**File:** `payload/script.js`

- [x] 3.3.1 Implement `runHighlighting()` with block count limit
- [x] 3.3.2 Use selector `'pre code[class*="language-"], pre code[class*="lang-"]'`
- [x] 3.3.3 Add console.debug for highlighting summary
- [x] 3.3.4 Add console.warn when block count exceeds MAX_BLOCKS
- [x] 3.3.5 Handle DOMContentLoaded vs already-loaded document

---

## Phase 4: Installer/Uninstaller Updates

### 4.1 Update Installer

**File:** `install.ps1`

- [x] 4.1.1 Add `Copy-Item` for `highlight.min.js` in `Copy-Payload` function
- [x] 4.1.2 Add `Copy-Item` for `highlight-theme.css` in `Copy-Payload` function
- [x] 4.1.3 Add both files to `$files` array in `Set-ReadOnlyAcl` function

### 4.2 Update Uninstaller

**File:** `uninstall.ps1`

- [x] 4.2.1 Verify existing `Remove-Item -Recurse` on install directory removes all files (likely no changes needed)

---

## Phase 5: Unit Tests

### 5.1 CSP Tests

**File:** `tests/MarkdownViewer.Tests.ps1`

- [x] 5.1.1 Test: New-Csp returns CSP with `file:` in script-src
- [x] 5.1.2 Test: New-Csp returns CSP with `file:` in style-src
- [x] 5.1.3 Test: CSP does NOT contain `https:` in script-src
- [x] 5.1.4 Test: CSP does NOT contain `'unsafe-inline'` in script-src

### 5.2 Asset File Tests

**File:** `tests/MarkdownViewer.Tests.ps1`

- [x] 5.2.1 Test: highlight.min.js exists in payload directory
- [x] 5.2.2 Test: highlight-theme.css exists in payload directory
- [x] 5.2.3 Test: highlight-theme.css contains `.hljs { background: transparent`
- [x] 5.2.4 Test: highlight-theme.css contains `:root[data-theme="light"]` rules
- [x] 5.2.5 Test: highlight-theme.css contains `:root[data-theme="dark"]` rules

### 5.3 JavaScript Module Tests

**File:** `tests/MarkdownViewer.Tests.ps1`

- [x] 5.3.1 Test: script.js contains `LANG_MAP` object
- [x] 5.3.2 Test: script.js contains guard for `hljs === 'undefined'`
- [x] 5.3.3 Test: script.js contains `MAX_BLOCK_SIZE` constant (102400)
- [x] 5.3.4 Test: script.js contains `MAX_BLOCKS` constant (500)
- [x] 5.3.5 Test: script.js does NOT contain `highlightAuto`
- [x] 5.3.6 Test: LANG_MAP contains PowerShell aliases (ps1, pwsh, psm1, psd1 → powershell)
- [x] 5.3.7 Test: LANG_MAP contains shell aliases (sh, shell, zsh → bash)
- [x] 5.3.8 Test: LANG_MAP contains JS aliases (js, ts, jsx, tsx)
- [x] 5.3.9 Test: LANG_MAP contains yml → yaml mapping
- [x] 5.3.10 Test: LANG_MAP contains plaintext mappings (text, txt, plain, none)

### 5.4 Installer Tests

**File:** `tests/MarkdownViewer.Tests.ps1`

- [x] 5.4.1 Test: install.ps1 contains Copy-Item for highlight.min.js
- [x] 5.4.2 Test: install.ps1 contains Copy-Item for highlight-theme.css

---

## Phase 6: Documentation Updates

### 6.1 Update README.md

**File:** `README.md`

- [x] 6.1.1 Add section on syntax highlighting feature
- [x] 6.1.2 Document that highlighting requires language tag in fence (e.g., \`\`\`powershell)
- [x] 6.1.3 List commonly supported languages

### 6.2 Update Architecture Documentation

**File:** `dev/docs/markdown-viewer-architecture.md`

- [x] 6.2.1 Add highlight.js to component diagram
- [x] 6.2.2 Update file structure to include highlight.min.js and highlight-theme.css
- [x] 6.2.3 Document CSP changes (`file:` in script-src/style-src)
- [x] 6.2.4 Add highlight.js to Dependencies section
- [x] 6.2.5 Document security tradeoff in Security Architecture section

---

## Phase 7: Manual Testing

### 7.1 Functional Testing

- [x] 7.1.1 Create `tests/highlight-test.md` with various fenced code blocks
- [ ] 7.1.2 Test: PowerShell code blocks (`ps1`, `pwsh`, `powershell`) highlight correctly
- [ ] 7.1.3 Test: JavaScript/TypeScript code blocks highlight correctly
- [ ] 7.1.4 Test: Python, JSON, YAML, Bash code blocks highlight correctly
- [ ] 7.1.5 Test: Code blocks without language class remain unhighlighted (no CPU spike)
- [ ] 7.1.6 Test: Inline code (single backticks) is NOT block-highlighted
- [ ] 7.1.7 Test: Unknown language code blocks remain readable (styled as plaintext)

### 7.2 Theme Variation Testing

- [ ] 7.2.1 Test: Highlighting colors correct in Light Default (variation 0)
- [ ] 7.2.2 Test: Highlighting colors correct in Light Warm (variation 1)
- [ ] 7.2.3 Test: Highlighting colors correct in Light Cool (variation 2)
- [ ] 7.2.4 Test: Highlighting colors correct in Light Sepia (variation 3)
- [ ] 7.2.5 Test: Highlighting colors correct in Light High Contrast (variation 4)
- [ ] 7.2.6 Test: Highlighting colors correct in Dark Default (variation 0)
- [ ] 7.2.7 Test: Highlighting colors correct in Dark Warm (variation 1)
- [ ] 7.2.8 Test: Highlighting colors correct in Dark Cool (variation 2)
- [ ] 7.2.9 Test: Highlighting colors correct in Dark OLED Black (variation 3)
- [ ] 7.2.10 Test: Highlighting colors correct in Dark Dimmed (variation 4)

### 7.3 Error Handling Testing

- [ ] 7.3.1 Test: Page renders when highlight.min.js is missing (graceful degradation)
- [ ] 7.3.2 Test: Page renders when highlight-theme.css is missing
- [ ] 7.3.3 Test: Console shows warning when highlight.js fails to load
- [ ] 7.3.4 Test: Theme toggle does NOT trigger re-highlighting
- [ ] 7.3.5 Test: Variation change does NOT trigger re-highlighting

### 7.4 Performance Testing

- [ ] 7.4.1 Test: Document with 100+ small code blocks highlights without significant delay
- [ ] 7.4.2 Test: Large code block (>100KB) is skipped with console.debug message
- [ ] 7.4.3 Test: Console shows warning when block count exceeds 500

### 7.5 Path Testing

- [ ] 7.5.1 Test: Highlighting works with local drive path (C:\...)
- [ ] 7.5.2 Test: Highlighting works with UNC path (\\\\server\\share\\...)

---

## Implementation Order

1. **Phase 1** (Asset Preparation) - Copy files to payload directory
2. **Phase 2** (CSP and HTML) - Foundation for loading assets
3. **Phase 3** (JavaScript Module) - Core highlighting logic
4. **Phase 5** (Unit Tests) - Validate implementation
5. **Phase 4** (Installer Updates) - Production deployment
6. **Phase 6** (Documentation) - User-facing docs
7. **Phase 7** (Manual Testing) - End-to-end validation

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| CSP blocks highlight.js | Verify `file:` in script-src before testing |
| highlight.js version incompatibility | Ship tested version, document in architecture |
| Theme contrast issues | Test all 10 variations, add overrides as needed |
| Performance with many tabs | Use defer, no auto-detect, block limits |
| Breaking existing functionality | Run full test suite after each phase |

---

## Security Notes

**Security Tradeoff:** Adding `file:` to `script-src` and `style-src` allows any local JavaScript or CSS file to execute/load if referenced in the HTML.

**Why this is acceptable:**
1. HTML sanitization strips ALL `<script>`, `<link>`, and `<style>` tags from markdown before HTML generation
2. CSP nonce still blocks inline scripts without the correct nonce
3. An attacker would need BOTH: bypass sanitization AND have a malicious .js file already on user's disk

**Mandatory constraint:** HTML sanitization is a REQUIRED security layer, not optional defense-in-depth.

---

## Rollback Plan

If critical issues are found post-release:
1. Revert CSP changes (remove `file:` from script-src/style-src)
2. Remove highlight asset references from HTML template
3. Keep highlight.js IIFE in script.js (will no-op without hljs global)
4. Users will see unstyled code blocks (acceptable fallback)
