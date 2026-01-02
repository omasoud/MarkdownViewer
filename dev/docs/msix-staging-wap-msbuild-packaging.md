### MSIX staging + WAP/MSBuild packaging (detailed design)

This section defines how we will replace `build.ps1` with a **repeatable MSBuild-driven pipeline** using a **Windows Application Packaging Project** (`.wapproj`) as the authoritative packager, while still keeping a **PowerShell staging step** to assemble the package contents (payload + bundled PowerShell + icons) in a deterministic way.

---

## What we are trying to accomplish

We want a build that:

1. Produces **MSIX (or MSIXBundle)** for **x64 and ARM64**.
2. Uses the **WAP project** (`.wapproj`) to:

   * build the MSIX package(s)
   * apply the `Package.appxmanifest`
   * include Store/MSIX metadata and Assets
   * perform (optional) signing as part of build
3. Uses a single **staging step** (PowerShell) to:

   * download and unpack the pinned **pwsh** runtime for the target architecture
   * generate the required MSIX Assets from the canonical `.ico`
   * copy the app payload (`Open-Markdown.ps1`, `script.js`, `style.css`, highlight bundle, icons, etc.)
   * ensure the resulting layout matches what the host expects (e.g., `pwsh\pwsh.exe`, `app\Open-Markdown.ps1`)
4. Avoids having two packaging systems in parallel.

   * The WAP project becomes the *only* packager.
   * The staging script becomes the *only* place where “what files go into the package and where” is defined.
   * `build.ps1` becomes unnecessary and is removed once the MSBuild+staging flow is complete.

---

## Why we need staging even with a WAP project

A WAP project can package an EXE and content files, but it does not, by itself, solve:

* **Bundling PowerShell 7 per-architecture** (x64 vs ARM64) via scripted download/unpack.
* **Automatically generating the MSIX Asset PNGs** from a source `.ico`.
* **Copying and arranging a “composed payload”** (host output + core scripts + JS/CSS + highlight bundle) into a predictable on-disk layout that your host/engine assumes.

So the split of responsibilities is:

* **Staging (PowerShell)**: prepare the exact files and folder layout to be packaged.
* **WAP/MSBuild**: produce the MSIX from that prepared layout and optionally sign it.

---

## Where things live in the repo

The WAP project is part of the Windows packaging layer, so it should live under `installers/win-msix/`.

Recommended layout:

```
installers/
  win-msix/
    MarkdownViewer.wapproj
    Package.appxmanifest
    Assets/                      # generated PNGs live here (committed or generated)
    build/
      stage.ps1                  # authoritative staging logic
      Directory.Build.targets     # wires stage.ps1 into MSBuild
      pwsh.version.txt           # pinned version (and optionally URLs + SHA256s)
```

* `src/core/` remains the canonical source of the engine and runtime assets.
* `src/host/` remains the canonical source of the host EXE.
* The WAP project references the host EXE project and packages the staged payload.

You can add `installers/win-msix/MarkdownViewer.wapproj` to your top-level solution (`MarkdownViewer.slnx`) so a single solution build can drive everything.

---

## How the pipeline will work (end-to-end)

### Step 1: Build host (per architecture)

MSBuild builds/publishes the host EXE for the requested platform (x64 or ARM64).

* Output: `MarkdownViewerHost.exe` and any required host dependencies.

### Step 2: Stage payload (per architecture) — `stage.ps1`

Before packaging occurs, MSBuild invokes `build/stage.ps1` with:

* `-Configuration` (Debug/Release)
* `-Platform` (x64/ARM64)
* paths to:

  * host build output directory
  * core payload directory (`src/core`)
  * the packaging project working directories
  * a staging output directory (unique per arch/config)

**What staging does (authoritative file composition):**

For the given `Platform`:

1. **Clean staging directory**

   * Ensures no stale runtime or assets persist between builds.

2. **Copy host output into staging root**

   * Ensures the packaged `Executable="MarkdownViewerHost.exe"` will be valid relative to package root.

