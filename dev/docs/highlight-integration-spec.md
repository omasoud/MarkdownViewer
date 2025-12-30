# Markdown Viewer: Shared highlight.js Integration Spec

## Goal

Add syntax highlighting for fenced code blocks using **highlight.js** while ensuring **shared resources across many simultaneously open documents (10–100)**.

Key objectives:

* Avoid per-document duplication of the highlight.js bundle (disk + memory overhead).
* Keep rendering fast and predictable for repeated opens.
* Preserve existing security posture (CSP+nonce, local-only by default, optional remote images).
* Avoid language auto-detection to prevent CPU spikes and mis-highlighting.

Non-goals:

* Remote markdown fetching.
* Per-language on-demand loading (single bundle only).
* Full HTML sanitization correctness beyond the existing defense-in-depth layer.

---

## High-level design

### Assets

Ship highlight.js as **shared local assets** installed once per user:

* `highlight.bundle.min.js` (single bundle, includes desired languages)
* `highlight.theme.css` (one theme)
* Optionally `highlight.patch.css` (viewer-specific overrides for inline code vs code blocks)

Install location:

* Under the app install dir (recommended):
  `%LOCALAPPDATA%\Programs\MarkdownViewer\assets\highlight\...`

The generated HTML (temp files) **must not inline** highlight.js content. It must reference the shared file(s).

### Execution model

On document load:

1. Viewer script identifies `<pre><code>` blocks.
2. For each block:

   * If a language class exists (`language-xxx` or `lang-xxx`), highlight using that language.
   * If no language class exists, leave unhighlighted (or apply a minimal “plaintext” styling only).
3. Apply minimal post-processing to correct any class-name mapping differences (e.g., `language-pwsh` → `language-powershell`).

**Absolute avoidance:** auto-detection across many blocks.

---

## CSP requirements

### Current posture

You already use a strict CSP with a nonce, and inline script/style are controlled via:

* `script-src 'nonce-<nonce>'`
* `style-src 'nonce-<nonce>'`
* `default-src 'none'`, etc.

### New CSP requirements (shared script + shared CSS)

To load shared resources from disk, CSP must allow `file:` as a source for scripts and styles.

Update CSP directives (local variant and remote-images variant) to:

* `script-src 'nonce-<nonce>' file:`
* `style-src  'nonce-<nonce>' file:`

Rationale:

* Keep nonce for inline viewer JS initialization/config.
* Permit external local JS/CSS resources via `file:` URLs.

Constraints:

* Do **not** allow `https:` in `script-src` or `style-src`.
* Do **not** add `'unsafe-inline'` for scripts.
* Do **not** add broad wildcards.

### `img-src` unchanged

Continue to keep privacy-by-default:

* Local variant: `img-src file: data:`
* Remote-images variant: `img-src file: data: https:` (or allowlisted domains if implemented)

No change required for highlight.js integration.

---

## Generated HTML changes

### Shared asset references

The generated HTML must include:

* `<link rel="stylesheet" href="file:///.../highlight.theme.css">`
* `<script src="file:///.../highlight.bundle.min.js"></script>`

These must point to the installed per-user asset path.

Ordering:

1. Viewer CSS (nonce’d inline or viewer external) loads first.
2. highlight theme CSS loads next (or before, depending on desired precedence).
3. highlight.js script loads before viewer script that calls highlighting.
4. Viewer nonce’d script runs after highlight.js is available.

### Avoid bundling highlight.js into nonce’d script

Do **not** embed highlight.js code into the nonce’d `<script>` block. That defeats the shared-resource goal.

### `window.mdviewer_config` contract

Continue setting `window.mdviewer_config` from PowerShell and only once. Extend config to include:

* `highlightEnabled` (boolean)
* `highlightMode` (string, expected value: `"class-only"`)
* `highlightAssetVersion` (string; optional, helps cache busting if needed)

Do not include paths to highlight assets in config; the HTML references are authoritative.

---

## Viewer JavaScript changes (runtime behavior)

### Highlight triggering

Highlight must run after:

* DOM is ready
* the markdown HTML is present
* any link rewrites that modify anchors or `mdview:` conversions are complete (order not critical for highlighting, but consistent sequencing is preferred)

### Language selection rule (mandatory)

The viewer must highlight a code block only when:

* the `<code>` element includes a language indicator class, e.g.:

  * `language-powershell`
  * `language-python`
  * `language-json`
* or the `<pre>`/`code` includes a known metadata attribute that maps to a language.

If no language class is present:

* Do not call auto-detection.
* Either leave it as plaintext with block styling only, or tag as `language-plaintext` (if your bundle includes plaintext).

### Class normalization/mapping

ConvertFrom-Markdown language classes can differ from highlight.js naming. Implement a deterministic mapping stage before highlighting, for example:

* `language-ps1`, `language-pwsh` → `language-powershell`
* `language-yml` → `language-yaml`
* `language-shell` → `language-bash` (only if that matches your expectations)
* `language-sh` → `language-bash` or `language-shell` depending on bundle support

Rules:

* Mapping must be one-way and stable.
* Mapping must not fall back to auto-detect.

### Avoid repeated work

With 10–100 tabs, also avoid repeated highlighting runs on the same DOM:

* Run highlighting once per page load.
* Do not re-run in response to scroll/resize/theme toggles.
* If your theme toggle changes colors via CSS variables, highlighting should not need reruns.

### Failure mode

If highlight.js fails to load (missing file, CSP misconfigured), the viewer must:

* continue to render markdown without highlighting
* optionally log a console warning, but avoid intrusive dialogs

---

## Installer changes

### Install assets

Installer must place highlight.js bundle and theme CSS in a stable per-user directory alongside existing app files.

Requirements:

* Directory must be deterministic for linking.
* Ensure filenames do not collide and can be versioned if needed.

### Install-time verification

Installer should verify:

* Assets exist after copy.
* File paths can be converted to valid `file:///...` URIs.
* No admin rights required.

### Uninstaller

Uninstaller must remove:

* highlight assets directory
* any protocol registration (already in scope for `mdview:` feature)
* registry entries related to the app

---

## Performance requirements

### Resource sharing expectations

When using `<script src="file:...">` and `<link href="file:...">`:

* Browsers will cache the shared files; repeated opens should primarily reuse cached bytes.
* Each tab will still maintain its own DOM + runtime state, but the JS payload is not duplicated in the HTML file itself.

### Avoid CPU spikes

Hard requirements:

* Do not use `highlightAll()` if it triggers auto-detection or scans broadly without language classes.
* Do not call `highlightElement` on blocks lacking a known class.
* Do not call `highlightAuto`.

Optional guardrails:

* Cap the number of blocks highlighted per document (configurable) if you anticipate huge documents.
* Cap maximum code block length processed (e.g., skip highlighting for blocks > N KB), to avoid worst-case CPU.

---

## Security requirements

Maintain existing security properties:

* CSP remains strict; scripts only from nonce and local file sources.
* No network access reintroduced through highlighting.
* Sanitization stays in place (defense-in-depth), but the system must not rely on sanitization correctness for script safety.

New security constraints:

* Do not loosen CSP beyond adding `file:` to `script-src`/`style-src`.
* Do not load highlight assets from CDN.
* Do not allow `eval` or similar constructs (avoid any highlight.js build/plugins that require it).

---

## Compatibility requirements

### Supported path types

Asset linking must work regardless of source markdown location:

* local drive paths (`C:\...`)
* UNC shares (`\\server\share\...`)
* extended-length paths (`\\?\C:\...`, `\\?\UNC\...`)

The highlight.js asset paths themselves will be local (`%LOCALAPPDATA%...`) and must be converted to valid `file:///...` URLs.

### Browser support

Expect Chromium-based browsers (Edge/Chrome). Implementation must not depend on features that require insecure flags or extensions.

---

## Test plan (acceptance)

### Functional

* Fenced code blocks with ` ```powershell ` highlight correctly.
* Inline code remains styled as inline, not block-highlighted.
* Documents with no language fences remain readable and do not trigger heavy CPU usage.

### Performance

* Open 50–100 markdown documents; observe:

  * no exponential slowdown
  * no significant per-tab delay attributable to repeated JS parsing beyond what the browser already does
  * acceptable UI responsiveness

### Security

* CSP violations expected only for:

  * remote images in local mode
  * blocked scripts in malicious markdown
* highlight assets load successfully under CSP in both local and remote-images variants.

---

## Implementation constraints (absolute)

Must avoid:

* Inlining highlight.js into generated HTML.
* Auto-detection (`highlightAuto`, “no-class highlightAll” behavior).
* Loading highlight assets from any network location.
* Expanding CSP to allow broad script/style sources (`https:`, `*`, `'unsafe-inline'` for scripts).

Must ensure:

* `script-src` and `style-src` include `file:` in addition to the nonce.
* Highlighting runs exactly once per document load.
* Language mapping is deterministic and does not fall back to detection.
