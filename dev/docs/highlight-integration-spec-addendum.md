# Markdown Viewer: highlight.js Integration Spec — Addendum

This addendum supplements the main specification (`highlight-integration-spec.md`)with implementation details for theme integration, language mapping, error handling, and performance guardrails.

---

## 1. Theme Integration

### 1.1 Problem Statement

The Markdown Viewer uses a CSS variable-based theme system with:
- A `data-theme` attribute on `:root` (`"light"` or `"dark"`)
- A `data-variation` attribute for sub-themes (0–4 for each mode)
- CSS variables (`--bg`, `--fg`, `--codebg`, `--border`, etc.) that change based on these attributes

Stock highlight.js themes are incompatible because they use **hardcoded colors**:

```css
/* Stock highlight.js theme - INCOMPATIBLE */
.hljs {
  background: #ffffff;  /* Hardcoded - ignores --codebg */
  color: #333333;       /* Hardcoded - ignores --fg */
}
.hljs-keyword {
  color: #a71d5d;       /* Hardcoded - same in light and dark */
}
```

If a stock light theme is loaded while the viewer is in dark mode, code blocks will have white backgrounds on a dark page.

### 1.2 Solution: Scoped Theme CSS

Ship a **custom combined theme file** (`highlight-theme.css`) that:

1. Resets `.hljs` background to `transparent` and color to `inherit`
2. Scopes token colors under `:root[data-theme="light"]` and `:root[data-theme="dark"]`
3. Excludes background colors from token rules (only `color`, `font-weight`, `font-style`, `opacity`)

Example structure:

```css
/* Reset - inherit from viewer theme */
pre code.hljs,
code.hljs,
.hljs {
    background: transparent;
    color: inherit;
}

/* Light mode tokens */
:root[data-theme="light"] .hljs-keyword { color: #a71d5d; }
:root[data-theme="light"] .hljs-string { color: #183691; }
/* ... */

/* Dark mode tokens */
:root[data-theme="dark"] .hljs-keyword { color: #ff7b72; }
:root[data-theme="dark"] .hljs-string { color: #a5d6ff; }
/* ... */
```

### 1.3 Theme Converter Tool

A PowerShell script (`Convert-HljsTheme.ps1`) automates generation of the combined theme file.

**Location:** Ship in the repository under `dev/scripts/`.

**Usage:**

```powershell
.\Convert-HljsTheme.ps1 `
  -LightTheme "path/to/tomorrow.css" `
  -DarkTheme "path/to/tomorrow-night.css" `
  -OutputPath "payload/highlight-theme.css"
```
(Sample output `highlight-theme-tomorrow.css` is present in `dev/scripts/`).

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-LightTheme` | Yes | Path to a highlight.js light theme CSS file |
| `-DarkTheme` | Yes | Path to a highlight.js dark theme CSS file |
| `-OutputPath` | Yes | Path for the generated combined CSS file |
| `-LightThemeName` | No | Override theme name in output comments |
| `-DarkThemeName` | No | Override theme name in output comments |

**Behavior:**

1. Parses both input CSS files, extracting all `.hljs` and `.hljs-*` rules
2. Auto-detects theme names from header comments (e.g., `Theme: Tomorrow`)
3. Outputs a combined CSS file with:
   - Reset block (background transparent, color inherit)
   - Light mode section scoped to `:root[data-theme="light"]`
   - Dark mode section scoped to `:root[data-theme="dark"]`
4. Filters token rules to only include: `color`, `font-weight`, `font-style`, `opacity`, `text-decoration`
5. Excludes `background`, `background-color` from token rules

**Recommended theme pairings:**

| Light Theme | Dark Theme | Notes |
|-------------|------------|-------|
| `tomorrow.css` | `tomorrow-night.css` | Good default, balanced colors |
| `github.css` | `github-dark.css` | Familiar to developers |
| `atom-one-light.css` | `atom-one-dark.css` | Popular, high contrast |

### 1.4 Theme Variation Compatibility

The combined theme does **not** need variation-specific rules (e.g., `[data-variation="1"]`). 

Rationale:
- Token colors are foreground-only; they work across variations
- Background comes from `--codebg`, which varies per variation
- Contrast is maintained because variations adjust `--codebg` appropriately

