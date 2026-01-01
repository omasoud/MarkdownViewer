## 1) Overall assessment of what you have now

* **MSIX manifest**: Correct shape for a full-trust packaged desktop app: `Windows.FullTrustApplication` entry point, executable points at `MarkdownViewerHost.exe`, file-type associations for `.md`/`.markdown`, protocol `mdview:`, and `runFullTrust`.   
* **Host app**: Correct type and “thin host” posture: `WinExe` (no console), launches bundled `pwsh\pwsh.exe` and `app\Open-Markdown.ps1` relative to install location.  
* **One key gap**: the host still assumes “activation == command-line args” and exits silently when launched without args.  This needs to be replaced with proper packaged activation handling + a UX landing path.

Everything below is the actionable worklist to get to “clean MSIX (x64 + ARM64), bundled pwsh, WAP project build, automated signing, and a usable ‘launch from Start’ experience”.

---

## 2) Actionable steps (detailed)

### A. Repo / folder structure adjustments (to support both MSIX + ad-hoc)

1. **Introduce a platform-oriented layout**

   * Keep “core engine” (PowerShell + JS/CSS + highlight bundle) in one canonical place (e.g., `src/core/` or `payload/`), and have both installers *consume* it.
   * Keep the MSIX packaging material under `installers/win-msix/`.
   * Keep the ad-hoc installer under `installers/win-adhoc/` (or leave current root scripts but treat them as that installer).

2. **Define the packaged runtime layout contract**

   * Your host currently expects:

     * `pwsh\pwsh.exe`
     * `app\Open-Markdown.ps1`

   * Lock this in as the MSIX package internal layout and ensure the staging step always materializes it exactly.

---

### B. Windows Application Packaging Project (WAP) setup (x64 + ARM64 only)

3. **Reduce supported platforms to x64 + ARM64**

   * Your template solution currently includes `Any CPU`, `ARM`, `ARM64`, `x64`, `x86`. 
   * Remove `x86`, `ARM`, and `Any CPU` from the packaging project configurations/build pipeline.
   * Ensure the WAP project produces:

     * `x64` package
     * `ARM64` package
     * optionally an `.msixbundle` containing both (preferred for Store submission)

4. **Ensure manifest architecture is not “stuck”**

   * Your current Identity is explicitly `ProcessorArchitecture="x64"`. 
   * For multi-arch output, ensure each architecture build produces the correct architecture manifest (WAP can do this per-configuration). Do not ship an ARM64 build with an `x64` Identity.

5. **Confirm file associations + protocol are declared in the manifest**

   * `.md` and `.markdown` association are already present. 
   * `mdview:` protocol is already present. 
   * Keep these in the final `Package.appxmanifest` that WAP uses.

---

### C. Host launcher implementation requirements (packaged activation, not argv-only)

6. **Implement activation handling via `AppInstance.GetActivatedEventArgs()`**

   * Replace the “loop over `args[]`” approach. 
   * Required behaviors:

     * **File activation** (double-click `.md` / Open With): extract file path/token, pass the real filesystem path to `Open-Markdown.ps1 -Path`.
     * **Protocol activation** (`mdview:` links): extract the full URI (including fragment), pass it to `Open-Markdown.ps1 -Path`.
     * **Multi-activation**: each activation should result in launching the engine once per target (stateless host policy).
   * Keep: **no duplicate UI** in the host for file-open errors (engine owns error dialogs).

7. **Keep host as a minimal Windows GUI subsystem app**

   * Your csproj is already `OutputType=WinExe`. 
   * Keep it “thin”:

     * Parse activation
     * Resolve packaged paths
     * Launch `pwsh` with structured argument list
     * Exit immediately

8. **Harden the host/engine contract**

   * The manifest executable is `MarkdownViewerHost.exe`. 
   * The host build output name must match this exactly.
   * Keep engine invocation stable: `-File <enginePath> -Path <pathOrUri>` (you already do structured argument passing). 

---

### D. Bundled PowerShell strategy (no trimming, pinned version, scripted download)

9. **Select a pinned pwsh version and download sources**

   * Decide a single pinned PowerShell version for the MSIX line (e.g., `7.x.y`), and download **two** archives:

     * Windows x64
     * Windows ARM64
   * For each:

     * Download in staging step
     * Verify integrity (SHA256 against a known hash file you commit or a release-provided checksum)
     * Extract into the staged package folder at `pwsh\...`

10. **Bundle “everything” initially**

* No trimming for now (per your direction).
* The only requirement is that the bundled runtime supports what your engine uses: `ConvertFrom-Markdown`, WinForms TaskDialog usage, filesystem, crypto RNG, etc.

---

### E. MSIX payload staging step (PowerShell) + pack/sign step (WAP/MSBuild)

11. **Create/standardize a staging step that produces a deterministic package layout**