3. **Copy engine payload into `app\`**

   * `Open-Markdown.ps1`
   * `script.js`
   * `style.css`
   * `highlight.min.js`
   * `highlight-theme.css`
   * any required icons/templates/HTML fragments used by the engine

4. **Download and unpack bundled pwsh into `pwsh\`**

   * Uses a pinned version and per-arch download URL.
   * Verifies integrity (SHA256) before unpacking.
   * Ensures `pwsh\pwsh.exe` exists at the expected path for this architecture.

5. **Generate/update MSIX Assets**

   * Uses your canonical `.ico` (or a pair of ICOs if you keep light/dark variants).
   * Generates required PNGs into the location the WAP project expects (`Assets\...png` or the staging Assets directory, depending on how you ensure they’re included).
   * Ensures the manifest references are satisfied.

6. **Validate staging output**

   * Hard fail if any required file is missing:

     * `MarkdownViewerHost.exe`
     * `app\Open-Markdown.ps1`
     * `pwsh\pwsh.exe`
     * key assets referenced by `Package.appxmanifest`
   * This prevents producing a “valid” MSIX that can’t run.

**Output of staging:**
A fully composed folder tree that is ready for packaging.

### Step 3: Package and sign — WAP/MSBuild

After staging succeeds, the WAP project packages from that staged layout.

* MSBuild/WAP produces:

  * `MarkdownViewer_..._x64.msix`
  * `MarkdownViewer_..._arm64.msix`
  * optionally `MarkdownViewer.msixbundle` if you choose bundle output

**Signing:**

* In development: can be automated using a self-signed cert (see below).
* In Store distribution: Store signs the submission; dev signing remains useful for local testing and CI artifacts.

---

## How MSBuild “hooks” staging into the WAP build

We want staging to run automatically when you build the WAP project, so you can do:

* Build → produces MSIX
* No manual running of scripts

Implementation approach:

* Put a `Directory.Build.targets` under `installers/win-msix/build/` (or `installers/win-msix/` if you want it to apply broadly).
* Add an MSBuild target that runs **before** the packaging step (pre-packaging).
* That target invokes `pwsh` or Windows PowerShell to run `stage.ps1` with the correct parameters.

Key characteristics of the hook:

* Runs once per target architecture build.
* Uses MSBuild properties for `$(Platform)`, `$(Configuration)`, output paths, etc.
* Writes staging output into a known directory that the WAP project packages from.

---

## What happens to `installers/win-msix/Package`

With this approach, `installers/win-msix/Package` as a manually maintained staging tree is no longer needed.

Instead:

* staging output becomes an **MSBuild-generated directory** (e.g., `installers/win-msix/obj/Staging/...` or `installers/win-msix/build/out/...`).
* the WAP project packages from that directory.

So yes: **remove `installers/win-msix/Package`** once staging is wired in and the build is verified end-to-end.

---

## Development signing automation (self-signed)

The build should support “one command produces an installable MSIX” in dev.

Minimum dev flow:

1. If no suitable dev cert exists, create one (like your current `New-SelfSignedCertificate ...`).
2. Sign the produced MSIX using `signtool sign ...`.
3. Optionally install it for smoke testing.

This can be integrated as:

* a post-build MSBuild target in the WAP project, or
* a separate `sign.ps1` invoked by MSBuild after packaging.

Success criteria for signing automation:

* On a clean dev machine, a single build command produces a signed MSIX that installs without manual signtool steps.

---

## UX success criteria (launching the app with no file)

This packaging pipeline must also support a coherent UX when the user launches the app from Start:

* If activated **without a file and without a protocol URI**, the host must show a “how to use” surface.
* That surface must:

  * tell the user to open a `.md` file via “Open with”
  * provide a direct action to open Windows Default Apps settings and guide the user to set Markdown Viewer as default for `.md`/`.markdown`

This is part of “done” because it improves discoverability and reduces support friction.

---

## Success criteria (definition of done)

The migration from `build.ps1` to WAP/MSBuild + staging is successful when:

1. **Single build entrypoint**

   * Building the WAP project (from VS or CLI) produces MSIX for x64 and ARM64 (or an MSIXBundle containing both).

2. **No manual staging**

   * No one manually copies files into a `Package` folder.
   * All staging is performed by `stage.ps1` invoked by MSBuild.

3. **Deterministic layout**

   * The packaged app always contains:

     * `MarkdownViewerHost.exe` at the expected executable location
     * `app\Open-Markdown.ps1`
     * `pwsh\pwsh.exe`
   * The host can reliably find and launch the engine for both x64 and ARM64.

4. **Deterministic runtime**

   * Bundled pwsh version is pinned and downloaded in a scripted way.
   * Staging validates the runtime is present and correct.

5. **Deterministic assets**

   * MSIX Assets are generated from `.ico` and satisfy manifest references.
   * No missing logos/tile images during install or in Start menu.

6. **Signing is automated**

   * Dev build can produce a signed MSIX without manual signtool commands.

7. **Functional behaviors validated**

   * File activation works (double-click `.md`, `.markdown`)
   * Protocol activation works (`mdview:`)
   * Launch-with-no-args shows the help/default-app guidance

Once these criteria are met, `build.ps1` is obsolete and can be removed (or retained only as a legacy/manual packaging helper, but not part of the supported flow).