However, after generating the combined theme, **test with all 10 variations** (5 light + 5 dark) to verify readability:
- High Contrast light (variation 4): Ensure token colors are distinct from pure black text
- OLED Black dark (variation 3): Ensure token colors are visible on pure black background
- Sepia light (variation 3): Ensure token colors don't clash with warm tones

If specific variations have contrast issues, add targeted overrides:

```css
/* Example: boost keyword visibility on OLED Black */
:root[data-theme="dark"][data-variation="3"] .hljs-keyword {
    color: #ff8a8a; /* Brighter red for pure black background */
}
```

### 1.5 Asset Installation

The installer must copy `highlight-theme.css` to the install directory alongside other assets:

```
%LOCALAPPDATA%\Programs\MarkdownViewer\
├── Open-Markdown.ps1
├── viewmd.vbs
├── style.css
├── script.js
├── markdown.ico
├── highlight.min.js          ← highlight.js bundle (UMD build)
└── highlight-theme.css       ← generated combined theme
```

### 1.6 HTML Integration

The generated HTML must include both files via `file://` URLs:

```html
<link rel="stylesheet" href="file:///...LOCALAPPDATA.../highlight-theme.css">
<script src="file:///...LOCALAPPDATA.../highlight.min.js" defer></script>
```

**Ordering in `<head>`:**

1. CSP meta tag
2. Viewer `<style nonce="...">` (includes `style.css` content)
3. `<link>` to `highlight-theme.css`
4. `<script src="highlight.min.js" defer>`
5. Viewer `<script nonce="...">` (includes `script.js` content)

The `defer` attribute ensures highlight.js loads without blocking page render.

---

## 2. highlight.js Bundle Requirements

### 2.1 Build Type: UMD/Global Required

The highlight.js bundle **MUST** be the browser/UMD build that exposes `window.hljs` globally.

**Do NOT use:**
- ES module build (`highlight.min.mjs`)
- CommonJS build (`highlight.min.cjs`)
- Any build requiring `import` statements

**Verification:** The shipped file should NOT contain `export` statements. It should define `hljs` on `window` when loaded via `<script>` tag.

**Correct source:** Download from highlight.js CDN or build using:
```bash
# From highlight.js source
node tools/build.js -t browser :common
```

### 2.2 Included Languages

The bundle should include languages commonly found in Markdown documentation. Recommended minimum set:

**Shell/Scripting:**
- bash, powershell, python, ruby, perl

**Web:**
- javascript, typescript, json, xml, html, css

**Systems:**
- c, cpp, csharp, java, go, rust

**Data/Config:**
- yaml, toml, ini, sql

**Markup:**
- markdown, diff

**Other:**
- plaintext (for explicit no-highlighting)

Total: ~30-40 languages, approximately 160-200KB minified.

However, we will start with the full language bundle (minified ~1MB) to see what performance impact that might have. A smaller version can be created later accordingly. `highlight.min.js` file is now available under dev/scripts (a non-minified version of it `highlight.js` is also available in the same location).

### 2.3 Asset URL Stability

**PROHIBITED:** Cache-busting query strings on asset URLs.

```html
<!-- INCORRECT - defeats caching -->
<script src="file:///...highlight.min.js?v=1.2.3" defer></script>

<!-- CORRECT - stable URL for caching -->
<script src="file:///...highlight.min.js" defer></script>
```

**Rationale:** Query strings defeat browser caching. The shared resource optimization relies on identical URLs across all document opens. When multiple tabs load the same `file://` URL, the browser/OS can share cached resources.

**If versioning is needed:** Rename the file itself (e.g., `highlight-v11.min.js`) and update the installer accordingly.

---

## 3. Language Mapping

### 3.1 Problem Statement

`ConvertFrom-Markdown` emits language classes that may differ from highlight.js naming:

| Markdown fence | ConvertFrom-Markdown class | highlight.js expects |
|----------------|---------------------------|---------------------|
| ` ```ps1 ` | `language-ps1` | `language-powershell` |
| ` ```pwsh ` | `language-pwsh` | `language-powershell` |
| ` ```yml ` | `language-yml` | `language-yaml` |
| ` ```sh ` | `language-sh` | `language-bash` |
| ` ```js ` | `language-js` | `language-javascript` |

Without mapping, these blocks won't highlight correctly.

### 3.2 Solution: Data-Driven Language Map

Define the mapping as a JavaScript object at the top of the highlighting IIFE:

```javascript
(function() {
    // Language alias mapping: source class -> highlight.js language name
    // IMPORTANT: All target values MUST exist in hljs.listLanguages() for the shipped bundle
    const LANG_MAP = {
        // PowerShell variants
        'ps1': 'powershell',
        'pwsh': 'powershell',
        'psm1': 'powershell',
        'psd1': 'powershell',
        
        // Shell variants
        'sh': 'bash',
        'shell': 'bash',
        'zsh': 'bash',
        
        // JavaScript/TypeScript variants
        'js': 'javascript',
        'mjs': 'javascript',
        'cjs': 'javascript',
        'ts': 'typescript',
        'tsx': 'typescript',
        'jsx': 'javascript',
        
        // Markup variants
        'yml': 'yaml',
        'md': 'markdown',
        'htm': 'xml',
        'xhtml': 'xml',
        'svg': 'xml',
        
        // Data format variants
        'jsonc': 'json',
        'json5': 'json',
        
        // C-family variants
        'c++': 'cpp',
        'h': 'c',
        'hpp': 'cpp',
        'cc': 'cpp',
        'cxx': 'cpp',
        'cs': 'csharp',
        
        // Other language shortcuts
        'py': 'python',
        'rb': 'ruby',
        'rs': 'rust',
        'kt': 'kotlin',
        'kts': 'kotlin',
        'pl': 'perl',
        'pm': 'perl',
        
        // Build/config files
        'mk': 'makefile',
        'bat': 'dos',
        'cmd': 'dos',
        
        // Plaintext (explicitly no highlighting)
        'text': 'plaintext',
        'txt': 'plaintext',
        'plain': 'plaintext',
        'none': 'plaintext'
    };
    
    // ... rest of highlighting code
})();
```

### 3.3 Build-Time Validation Requirement

**REQUIRED:** At build/test time, validate that all `LANG_MAP` target values exist in the shipped bundle.

```javascript
// Run this validation during build or as a test
function validateLangMap(hljs, langMap) {
    const bundledLangs = new Set(hljs.listLanguages());
    const errors = [];
    
    for (const [alias, target] of Object.entries(langMap)) {
        if (target !== 'plaintext' && !bundledLangs.has(target)) {
            errors.push(`LANG_MAP['${alias}'] -> '${target}' not in bundle`);
        }
    }
    
    if (errors.length > 0) {
        console.error('LANG_MAP validation failed:');
        errors.forEach(e => console.error('  ' + e));
        throw new Error('Invalid LANG_MAP entries');
    }
    
    console.log('LANG_MAP validated: all targets exist in bundle');
}
```

**Rationale:** Prevents silent failures where mapped languages don't exist in the shipped bundle.

### 3.4 Mapping Application

Before calling `hljs.highlightElement()`, normalize the language class:

```javascript
function normalizeLanguage(codeEl) {
    // Extract language from class (language-xxx or lang-xxx)
    const classes = codeEl.className.split(/\s+/);
    for (const cls of classes) {
        const match = cls.match(/^(?:language-|lang-)(.+)$/);
        if (match) {
            const lang = match[1].toLowerCase();
            const mapped = LANG_MAP[lang] || lang;
            
            // Update the class to use mapped language
            codeEl.className = codeEl.className.replace(cls, 'language-' + mapped);
            return mapped;
        }
    }
    return null; // No language class found
}
```

### 3.5 Extensibility

The `LANG_MAP` object is the single source of truth for language aliases. To add new mappings:

1. Add entries to `LANG_MAP`
2. Ensure the target language is included in the highlight.js bundle
3. Re-run build-time validation

Do **not** hardcode mappings elsewhere in the codebase.

### 3.6 Unknown Languages

If a language class exists but isn't in `LANG_MAP` and isn't recognized by highlight.js:

1. Do **not** fall back to auto-detection
2. Leave the block unhighlighted (styled as plaintext via `pre code` CSS)
3. Optionally log to console: `console.debug('Unknown language:', lang)`

---

## 4. Content Security Policy Changes

### 4.1 Required CSP Modifications

To load highlight.js and theme CSS from the install directory, update CSP to include `file:` in `script-src` and `style-src`:

**Before:**
```
script-src 'nonce-<nonce>'
style-src 'nonce-<nonce>'
```

**After:**
```
script-src 'nonce-<nonce>' file:
style-src 'nonce-<nonce>' file:
```

### 4.2 Security Implications

> **⚠️ SECURITY NOTE: This is a deliberate tradeoff.**

Adding `file:` to `script-src` and `style-src` allows **any local JavaScript or CSS file** to execute/load if referenced in the HTML.

**This is acceptable ONLY because:**

1. **Sanitization strips ALL `<script>`, `<link>`, and `<style>` tags** from rendered markdown before the HTML is generated
2. **CSP nonce still blocks inline scripts** without the correct nonce
3. **An attacker would need BOTH:**
   - Bypass sanitization (to inject a `<script src="file://...">` tag)
   - Have a malicious `.js` file already present on the user's disk at a known path

**Mandatory constraint:** The HTML sanitization that removes `<script>`, `<link>`, and `<style>` tags is **NOT optional**. It is a required security layer, not merely defense-in-depth.

**If sanitization is ever:**
- Made optional
- Configurable by the user
- Relaxed to allow certain tags

**Then this CSP change MUST be revisited.**

### 4.3 What Remains Protected

Even with `file:` allowed:

| Attack Vector | Protection |
|---------------|------------|
| Inline `<script>alert(1)</script>` | Blocked by nonce requirement |
| `<script src="https://evil.com/x.js">` | Blocked (https not in script-src) |
| `<script src="file:///path/to/malicious.js">` | Blocked by sanitization (tag stripped) |
| `onclick="alert(1)"` event handlers | Blocked by nonce (inline script) |
| `javascript:` URLs | Blocked by sanitization + nonce |

---

## 5. Error Handling

### 5.1 highlight.js Load Failure

If `highlight.min.js` fails to load (missing file, CSP misconfiguration, corrupt file), the viewer must:

1. Continue rendering markdown without syntax highlighting
2. Not throw errors that break other functionality
3. Log a warning to the console

**Implementation:**

At the start of the highlighting IIFE, check for `hljs`:

```javascript
(function() {
    // Guard: highlight.js not loaded
    if (typeof hljs === 'undefined') {
        console.warn('Markdown Viewer: highlight.js not loaded, syntax highlighting disabled');
        return;
    }
    
    // ... rest of highlighting code
})();
```

### 5.2 Individual Block Failures

If highlighting a specific block throws an error (malformed code, unsupported language edge case):

1. Catch the error
2. Log it with context
3. Leave that block unhighlighted
4. Continue processing remaining blocks

**Implementation:**

```javascript
function highlightBlock(codeEl) {
    try {
        const lang = normalizeLanguage(codeEl);
        if (!lang || lang === 'plaintext') {
            return; // Skip plaintext blocks
        }
        
        hljs.highlightElement(codeEl);
    } catch (err) {
        console.warn('Markdown Viewer: Failed to highlight block', {
            language: codeEl.className,
            error: err.message
        });
        // Block remains unhighlighted - acceptable fallback
    }
}
```

### 5.3 Theme CSS Load Failure

If `highlight-theme.css` fails to load:

1. Code blocks will have no token coloring (all text same color as `--fg`)
2. Blocks remain readable due to `pre code` base styling from viewer CSS
3. No JavaScript error occurs

This is an acceptable degradation. No special handling required.

### 5.4 Prohibited Error Responses

The highlighting code must **never**:

- Throw uncaught exceptions
- Display alert/confirm dialogs for highlighting errors
- Block page rendering
- Retry failed operations in a loop
- Call `hljs.highlightAuto()` as a fallback

---

## 6. Performance Guardrails

### 6.1 Maximum Block Size (Required)

Large code blocks (e.g., minified JavaScript, log dumps, data files) can cause CPU spikes during highlighting.

**Requirement:** Skip highlighting for blocks exceeding a size threshold.

**Default threshold:** 100 KB (102,400 characters)

**Implementation:**

```javascript
const MAX_BLOCK_SIZE = 102400; // 100 KB - REQUIRED

