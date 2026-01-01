# MSIX Packaging and Host Launcher Specification (Markdown Viewer)

## References

* **Activation behavior and Host↔Engine contract:** `dev/docs/msix-activation-matrix.md`
  This document defines *what must happen* for each activation mode and the canonical argument contract between the Host EXE and `Open-Markdown.ps1`. This spec builds on it and defines *how to implement it* in an MSIX-ready architecture without changing the core PowerShell-based operation.

---

## 1. Goals

### 1.1 Primary goals

1. Deliver a **Microsoft Store–compatible MSIX** for Markdown Viewer.
2. Preserve the existing operational model:

   * **All rendering/security logic remains in PowerShell** (`Open-Markdown.ps1`).
   * The browser continues to display generated HTML written to a user-writable location (e.g., `%TEMP%`).
3. Introduce a **minimal signed Host EXE** required by MSIX for:

   * file associations (`.md`, `.markdown`)
   * protocol activation (`mdview:`)
4. Bundle **PowerShell 7 (`pwsh`)** inside the MSIX for deterministic behavior (no external dependency).
5. Keep the current **ad-hoc install route** as a supported alternative path.

### 1.2 Non-goals

* Rewriting the viewer engine in C#/C++/WebView.
* Relying on “Store PowerShell as a dependency.”
* Remote markdown fetching.
* Replacing the current browser-based UI model.

---

## 2. Repository Structure

The repository must separate:

* **App payload** (cross-platform engine + assets)
* **Windows-specific launchers**
* **Install/packaging mechanisms** (ad-hoc vs MSIX)

### 2.1 Target layout (authoritative)

```
MarkdownViewer/
  README.md
  LICENSE
  THIRD-PARTY-LICENSES.md
  .gitignore
  dev/
    docs/
      msix-activation-matrix.md
      msix-packaging-and-host-launcher-specification.md   # this document
    scripts/

  src/
    core/                             # cross-platform engine + shared assets
      Open-Markdown.ps1
      script.js
      style.css
      highlight.min.js
      highlight-theme.css
      icons/
        markdown.ico
        markdown-light.ico

    win/                              # Windows-specific glue / modules
      MarkdownViewer.psm1             # if still used by ad-hoc route
      viewmd.vbs                      # ad-hoc-only launcher (optional)
      uninstall.vbs                   # ad-hoc-only helper (optional)

    host/                             # Windows Host EXE source
      MarkdownViewerHost/             # .NET project
        (C# source, project files)

  installers/
    win-adhoc/
      INSTALL.cmd
      UNINSTALL.cmd
      install.ps1
      uninstall.ps1

    win-msix/
      Package/                        # staging root for MSIX build
        AppxManifest.xml              # templated/generated
        Assets/                       # MSIX tile/logo assets (required sizes)
      build.ps1                       # produces MSIX/MSIXBundle
      sign.ps1                        # optional for sideload
      tooling/                        # optional helpers (manifest templating, etc.)

  tests/
    MarkdownViewer.Tests.ps1
    highlight-test.md
    test-bug-fix.md
    theme-variation-test.md
```

### 2.2 Notes

* `src/core` is the “shipping payload.” It must be usable by:

  * MSIX packaging
  * ad-hoc install
  * future macOS/Linux wrappers
* `src/host` is Windows-only and exists to satisfy MSIX executable entry requirements.
* `installers/win-msix` must not contain core logic; it stages and packages artifacts from `src/*`.

---

## 3. Host Application

### 3.1 Host stack

* **.NET 10** application.
* Project type: **minimal Win32-style executable** built as a **Windows GUI subsystem app** (no console window), with no WPF/WinForms dependency.
* Purpose: activation handling + safe process launch only.

### 3.2 Required Windows packaging/activation API

The Host must use the Windows packaged-app activation mechanism:

* Use **Windows App SDK AppLifecycle** to obtain activation payload via:

  * `AppInstance.GetActivatedEventArgs()`

This is required to robustly distinguish activation kinds (file vs protocol) in packaged contexts.

### 3.3 Host responsibilities (must)

Per `dev/docs/msix-activation-matrix.md`, the Host must:

1. **Receive activation** through packaged activation APIs:

   * File activation: `.md`, `.markdown`
   * Protocol activation: `mdview:`
2. **Normalize activation input** into a single string passed to the Engine:

   * File activation → absolute filesystem path
   * Protocol activation → full `mdview:` URI string including fragment
