# MSIX Activation Matrix and Host↔PowerShell Contract

## Purpose

Define the runtime activation behaviors for the MSIX-installed **Markdown Viewer** and the exact contract between the **signed host EXE** and the **PowerShell engine** (`Open-Markdown.ps1`) executed via **bundled** PowerShell 7 (`pwsh.exe`).

This document is intended to be implementable without ambiguity.

---

## Terms

* **Host**: the packaged, signed executable (e.g., `MarkdownViewerHost.exe`) that is registered in `AppxManifest.xml` for file associations and protocol activation.
* **Engine**: the PowerShell entry script `Open-Markdown.ps1` that performs all rendering, security checks, HTML generation, and browser launching.
* **Bundled pwsh**: PowerShell 7 runtime shipped inside the MSIX and invoked by the host (never system `pwsh`).

---

## Design Principles

1. **Host stays minimal**

   * Activation handling + argument normalization + safe process launch + no console window.
2. **Engine owns all logic**

   * URI/path parsing, security gates (MOTW), sanitization, CSP, HTML generation, link rewriting, browser launching, error dialogs.
3. **Structured argument passing**

   * No command-line string concatenation. Host passes a deterministic argument list.
4. **No writes to package install directory**

   * MSIX install location is read-only. All generated artifacts go to user-writable locations (e.g., `%TEMP%`).

---

## Activation Modes

### A. File activation (double-click `.md` / `.markdown`)

**User trigger**

* Double-click a `.md` or `.markdown` file in Explorer
* Or open from any file picker that uses file association

**OS activation**

* Packaged file activation containing one or more file items.

**Host responsibilities**

* For each file item:

  * Resolve to an **absolute filesystem path** (drive path, UNC path, extended-length path).
  * Launch Engine via bundled pwsh using the Host↔Engine contract (see below).
* Preferred behavior for multi-file activation:

  * **Launch once per file** (simple, predictable).

**User-visible outcome**

* The file opens rendered in the browser (new tab/window according to browser behavior).

---

### B. Protocol activation (`mdview:`)

**User trigger**

* Click a rewritten link inside the browser-rendered HTML that uses the custom protocol:

  * `mdview:file:///.../other.md`
  * `mdview:file:///.../other.md#section`

**OS activation**

* Packaged protocol activation with a URI value.

**Host responsibilities**

* Obtain the protocol URI as a string and pass it to the Engine **without lossy transformation**.
* Preserve the fragment (`#...`) exactly.
* Do not attempt to “fix” decoding/encoding unless you explicitly decide the Host owns URI decoding. (Default: Engine owns decoding.)

**User-visible outcome**

* The linked markdown file opens rendered in the browser.
* If a fragment is present, the rendered page navigates to the section (via existing JS anchor logic).

---

### C. “Open with…” picker

**User trigger**

* Right-click a `.md` file → “Open with…” → select Markdown Viewer.

**OS activation**

* Typically delivered as file activation (same as A).

**Host responsibilities**

* Treat exactly like file activation.

**User-visible outcome**

* Same as file activation.

---

## Multi-instance Policy

### Policy: “Stateless host; each activation spawns pwsh and exits” (recommended)

**Rationale**

* Minimal host logic and highest reliability.
* Scales naturally with many opens and aligns with current behavior (VBS → pwsh → browser).
* Avoids a resident process and activation redirection complexity.

**Requirements**

* Host must start Engine promptly and exit.
* Concurrency is allowed: multiple activations can run simultaneously.

---

## Host ↔ Engine Contract

### Canonical invocation rules

The Host must invoke:

* **Bundled** `pwsh.exe` (within the MSIX package)
* **Packaged** `Open-Markdown.ps1` (within the MSIX package)

The Host must pass arguments as an **argument list** (structured) and must not build a single concatenated shell command string.

### Engine parameter contract

The Host passes exactly one input parameter:

#### Contract Form 1: local file path

* Parameter: `-Path`
* Value: absolute filesystem path to the markdown file
  Examples:

  * `C:\Docs\readme.md`
  * `\\server\share\notes.md`
  * `\\?\C:\VeryLongPath\file.md`

#### Contract Form 2: protocol URI

* Parameter: `-Path` (or `-Uri` if you choose to add a dedicated parameter; pick one and keep it permanent)
* Value: full `mdview:` URI including fragment if present
  Examples:

  * `mdview:file:///C:/Docs/other.md`
  * `mdview:file:///C:/Docs/other.md#part-6-authentication-methods`

> Recommended: keep a single `-Path` parameter and allow it to accept either a filesystem path or an `mdview:` URI, since the Engine already supports both.

### Host must not

* Re-encode, decode, normalize, or strip fragments from protocol URIs in a way that changes meaning.
* Attempt to render markdown or implement security logic.
* Write files under the MSIX install directory.
* Depend on system `pwsh` (PATH / Store-installed) in MSIX mode.

---

## Error Handling Contract

### Missing target file (e.g., link points to non-existent `other.md`)

**Preferred behavior**

* Host forwards activation to Engine; Engine is responsible for producing a friendly error dialog (“link not found” / “file not found”) and exiting.

**Host requirement**

* Do not suppress or swallow Engine failures.
* Host should not present duplicate dialogs if Engine already has standardized TaskDialog-based error presentation.

### Invalid protocol URI

* Host passes raw URI string; Engine owns validation and user-facing errors.

---

## Acceptance Criteria

### File activation

* Double-click `.md` opens the markdown rendered (not plain text).
* Works for:

  * local drive paths
  * UNC share paths
  * long path variants (if encountered)

### Protocol activation

* Clicking an in-document link to another markdown file opens it rendered via `mdview:`.
* Fragment links (`other.md#section`) preserve the fragment and navigate correctly after render.

### Open with

* Selecting Markdown Viewer from “Open with…” behaves the same as double-click.

### Multi-open behavior

* Opening many markdown files (10–100) results in the browser opening many tabs/windows without host instability.
* Host does not remain resident; each activation is independent.

### No console flash

* No visible console window appears during activation.

---

## Notes on Manifest Requirements (informational)

* MSIX `AppxManifest.xml` must declare:

  * File type associations for `.md` and `.markdown`
  * Protocol association for `mdview`
* The manifest must point to the Host EXE as the entry point for these activations.

(Manifest details are defined elsewhere; this doc defines runtime behavior.)

---

## Packaging Requirement (Bundled pwsh)

* The MSIX package includes a PowerShell 7 runtime sufficient for `pwsh.exe` to run `Open-Markdown.ps1` and for `ConvertFrom-Markdown` to function as expected.
* Initial implementation should bundle the full/standard distribution for reliability; trimming is explicitly deferred.