function shouldHighlight(codeEl) {
    if (codeEl.textContent.length > MAX_BLOCK_SIZE) {
        console.debug('Markdown Viewer: Skipping large block', {
            size: codeEl.textContent.length,
            threshold: MAX_BLOCK_SIZE
        });
        return false;
    }
    
    if (!hasLanguageClass(codeEl)) {
        return false;
    }
    
    return true;
}

function hasLanguageClass(codeEl) {
    return /(?:^|\s)(?:language-|lang-)\S+/.test(codeEl.className);
}
```

### 6.2 Maximum Block Count (Required)

Even with per-block size limits, a document with hundreds or thousands of small blocks can cause CPU spikes, especially with many tabs open.

**Requirement:** Limit the number of blocks highlighted per document.

**Default threshold:** 500 blocks

**Implementation:**

```javascript
const MAX_BLOCKS = 500; // REQUIRED

function highlightAllBlocks() {
    const blocks = document.querySelectorAll('pre code[class*="language-"], pre code[class*="lang-"]');
    const toProcess = Math.min(blocks.length, MAX_BLOCKS);
    
    if (blocks.length > MAX_BLOCKS) {
        console.warn('Markdown Viewer: Limiting highlighting to first', MAX_BLOCKS, 'of', blocks.length, 'blocks');
    }
    
    for (let i = 0; i < toProcess; i++) {
        if (shouldHighlight(blocks[i])) {
            highlightBlock(blocks[i]);
        }
    }
}
```

**Rationale:** With 10–100 tabs open, a pathological document with 2000 small code blocks could still cause significant CPU load even if each block is under 100KB.

### 6.3 No Re-Highlighting (Required)

Highlighting must run **exactly once** per page load.

**Implementation:**

```javascript
(function() {
    if (typeof hljs === 'undefined') return;
    
    let highlighted = false;
    
    function runHighlighting() {
        if (highlighted) return;
        highlighted = true;
        
        // ... highlighting logic
    }
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', runHighlighting);
    } else {
        runHighlighting();
    }
})();
```

**Prohibited triggers for re-highlighting:**

- Window resize
- Scroll events
- Theme toggle (light/dark switch)
- Variation change (warm/cool/sepia/etc.)
- Remote images toggle
- Any user interaction

**Rationale:** Theme toggles change colors via CSS variables only. The DOM structure (including highlight.js spans) does not change. Re-highlighting would be wasteful and could cause visible flicker.

### 6.4 Use `defer` for Script Loading (Required)

The HTML must load highlight.js with the `defer` attribute:

```html
<script src="file:///...highlight.min.js" defer></script>
```

**Benefits:**
- Script downloads in parallel with HTML parsing
- Executes after DOM is ready but before `DOMContentLoaded`
- Does not block initial page render
- User sees styled content immediately; highlighting applies shortly after

**Do NOT use:**
- `async` (execution order unpredictable)
- No attribute (blocks parsing)
- `type="module"` (requires ES module build)

---

## 7. Complete JavaScript Reference Implementation

```javascript
/**
 * Markdown Viewer - Syntax Highlighting Module
 * 
 * Requirements:
 * - highlight.js UMD build loaded globally as `window.hljs`
 * - highlight-theme.css loaded (scoped to data-theme attribute)
 * 
 * Behavior:
 * - Highlights code blocks with language-* or lang-* classes
 * - Maps common aliases to highlight.js language names
 * - Skips blocks without language class (no auto-detection)
 * - Skips blocks exceeding size/count thresholds
 * - Runs exactly once per page load
 * - Never throws uncaught exceptions
 */
