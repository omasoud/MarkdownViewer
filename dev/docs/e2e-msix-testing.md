# Build tests that catch packaged-layout and MSIX activation issues

## Deliverable A — Extend the staged payload test slightly (low cost, immediate wins)

**Goal:** catch packaged-layout path-resolution bugs *without* needing a full MSIX install.

1. In `Test-StagedPayload.ps1`, add a new step: **simulate the “host-in-subfolder” case**.

   * Create a temp directory.
   * Copy the staged payload into it.
   * Move/copy `MarkdownViewerHost.exe` into a subfolder (example: `temp\MarkdownViewerHost\MarkdownViewerHost.exe`) while keeping `temp\app\...` and `temp\pwsh\...` at the parent.
   * Run the host EXE from that subfolder with a dummy argument (file path and protocol URI), and verify it successfully finds `..\pwsh\pwsh.exe` and `..\app\Open-Markdown.ps1`.

2. To make verification deterministic, add a **test mode signal**:

   * Host: if env var `MDV_TEST_SIGNAL_PATH` is set, write a JSON line like `{ kind, arg, resolvedPwsh, resolvedEngine }` to that path and exit **without launching pwsh**.
   * Then the PowerShell test asserts that the resolved paths match the expected parent-root layout.

This catches a large class of “works in staging root, fails when packaged moves the host”.

## Deliverable B — Add a true MSIX end-to-end activation test (the one that catches the “missed requirements”)

**Goal:** install the MSIX, trigger activations the way Windows does, and assert behavior on disk/logs.

### B1) Prereqs / environment

Run this in a **Windows 11 VM/runner** configured as close to customer machines as possible:

* No Visual Studio
* No Windows App SDK runtime installed (or at least assert it isn’t present)
* .NET Framework 4.8.1+ available (Win11 typically has a suitable baseline; still verify)
* Ability to install a test-signed MSIX (dev cert installed or trusted)

### B2) Build + package

Create a script `Test-PackagedActivation.ps1` that:

1. Builds Release.
2. Runs the staging test (`Test-StagedPayload.ps1`) against the staging output (keep it).
3. Produces the MSIX (`msbuild`/WAP pack step).
4. Installs it:

   * Remove prior install if present (`Get-AppxPackage ... | Remove-AppxPackage`)
   * `Add-AppxPackage -Path <msix>`

### B3) Find installed identity and install location

After install:

* Get package: `Get-AppxPackage -Name <YourPackageName>`
* Capture:

  * `InstallLocation` (for file presence assertions)
  * `PackageFamilyName`
* Determine AUMID:

  * `AUMID = "<PackageFamilyName>!<ApplicationId>"`
  * `ApplicationId` can be read from the installed `AppxManifest.xml` under `InstallLocation`.

### B4) Trigger activations *without relying on user default-app settings*

For automated tests, don’t depend on Windows “default app” UI. Instead, use **IApplicationActivationManager** to activate the app specifically as:

* **Protocol activation**
* **File activation**

Implement a small helper executable `ActivationDriver.exe` (net481) that:

* Creates COM instance `ApplicationActivationManager`
* Calls:

  * `ActivateApplication(aumid, args, …)` for a baseline launch test
  * `ActivateForProtocol(aumid, uri, …)` for protocol activation
  * `ActivateForFile(aumid, shellItemArray, verb, …)` for file activation

Your PowerShell test calls `ActivationDriver.exe` with:

* `--aumid "<PFN>!App"`
* `--protocol "mdview:file:///C:/temp/test.md#section"`
* `--file "C:\temp\test.md"`

### B5) Assertions: prove the correct thing happened

To catch “silent requirement misses”, you need a deterministic artifact.

Add a test-only behavior to the host + engine:

* Host supports env var `MDV_E2E_TRACE_PATH`.
* When set, host writes a JSON record containing:

  * activation kind (launch/file/protocol)
  * raw input it received (full URI including fragment; file path including spaces)
  * resolved package root
  * resolved pwsh path chosen (bundled vs system)
  * resolved engine path
  * full pwsh arguments it would use
* In E2E test mode, the host can either:

  * **not** launch pwsh (fastest), or
  * launch pwsh with `-TestMode` so the engine writes its own confirmation and exits quickly (more complete).

Then the test asserts:

* Installed layout contains expected files under `InstallLocation` (`pwsh\pwsh.exe`, `app\Open-Markdown.ps1`, assets).
* The trace file exists and shows:

  * For protocol: the **full URI** was preserved (including fragment).
  * For file: the **exact file path** is preserved (including spaces/unicode if you include such cases).
  * The resolved paths point inside the MSIX install location (not dev paths).
  * No dependency on external runtimes (see next section).

### B6) Clean-machine dependency gate (what catches “solutions 1/2 missed requirements”)

Add an explicit gate step before running activations:

1. Assert Windows App SDK runtime packages are not installed:

   * `Get-AppxPackage | ? Name -like "Microsoft.WindowsAppRuntime*"` should be empty (or log and fail if present, depending on how strict you want the environment).
2. Run the activation tests anyway; if the app fails to start due to missing runtime, the test fails.
3. Optionally, add a static dependency scan:

   * Inspect the host EXE’s referenced assemblies and fail if it references `Microsoft.WindowsAppRuntime.*`, `Microsoft.WindowsAppSDK`, etc.

This is the part unit tests will never catch on a dev machine.