* For **each architecture**:

  * Clean staging output directory
  * Copy host build output into staging root
  * Copy engine payload into `app\` (Open-Markdown.ps1 + all required assets)
  * Copy pwsh runtime into `pwsh\`
  * Copy MSIX assets (`Assets\*.png`)
* Ensure the MSIX manifest’s `Executable="MarkdownViewerHost.exe"` remains valid relative to package root. 

12. **Use WAP/MSBuild as the pack/sign step**

* Treat WAP/MSBuild as the authoritative packager.
* Your staging step’s job is only to ensure all bits exist where WAP expects them.

The **`.wapproj`** should be placed under:

* `installers/win-msix/`

Reason: the WAP project is part of the **Windows packaging mechanism**, not core app logic. Keeping it under `installers/win-msix/` cleanly separates:

* `src/core/` (cross-platform engine + assets)
* `src/host/` (Windows host EXE source)
* `installers/win-msix/` (MSIX packaging: `.wapproj`, `Package.appxmanifest`, Assets, MSBuild targets/scripts)

Recommended layout:

```
installers/
  win-msix/
    MarkdownViewer.wapproj
    Package.appxmanifest
    Assets/
    build/
      stage.ps1           # downloads pwsh, generates png assets, copies payload into staging
      Directory.Build.targets  # hook staging into MSBuild
```
(The `.wapproj` can be added to the top level `MarkdownViewer.slnx`)

Keep any staging/downloading/icon-generation logic either:

* in `stage.ps1` invoked by MSBuild pre-build, or
* in MSBuild targets under the same folder (but still owned by the packaging layer).

The current `installers/win-msix/Package` will no longer be needed and should be removed.

A dummy set of files has been placed here for reference:
```
installers/win-msix/WapProjTemplate1.wapproj
installers/win-msix/Images
installers/win-msix/Package.appxmanifest
```

---

### F. Automate icon generation (from your `.ico`) into required MSIX assets

13. **Automate generation of the WAP “Assets” PNG set**

* Your assets README already defines required files and sizes and suggests tooling.  
* Decide on one build-time dependency:

  * ImageMagick available on build machine/CI, or
  * a small checked-in generator tool, or
  * a PowerShell/.NET image pipeline in the staging script
* Generate at minimum:

  * `Square44x44Logo.png`
  * `Square150x150Logo.png`
  * `Wide310x150Logo.png`
  * `StoreLogo.png`

* Optionally generate the scale-* variants listed. 

---

### G. Signing automation (dev self-signed + future Store)

14. **Dev signing: fully automate what you did manually**

* Automate:

  * Create/find a dev code-sign cert in `CurrentUser`
  * Ensure it is trusted for local install testing (appropriate store)
  * Configure WAP build to sign using that cert (preferred), or post-sign output (acceptable for dev)
* Keep the signing material out of source control (pfx, passwords, thumbprints).

15. **Store signing: document the switch**

* Store submission will re-sign; ensure your pipeline can produce the expected Store upload artifact without relying on the dev cert.

---

### H. UX enhancement: launching the app directly (no args)

16. **Define “no activation target” behavior**

* When the host is launched from Start Menu with no file/protocol:

  * Show a simple “How to use Markdown Viewer” experience instead of exiting silently.
* Requirements:

  * Explain: “Use Open With on a .md file” and/or “set as default for .md/.markdown”.
  * Provide a one-click action to open Windows Default Apps settings (host-triggered deep link).
  * Do not require pwsh for this UX path (it should still work even if the engine fails).

17. **Guide user to set default app**

* Text should mention the app name shown in Default Apps UI (“Markdown Viewer” per manifest).  
* Mention that `.md` and `.markdown` are supported. 

---

### I. Verification / test plan (must pass before Store submission)

18. **Functional tests**

* Double-click `.md` opens via file association.
* Links inside rendered HTML to other local markdown open via `mdview:` rewriting (you already have link rewriting logic in JS). 
* In-page `#fragment` links work (your anchor rewrite IIFE). 
* Remote-images toggle only appears when remote images exist and uses the two-HTML-variants approach. 
* Theme toggle reflects System vs Invert and label updates. 

19. **Architecture tests**

* x64 MSIX installs and runs on x64.
* ARM64 MSIX installs and runs on ARM64.
* If you ship a bundle: correct package is selected per device architecture.

20. **Security regression tests**

* MOTW warning gate still triggers for Internet-downloaded markdown.
* Sanitization and CSP remain effective (no script execution from markdown).
* Remote images are blocked by default and only enabled after explicit user choice.

---

## 3) “Anything important remaining?”

Yes—these are the important remaining items for the MSIX effort:

* **Switch host from argv-only to real packaged activation (`AppInstance.GetActivatedEventArgs()`)** (required for correctness and future-proofing). 
* **Define and implement the “no-args UX”** so launching the app directly is self-explanatory (and supports guiding to Default Apps settings).
* **Make the build deterministic for two architectures** (staging produces correct pwsh + assets per arch; WAP produces x64 + ARM64 outputs).  
* **Automate signing for dev** (so test installs are one command, not manual signtool invocations).
* **Automate asset generation from `.ico`** so the package always has correct icons. 
* **App name** should be easy to set/change and `developer-guide.md` should explain how to update it. This is because the app name will eventually depend on MS Store app name availability.