(function() {
    'use strict';
    
    // ===== CONFIGURATION =====
    
    const MAX_BLOCK_SIZE = 102400; // 100 KB - skip larger blocks
    const MAX_BLOCKS = 500;        // Max blocks to highlight per document
    
    /**
     * Language alias mapping: source class -> highlight.js language name
     * 
     * IMPORTANT: All target values (except 'plaintext') MUST exist in 
     * hljs.listLanguages() for the shipped bundle. Validate at build time.
     */
    const LANG_MAP = {
        // PowerShell variants
        'ps1': 'powershell',
        'pwsh': 'powershell',
        'psm1': 'powershell',
        'psd1': 'powershell',
        
        // Shell variants
        'sh': 'bash',
        'shell': 'bash',
        'zsh': 'bash',
        
        // JavaScript/TypeScript variants
        'js': 'javascript',
        'mjs': 'javascript',
        'cjs': 'javascript',
        'ts': 'typescript',
        'tsx': 'typescript',
        'jsx': 'javascript',
        
        // Markup variants
        'yml': 'yaml',
        'md': 'markdown',
        'htm': 'xml',
        'xhtml': 'xml',
        'svg': 'xml',
        
        // Data format variants
        'jsonc': 'json',
        'json5': 'json',
        
        // C-family variants
        'c++': 'cpp',
        'h': 'c',
        'hpp': 'cpp',
        'cc': 'cpp',
        'cxx': 'cpp',
        'cs': 'csharp',
        
        // Other language shortcuts
        'py': 'python',
        'rb': 'ruby',
        'rs': 'rust',
        'kt': 'kotlin',
        'kts': 'kotlin',
        'pl': 'perl',
        'pm': 'perl',
        
        // Build/config files
        'mk': 'makefile',
        'bat': 'dos',
        'cmd': 'dos',
        
        // Plaintext (explicitly no highlighting)
        'text': 'plaintext',
        'txt': 'plaintext',
        'plain': 'plaintext',
        'none': 'plaintext'
    };
    
    // ===== GUARDS =====
    
    // Guard: highlight.js not loaded
    if (typeof hljs === 'undefined') {
        console.warn('Markdown Viewer: highlight.js not loaded, syntax highlighting disabled');
        return;
    }
    
    // Guard: prevent double execution
    let highlighted = false;
    
    // ===== HELPER FUNCTIONS =====
    
    /**
     * Extract language identifier from element's class list.
     * Looks for language-xxx or lang-xxx patterns.
     * @returns {string|null} Lowercase language identifier or null
     */
    function getLanguageClass(codeEl) {
        const match = codeEl.className.match(/(?:^|\s)(?:language-|lang-)(\S+)/);
        return match ? match[1].toLowerCase() : null;
    }
    
    /**
     * Map language alias to canonical highlight.js name.
     * @returns {string} Canonical name or original if no mapping exists
     */
    function normalizeLanguage(lang) {
        return LANG_MAP[lang] || lang;
    }
    
    /**
     * Determine if a code block should be highlighted.
     * @returns {boolean}
     */
    function shouldHighlight(codeEl) {
        // Must have a language class
        const lang = getLanguageClass(codeEl);
        if (!lang) {
            return false;
        }
        
        // Skip explicit plaintext
        const normalized = normalizeLanguage(lang);
        if (normalized === 'plaintext') {
            return false;
        }
        
        // Skip oversized blocks
        const size = codeEl.textContent.length;
        if (size > MAX_BLOCK_SIZE) {
            console.debug('Markdown Viewer: Skipping large block', {
                language: lang,
                size: size,
                threshold: MAX_BLOCK_SIZE
            });
            return false;
        }
        
        return true;
    }
    
    /**
     * Highlight a single code block.
     * Normalizes language class and applies highlighting.
     * Never throws - catches and logs errors.
     */
    function highlightBlock(codeEl) {
        try {
            const lang = getLanguageClass(codeEl);
            if (!lang) return;
            
            const normalized = normalizeLanguage(lang);
            
            // Update class to normalized language for highlight.js
            codeEl.className = codeEl.className.replace(
                /(?:language-|lang-)\S+/,
                'language-' + normalized
            );
            
            hljs.highlightElement(codeEl);
        } catch (err) {
            console.warn('Markdown Viewer: Failed to highlight block', {
                language: codeEl.className,
                error: err.message
            });
            // Block remains unhighlighted - acceptable fallback
        }
    }
    
    // ===== MAIN FUNCTION =====
    
    /**
     * Main highlighting entry point.
     * Runs once per page load, never re-runs.
     */
    function runHighlighting() {
        // Prevent re-execution
        if (highlighted) return;
        highlighted = true;
        
        // Select only <pre><code> blocks with language classes
        const selector = 'pre code[class*="language-"], pre code[class*="lang-"]';
        const blocks = document.querySelectorAll(selector);
        
        // Apply block count limit
        const count = Math.min(blocks.length, MAX_BLOCKS);
        if (blocks.length > MAX_BLOCKS) {
            console.warn('Markdown Viewer: Limiting highlighting to', MAX_BLOCKS, 'of', blocks.length, 'blocks');
        }
        
        // Highlight eligible blocks
        let highlightedCount = 0;
        for (let i = 0; i < count; i++) {
            if (shouldHighlight(blocks[i])) {
                highlightBlock(blocks[i]);
                highlightedCount++;
            }
        }
        
        console.debug('Markdown Viewer: Highlighted', highlightedCount, 'code blocks');
    }
    
    // ===== INITIALIZATION =====
    
    // Run after DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', runHighlighting);
    } else {
        runHighlighting();
    }
})();
```

---

## 8. Build-Time Validation Script

Include this script in your build/test process to validate the language map:

```javascript
/**
 * Validate LANG_MAP against shipped highlight.js bundle.
 * Run this at build time or as part of test suite.
 * 
 * Usage (Node.js):
 *   node validate-langmap.js
 * 
 * Usage (Browser console with hljs loaded):
 *   validateLangMap(hljs, LANG_MAP);
 */