3. **Locate packaged engine and runtime paths**

   * Determine package install base (via Host executable location at runtime).
   * Derive paths to:

     * bundled `pwsh.exe`
     * `Open-Markdown.ps1`
4. **Launch bundled pwsh** with structured arguments (no command-string concatenation).
5. **Hide windows**

   * The Host must not display a console window.
   * The launched `pwsh` process must not show a console window.
6. **Exit immediately** after launching `pwsh` (stateless host policy).

### 3.4 Host must not

* Parse markdown.
* Render HTML.
* Implement CSP/sanitization/MOTW logic.
* Write to the MSIX install directory.
* Attempt to “fix up” or strip fragments from protocol URIs.
* Depend on system `pwsh`.

---

## 4. Engine (PowerShell) Responsibilities

`src/core/Open-Markdown.ps1` remains the canonical engine. It must continue to own:

* Path/URI parsing (including `mdview:` protocol decoding and fragment handling).
* Security checks:

  * MOTW detection and warning gate
  * HTML sanitization (defense-in-depth)
  * CSP with nonce
* HTML generation into user-writable temp files.
* Browser launching and navigation.
* UI behavior (theme toggle, remote images toggle, anchor rewrite).
* Shared highlighting asset usage (highlight.js loaded from stable local file URIs).

No core logic should be moved to the Host beyond activation normalization and safe launching.

---

## 5. Host ↔ Engine Contract

This contract is defined in `dev/docs/msix-activation-matrix.md` and must be implemented exactly.

### 5.1 Input contract

The Host passes exactly one input parameter to the engine:

* **File activation**

  * `-Path <absolute filesystem path>`
* **Protocol activation**

  * `-Path <full mdview: URI including fragment>`

### 5.2 Structured argument passing requirement

The Host must pass parameters as a structured argument list to `pwsh` (not a single concatenated command line). This is required for correctness and to avoid argument injection/quoting bugs.

### 5.3 Engine path resolution requirement

The Host must invoke the packaged `Open-Markdown.ps1` by an explicit absolute path derived from the package install layout.

---

## 6. MSIX Packaging

### 6.1 Package contents

The MSIX must include:

1. **Host executable**

   * `MarkdownViewerHost.exe` (signed as part of package signing flow)
2. **Bundled PowerShell runtime**

   * `pwsh.exe` and all required runtime files/modules needed for:

     * PowerShell startup
     * `ConvertFrom-Markdown`
     * any .NET assemblies used by the engine (TaskDialog usage occurs inside PS)
3. **Engine payload**

   * `Open-Markdown.ps1`
   * UI assets (`script.js`, `style.css`)
   * highlight assets (`highlight.min.js`, `highlight-theme.css`)
   * icons used by the engine (favicons, etc.)

### 6.2 Package internal layout (normative)

Within the MSIX staging root (`installers/win-msix/Package`), the packaged layout must be deterministic so the Host can locate resources relative to itself. Example policy:

* Host EXE at package root (or a known folder).
* A dedicated payload folder inside the package (e.g., `payload\` or `app\`) containing:

  * engine scripts
  * shared assets
  * bundled pwsh (either inside `payload\pwsh\` or another known folder)

The exact folder names are not critical, but **must be stable** and documented, because the Host will compute absolute paths from them at runtime.

### 6.3 Manifest declarations (required)

The `AppxManifest.xml` must declare:

1. **File associations**

   * `.md`
   * `.markdown`
   * Display name and icons appropriate for default-app UI.
2. **Protocol association**

   * `mdview:` protocol mapped to this app.
3. **Execution entry point**

   * The Host EXE must be the registered entry point for both file and protocol activation.

### 6.4 Default app experience

* The MSIX must present a clear identity in Windows “Default apps” UI:

  * name, publisher, icon assets
* No registry hacking is used in MSIX mode; associations are managed through the manifest.

---

## 7. Bundled PowerShell Strategy

### 7.1 Baseline approach (required for initial MSIX)

Bundle the standard PowerShell 7 distribution for Windows (the “full” runtime) to avoid missing-module surprises.

### 7.2 Update policy

* PowerShell security updates are delivered by **publishing an updated MSIX** (or MSIXBundle) containing the new runtime.
* The MSIX build pipeline must make updating the bundled pwsh version a routine step.

### 7.3 “Trimmed pwsh” (explicitly deferred)

A trimmed runtime is allowed only after:

* baseline MSIX is stable
* a repeatable validation suite exists (see Test Plan)

---

## 8. Highlight.js Integration Constraints (MSIX implications)

The engine already implements shared-resource loading of highlighting assets.

### 8.1 Asset referencing

* Generated HTML (in `%TEMP%`) must reference highlight assets as **external local files**, not inline.
* This enables caching across many open documents.

### 8.2 CSP requirement

The engine’s CSP must continue to allow local file resources needed for shared assets:

* `script-src` must allow:

  * nonce for inline viewer JS
  * `file:` for shared highlight bundle
* `style-src` must allow:

  * nonce for inline viewer CSS (if still inline)
  * `file:` for shared highlight theme CSS

### 8.3 Performance requirement

The viewer must avoid code auto-detection:

* Highlight only when a language class is present.
* Enforce block-count and/or block-size guardrails as already specified in the highlighting integration plan.

---

## 9. Ad-hoc Installer Compatibility

The existing ad-hoc install route remains supported:

* `installers/win-adhoc/*` continues to:

  * install payload to a per-user location
  * optionally register context menu
  * optionally set default app (via user-driven settings, not hash tampering)
  * ensure external `pwsh` availability via winget/store (ad-hoc only)

MSIX route does not use ad-hoc registry registration.

---

## 10. Build and Release Requirements

### 10.1 Outputs

* **MSIX artifact** suitable for:

  * sideload testing (signed with dev cert)
  * Store submission (Store signing handled by Microsoft at distribution time)
* Ad-hoc installer artifacts remain unchanged.

### 10.2 Signing

* For sideload:

  * package must be signed with a certificate trusted by the target machine(s)
* For Store:

  * follow Store submission signing requirements (Store re-signing is standard)

---

## 11. Test Plan (Acceptance)

### 11.1 Activation tests (must match `msix-activation-matrix.md`)

1. File activation:

   * double-click `.md` and `.markdown`
   * local drive path
   * UNC path (`\\server\share\file.md`)
2. Protocol activation:

   * `mdview:` link from within rendered HTML
   * fragment preservation (`other.md#section`)
3. Open-with:

   * open a `.md` via “Open with…”

### 11.2 Behavioral tests

* No console flash from Host or pwsh.
* Host exits immediately after launching pwsh.
* Engine writes only to user-writable locations.
* Theme and remote image toggles persist per document (browser storage/localStorage).
* Highlight assets are shared (not embedded) and function across many simultaneous opens.

### 11.3 Stress tests

* Open 10–100 markdown files rapidly:

  * verify acceptable performance
  * verify browser caching works (no per-document highlight bundle duplication in temp HTML)

### 11.4 Security regression tests

* MOTW warning gate triggers for downloaded files with Zone.Identifier.
* CSP blocks inline scripts from markdown content (nonce enforcement).
* Sanitization pass removes dangerous tags and event handlers as previously agreed.
* Remote images remain blocked by default and only enabled via explicit toggle + confirmation.

---

## 12. Implementation Checklist (normative)

1. Implement Host EXE:

   * .NET 10 GUI-subsystem executable
     * Set host output to GUI subsystem (so no console flash) by setting project output type to WinExe in the project file (this avoids needing WPF/WinForms just to hide the console
   * uses `AppInstance.GetActivatedEventArgs()` to extract activation inputs
     * Target a Windows TFM and add the Windows App SDK package
   * maps each activation mode to the contract in `msix-activation-matrix.md`
   * launches bundled pwsh with structured args and exits
2. MSIX packaging:

   * stage Host + bundled pwsh + `src/core` payload into package layout
   * define manifest file associations and protocol association
   * include required MSIX visual assets/icons
3. Validate engine under packaged execution:

   * confirm path resolution for shared assets works from WindowsApps install location
   * confirm temp HTML references to `file:` resources function with CSP
4. Run acceptance suite above.

---

## 13. Future Platform Notes (non-blocking)

* The PowerShell engine in `src/core` is the cross-platform core.
* macOS/Linux will likely use platform-native launchers/registration mechanisms:

  * macOS `.app` wrapper or Swift stub + `pwsh`
  * Linux `.desktop` entry + MIME associations + `pwsh`
* This MSIX work should not introduce Windows-only assumptions into `src/core` beyond what already exists (browser behavior and file URIs).

---
