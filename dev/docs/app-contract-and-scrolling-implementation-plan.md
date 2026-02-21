# `_fragment` App Contract & Scrolling — Implementation Plan

## Overview

Standardize fragment delivery for `mdview:` protocol links across all platforms using a `_fragment` query parameter. This removes dependence on `#fragment` surviving portal/scheme-handler boundaries and provides a clean, deterministic contract that works for click navigation, paste-in-address-bar, terminal launches, and file associations.

**Design document:** [app-contract-and-scrolling-recommendation.md](app-contract-and-scrolling-recommendation.md)

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

## Phase 1: Encode `_fragment` in `mdview:` Links (script.js)

**File:** `src/core/script.js` — `rewriteMarkdownLinks()` function

### 1.1 Move fragment from `#` to `?_fragment=` in rewritten links

- [ ] 1.1.1 When a local `.md` link has a `#fragment`, strip the hash from the resolved URL and append `?_fragment=<encoded-id>` instead
  - Before: `mdview:file:///path/to/doc.md#section-1`
  - After:  `mdview:file:///path/to/doc.md?_fragment=section-1`
  - Use `encodeURIComponent(url.hash.substring(1))` for encoding
- [ ] 1.1.2 Handle existing query strings: if the resolved `file:` URL already has `?…`, append `&_fragment=…` instead of `?_fragment=…`
- [ ] 1.1.3 If the resolved URL already has a `_fragment` param, overwrite it (single source of truth)
- [ ] 1.1.4 Remove the existing localStorage `click` event listener that stores `mdview_scroll` — no longer needed
- [ ] 1.1.5 Remove the existing localStorage `mdview_scroll` consumer (scroll-on-load block) — replaced by `_fragment` query param scroll

### 1.2 Smoke tests (Pester — script.js content)

- [ ] 1.2.1 Test: `script.js` contains `_fragment` string
- [ ] 1.2.2 Test: `script.js` contains `encodeURIComponent`
- [ ] 1.2.3 Test: `script.js` does NOT contain `localStorage.setItem("mdview_scroll"`

---

## Phase 2: Parse `_fragment` in Open-Markdown.ps1

**File:** `src/core/Open-Markdown.ps1` — URI parsing block

### 2.1 Extract `_fragment` from the query string

Use a cross-platform-safe approach — no `System.Web.HttpUtility` dependency (not guaranteed in all pwsh environments). Use `[Uri]::UnescapeDataString` + simple string parsing.

- [ ] 2.1.1 After stripping the `mdview:` prefix and parsing as `[Uri]`, extract `_fragment` from `$u.Query`:
  ```powershell
  # Parse _fragment from query string (cross-platform safe, no System.Web dependency)
  if ($u.Query -match '[?&]_fragment=([^&#]*)') {
      $frag = '#' + [Uri]::UnescapeDataString($Matches[1])
  }
  ```
- [ ] 2.1.2 Strip the query string from the URI before extracting `$u.LocalPath` (so `Test-Path` sees a clean path). Build a clean URI from scheme + authority + path only.
- [ ] 2.1.3 Remove the existing `$frag = $u.Fragment` fallback — `_fragment` is the only supported transport
- [ ] 2.1.4 Remove the `$hash = $raw.IndexOf('#')` fallback for literal paths with `#` — not a supported contract input

### 2.2 Unit tests (Pester)

These tests validate the _fragment parsing logic extracted from Open-Markdown.ps1's URI handling block.

- [ ] 2.2.1 Test: `mdview:file:///path/doc.md?_fragment=section-1` → `$frag` = `#section-1`, file path = `/path/doc.md`
- [ ] 2.2.2 Test: `mdview:file:///path/doc.md?_fragment=Section%20%231` → `$frag` = `#Section #1` (URL-decoded)
- [ ] 2.2.3 Test: `mdview:file:///C:/docs/spec.md?_fragment=intro` → `$frag` = `#intro`, path = `C:\docs\spec.md` (Windows)
- [ ] 2.2.4 Test: `mdview:file:///path/doc.md` (no fragment at all) → `$frag` = `''`
- [ ] 2.2.5 Test: `mdview:file:///path/doc.md?_fragment=` (empty value) → `$frag` = `''` (ignored)
- [ ] 2.2.6 Test: URI with both `?_fragment=foo` and `#bar` → `_fragment` wins, `#bar` ignored

---

## Phase 3: Deliver Fragment to HTML & Scroll on Load

### 3.1 Open HTML as URL with `_fragment` (Open-Markdown.ps1)

**File:** `src/core/Open-Markdown.ps1` — browser launch block

- [ ] 3.1.1 When `$frag` is non-empty, launch via `Start-DefaultBrowser` with the HTML URL + `?_fragment=<encoded>`:
  ```powershell
  $htmlUrl = $uLocal + '?_fragment=' + [Uri]::EscapeDataString($frag.TrimStart('#'))
  Start-DefaultBrowser -Url $htmlUrl
  ```
  **Critical:** Must use `Start-DefaultBrowser` (URL), not `Start-Process $outLocal` (path), because `?` in a path argument is misinterpreted on Windows.