function validateLangMap(hljs, langMap) {
    const bundledLangs = new Set(hljs.listLanguages());
    const errors = [];
    const warnings = [];
    
    for (const [alias, target] of Object.entries(langMap)) {
        // Skip plaintext - it's a special case
        if (target === 'plaintext') {
            if (!bundledLangs.has('plaintext')) {
                warnings.push(`'plaintext' not in bundle (optional)`);
            }
            continue;
        }
        
        if (!bundledLangs.has(target)) {
            errors.push(`LANG_MAP['${alias}'] -> '${target}' NOT FOUND in bundle`);
        }
    }
    
    // Report results
    if (warnings.length > 0) {
        console.warn('LANG_MAP warnings:');
        warnings.forEach(w => console.warn('  ' + w));
    }
    
    if (errors.length > 0) {
        console.error('LANG_MAP validation FAILED:');
        errors.forEach(e => console.error('  ' + e));
        throw new Error(`Invalid LANG_MAP: ${errors.length} target(s) not in bundle`);
    }
    
    console.log('✓ LANG_MAP validated: all', Object.keys(langMap).length, 'aliases map to valid targets');
    console.log('  Bundle contains', bundledLangs.size, 'languages');
    
    return true;
}

// For Node.js usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { validateLangMap };
}
```

---

## 9. Checklist for Implementer

### highlight.js Bundle
- [ ] Download UMD/browser build (NOT ES module)
- [ ] Verify file does NOT contain `export` statements
- [ ] Verify `window.hljs` is defined when loaded via `<script>`
- [ ] Include required languages (~30-40 common languages)
- [ ] Document exact version and included languages

### Theme Integration
- [ ] Run `Convert-HljsTheme.ps1` with chosen light/dark theme pair
- [ ] Verify output `highlight-theme.css` has no `background` properties in token rules
- [ ] Test combined theme with all 10 viewer variations
- [ ] Add targeted overrides for any contrast issues
- [ ] Update installer to copy `highlight-theme.css` to install directory

### Language Mapping
- [ ] Include `LANG_MAP` object in highlighting JavaScript
- [ ] Run `validateLangMap()` against shipped bundle
- [ ] Fix any mapping errors (targets not in bundle)
- [ ] Test with common fenced code blocks: ps1, js, py, sh, yml, json

### CSP Updates
- [ ] Add `file:` to `script-src` in CSP generation
- [ ] Add `file:` to `style-src` in CSP generation
- [ ] Verify CSP still blocks inline scripts without nonce
- [ ] Verify HTML sanitization still strips `<script>`, `<link>`, `<style>` tags
- [ ] Document security tradeoff in code comments

### Error Handling
- [ ] Verify page renders correctly when `highlight.min.js` is missing
- [ ] Verify page renders correctly when `highlight-theme.css` is missing
- [ ] Test with malformed code block to ensure no uncaught exceptions
- [ ] Verify console warnings appear for load failures

### Performance
- [ ] Verify `defer` attribute on script tag
- [ ] Verify NO cache-busting query strings on asset URLs
- [ ] Test with document containing 100+ code blocks
- [ ] Test with single large code block (>100KB)
- [ ] Verify theme toggle does NOT trigger re-highlighting
- [ ] Verify variation change does NOT trigger re-highlighting
- [ ] Profile CPU usage with 50 tabs open

### Integration Testing
- [ ] Test highlighting with local-only HTML variant
- [ ] Test highlighting with remote-images HTML variant
- [ ] Test with UNC path source file (`\\server\share\doc.md`)
- [ ] Test with extended-length path (`\\?\C:\...`)
- [ ] Verify no regressions in existing features (theme toggle, remote images, mdview: links)