- [ ] 3.1.2 When `$frag` is empty and on Windows, keep `Start-Process $outLocal` (existing behavior, no change)
- [ ] 3.1.3 When `$frag` is empty and on Linux, keep `Start-DefaultBrowser -Url $uLocal` (existing behavior, no change)

### 3.2 Scroll to `_fragment` on page load (script.js)

**File:** `src/core/script.js`

- [ ] 3.2.1 Read `_fragment` from the HTML page's URL:
  ```js
  var params = new URLSearchParams(window.location.search);
  var scrollTarget = params.get("_fragment");
  ```
- [ ] 3.2.2 After DOM is ready **and after** `fixMismatchedAnchors()` has run, scroll to the element:
  ```js
  if (scrollTarget) {
      var el = document.getElementById(scrollTarget);
      if (el) el.scrollIntoView();
  }
  ```
- [ ] 3.2.3 Add a retry loop (3 attempts, 200ms apart) to handle late DOM injection by highlight.js
- [ ] 3.2.4 After successful scroll, clean the address bar with `history.replaceState`:
  ```js
  var cleanUrl = window.location.pathname;
  history.replaceState(null, "", cleanUrl);
  ```
  This prevents re-scroll on page reload (transient HTML, not bookmarkable).

### 3.3 Smoke tests

- [ ] 3.3.1 Test: `script.js` contains `URLSearchParams`
- [ ] 3.3.2 Test: `script.js` contains `history.replaceState`

---

## Phase 4: Test Suite & Regressions

### 4.1 Run and fix all tests

- [ ] 4.1.1 Run `Invoke-Pester tests -Output Minimal` — all existing tests must pass
- [ ] 4.1.2 Run xUnit host tests if dotnet SDK is available: `dotnet test tests/MarkdownViewerHost.Tests/` (optional — depends on dev environment)
- [ ] 4.1.3 Fix any regressions introduced by the changes

---

## Phase 5: Documentation Updates

### 5.1 Update architecture doc

**File:** `dev/docs/markdown-viewer-architecture.md`

- [ ] 5.1.1 Add a "Fragment Handling (`_fragment` Contract)" section describing the end-to-end flow
- [ ] 5.1.2 Document the contract rules (encoding, decoding, precedence, launch rule)
- [ ] 5.1.3 Update the data-flow / activation diagram (if one exists) to show `_fragment` query-param path
- [ ] 5.1.4 Remove or update any references to `#fragment` being passed through `mdview:` links
- [ ] 5.1.5 Remove or update any references to localStorage-based fragment passing

---

## Phase 6: Snap Rebuild & Manual Verification (Linux)

### 6.1 Rebuild and test

- [ ] 6.1.1 Rebuild snap: `cd installers/linux-snap && ./build.sh arm64`
- [ ] 6.1.2 Install: `sudo snap install output/markview_1.0.0_arm64.snap --dangerous`
- [ ] 6.1.3 Manual test: open a markdown file with TOC links → click a `mdview:` link with fragment → verify scroll to correct section

---

## Implementation Order

1. **Phase 2** (Parse `_fragment` in Open-Markdown.ps1) — server-side first, PowerShell is easily testable with Pester
2. **Phase 1** (Encode `_fragment` in script.js links + remove localStorage) — client-side encoding
3. **Phase 3** (Deliver `_fragment` to HTML + JS scroll-on-load) — wiring end-to-end
4. **Phase 4** (Test suite) — validation
5. **Phase 5** (Documentation) — architecture doc updates
6. **Phase 6** (Snap rebuild) — real-world verification

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

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| `?_fragment` on `file:` URL rejected by browser CSP | `base-uri file:` already allows file: URLs with query strings |
| `_fragment` value contains special chars | `encodeURIComponent` in JS, `[Uri]::EscapeDataString` in PS; consumer URL-decodes once |
| Late DOM (highlighting adds elements after scroll) | Retry loop with setTimeout (3 attempts, 200ms apart) |
| Windows `Start-Process` misinterprets `?` in path | Contract rule: when `_fragment` present, always use `Start-DefaultBrowser` (URL), never `Start-Process` (path) |
| Source URL already has query string | JS checks for existing `?` and uses `&_fragment=` accordingly |
| `System.Web.HttpUtility` not available | Query parsing uses regex + `[Uri]::UnescapeDataString` (both in .NET BCL, always available) |

---

## Success Criteria

1. Clicking a `[link](other.md#section)` in rendered HTML scrolls to `#section` in the target doc
2. Pasting `mdview:file:///path/doc.md?_fragment=section` in a terminal opens and scrolls correctly
3. No-fragment links continue to work (no regression)
4. All Pester tests pass
5. Snap + Firefox on Linux scrolls to correct section
6. Windows ad-hoc install scrolls to correct section
7. Architecture doc reflects the `_fragment` contract
