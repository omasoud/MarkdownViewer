# Markdown Viewer Developer Guide

This guide covers building, testing, and developing Markdown Viewer.

## Prerequisites

- **PowerShell 7+** (pwsh) - Required for all scripts and testing
- **Windows 10 SDK** - Required for MSIX packaging (includes `makeappx.exe`)
- **.NET 10 SDK** - Required for building the Host EXE
- **Pester 5.x** - Required for PowerShell tests

### Installing Prerequisites

```powershell
# PowerShell 7 (if not installed)
winget install Microsoft.PowerShell

# .NET 10 SDK
winget install Microsoft.DotNet.SDK.Preview

# Pester 5.x (in PowerShell 7)
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

## Project Structure
```
MarkdownViewer/
├── MarkdownViewer.slnx          # Visual Studio solution
├── src/
│   ├── core/                    # Cross-platform engine + assets
│   │   ├── Open-Markdown.ps1    # Main PowerShell engine
│   │   ├── script.js            # Client-side JavaScript
│   │   ├── style.css            # Client-side CSS
│   │   ├── highlight.min.js     # Syntax highlighting
│   │   ├── highlight-theme.css  # Highlight.js theme
│   │   └── icons/               # Application icons
│   ├── win/                     # Windows-specific files
│   │   ├── MarkdownViewer.psm1  # Shared PowerShell module
│   │   ├── viewmd.vbs           # VBScript launcher (ad-hoc)
│   │   └── uninstall.vbs        # Silent uninstall helper
│   └── host/                    # MSIX Host EXE
│       └── MarkdownViewerHost/  # .NET 10 project
├── installers/
│   ├── win-adhoc/               # Per-user ad-hoc installer
│   └── win-msix/                # MSIX packaging
├── tests/
│   ├── MarkdownViewer.Tests.ps1 # Pester tests (PowerShell)
│   └── MarkdownViewerHost.Tests/# xUnit tests (C#)
└── dev/
    └── docs/                    # Developer documentation
```

## Building

### Option 1: Visual Studio

1. Open `MarkdownViewer.slnx` in Visual Studio 2026
2. Select Build > Build Solution (Ctrl+Shift+B)
3. Projects build to their respective `bin/Debug/` directories

### Option 2: Command Line

```powershell
# Build entire solution
dotnet build MarkdownViewer.slnx

# Build specific project
dotnet build src/host/MarkdownViewerHost/MarkdownViewerHost.csproj

# Build for release
dotnet build MarkdownViewer.slnx -c Release
```

### Build Outputs

| Project | Output Location |
|---------|-----------------|
| MarkdownViewerHost | `src/host/MarkdownViewerHost/bin/Debug/net10.0-windows10.0.19041.0/` |
| MarkdownViewerHost.Tests | `tests/MarkdownViewerHost.Tests/bin/Debug/net10.0/` |

## Running Tests

### PowerShell Tests (Pester)

The main test suite for the PowerShell engine and module:

```powershell
# Run from repository root
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester "tests\MarkdownViewer.Tests.ps1" -Output Detailed

# Or with minimal output
Invoke-Pester "tests\MarkdownViewer.Tests.ps1" -Output Minimal
```

**Expected:** 170 tests pass

### C# Tests (xUnit)

Tests for the Host EXE:

```powershell
# Run via dotnet CLI
dotnet test MarkdownViewer.slnx

# Or run specific test project
dotnet test tests\MarkdownViewerHost.Tests\MarkdownViewerHost.Tests.csproj
```

**Expected:** 12 tests pass

### Visual Studio Test Explorer

1. Open `MarkdownViewer.sln` in Visual Studio
2. Open Test > Test Explorer (Ctrl+E, T)
3. Click "Run All Tests" or select specific tests
4. C# xUnit tests appear automatically; Pester tests require the Pester Test Adapter extension

## Development Testing

### Testing Changes to the Engine

The easiest way to test engine changes during development:

```powershell
# From repository root, run directly on a test file
pwsh -NoProfile -ExecutionPolicy Bypass -File "src\core\Open-Markdown.ps1" -Path "tests\highlight-test.md"

# Or with a specific markdown file
pwsh -NoProfile -ExecutionPolicy Bypass -File "src\core\Open-Markdown.ps1" -Path "C:\path\to\your\file.md"
```

This opens the rendered markdown in your default browser.

### Testing with Module Changes

If you modify `MarkdownViewer.psm1`:

```powershell
# Force reimport the module before testing
Import-Module "src\win\MarkdownViewer.psm1" -Force

# Then run the engine
pwsh -NoProfile -ExecutionPolicy Bypass -File "src\core\Open-Markdown.ps1" -Path "tests\highlight-test.md"
```

### Testing CSS/JS Changes

CSS and JS changes take effect immediately when you re-run the engine, since they're inlined into the generated HTML. Just run the engine again on any markdown file.

### Testing the Installed MSIX

After building and installing the MSIX package, you can test file activation:

```powershell
# Open a markdown file via the registered file association
Start-Process "C:\path\to\your\file.md"

# Or use the protocol handler
Start-Process "ms-markdown-viewer:file=C:\path\to\your\file.md"
```

You can also right-click any `.md` file in Explorer and select "Open with > Markdown Viewer".

## Creating Installers

### Ad-hoc Installer (Per-User)

The ad-hoc installer copies files to `%LOCALAPPDATA%\Programs\MarkdownViewer` and registers file associations.

```powershell
# Install
.\installers\win-adhoc\install.ps1

# Or double-click INSTALL.cmd

# Uninstall
.\installers\win-adhoc\uninstall.ps1

# Or double-click UNINSTALL.cmd
```

**Note:** Run from the `installers/win-adhoc/` directory or the repository root.

### MSIX Package

The MSIX package bundles the Host EXE, PowerShell runtime, and engine files. There are two build methods:

#### Method 1: WAP Project (MSBuild) - Recommended

This is the preferred method using the Windows Application Packaging (WAP) project:

```powershell
# Prerequisites: Visual Studio 2026 with Desktop Bridge workload
# Launch Developer PowerShell first:
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
. "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation
# If the latest is Visual Studio 2026, this is equivalent to:
# . '<Drive>:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\Launch-VsDevShell.ps1' -SkipAutomaticLocation

# Build x64 Release
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release

# Build ARM64 Release  
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=ARM64 /p:Configuration=Release

# Build with signing enabled
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /p:SignMsix=true

# Skip bundling pwsh (for faster dev builds)
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /p:SkipPwsh=true

# Force regenerate assets from ICO
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /p:ForceRegenAssets=true
```

**WAP Build Flow:**
1. MSBuild builds `MarkdownViewerHost.csproj` via project reference
2. `Directory.Build.targets` invokes `stage.ps1` to compose the payload
3. `stage.ps1` downloads pwsh (if not cached), copies engine files, generates assets
4. WAP packages the staged content into MSIX

**MSBuild Properties:**

| Property | Description |
|----------|-------------|
| `/p:Platform=x64|ARM64` | Target architecture (required) |
| `/p:Configuration=Debug|Release` | Build configuration (default: Debug) |
| `/p:SkipPwsh=true` | Skip bundling PowerShell runtime |
| `/p:ForceRegenAssets=true` | Force regenerate PNG assets from ICO |
| `/p:SignMsix=true` | Sign package after build |

**Output:** `installers\win-msix\AppPackages\MarkdownViewer_<version>_<arch>_Test\MarkdownViewer_<version>_<arch>.msix`

**Clean Build:**
To force a complete rebuild from scratch:

```powershell
# Clean staging and output directories
msbuild .\installers\win-msix\MarkdownViewer.wapproj /t:Clean /p:Platform=x64 /p:Configuration=Release

# Then rebuild
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release
```

The Clean target removes:
- `installers\win-msix\output\stage\` - Staged payload files
- `installers\win-msix\output\*.msix` - Built packages
- `installers\win-msix\build\*.stamp` - Build timestamps

**Prerequisites for WAP Build:**
- Visual Studio 2026 with "Windows Application Packaging Project" workload
- .NET 10 SDK
- ImageMagick (optional, for asset generation from ICO - falls back to solid-color placeholders)

#### Method 2: build.ps1 (Legacy)

The standalone PowerShell script for environments without Visual Studio:

```powershell
# Build MSIX package (single architecture, uses system pwsh)
.\installers\win-msix\build.ps1

# Build with specific options
.\installers\win-msix\build.ps1 -Configuration Release -Architecture x64 -Version "1.0.0.0"

# Skip building Host EXE (if already built)
.\installers\win-msix\build.ps1 -SkipBuild

# Skip bundling PowerShell (uses system pwsh, smaller package for dev testing)
.\installers\win-msix\build.ps1 -SkipPwsh
```

#### Multi-Architecture Builds

```powershell
# Build both x64 and ARM64 packages
.\installers\win-msix\build.ps1 -BuildAll

# Build both architectures and create bundle (.msixbundle)
.\installers\win-msix\build.ps1 -Bundle

# Build with downloaded pinned PowerShell version (recommended for production)
.\installers\win-msix\build.ps1 -BuildAll -DownloadPwsh

# Full production build: both architectures, bundle, pinned pwsh, signed
.\installers\win-msix\build.ps1 -Bundle -DownloadPwsh -Sign
```

#### Build Parameters

| Parameter | Description |
|-----------|-------------|
| `-Configuration` | `Debug` or `Release` (default: Release) |
| `-Architecture` | `x64` or `arm64` (default: x64, ignored with -BuildAll) |
| `-Version` | Package version (default: 1.0.0.0) |
| `-PwshZipPath` | Path to PowerShell zip (optional, overrides download) |
| `-SkipBuild` | Don't rebuild Host EXE |
| `-SkipPwsh` | Don't bundle PowerShell runtime |
| `-BuildAll` | Build both x64 and ARM64 packages |
| `-Bundle` | Create .msixbundle (implies -BuildAll) |
| `-Sign` | Sign package(s) after build using sign.ps1 |
| `-DownloadPwsh` | Download pinned PowerShell version instead of using system pwsh |
| `-RegenerateAssets` | Force regenerate PNG assets from ICO (requires ImageMagick) |

**Output files:**
- Single arch: `installers/win-msix/output/MarkdownViewer_<version>_<arch>.msix`
- Bundle: `installers/win-msix/output/MarkdownViewer_<version>.msixbundle`

#### Pinned PowerShell Download

The `-DownloadPwsh` switch downloads a specific, pinned version of PowerShell from GitHub releases with SHA256 verification. This ensures:
- Reproducible builds across machines
- Correct architecture-specific runtime for each package
- Known-good PowerShell version

The pinned version is configured in `installers/win-msix/pwsh-versions.json`. To update the pinned version:

1. Edit `pwsh-versions.json` with new version and URLs
2. Get SHA256 hashes from the GitHub release page
3. Update the `sha256` values in the config file

Downloads are cached in `%TEMP%\MarkdownViewer-BuildCache`.

**Prerequisites for MSIX:**
- Windows 10 SDK installed (provides `makeappx.exe`)
- For proper icons, either:
  - Create PNG assets in `installers/win-msix/Package/Assets/`
  - Or install ImageMagick (the script will generate assets from the ICO)

### Signing MSIX Packages

The MSIX is unsigned by default, so you need to sign it for installation outside Developer Mode.

#### Using sign.ps1 (Recommended)

The `sign.ps1` script automates certificate creation and signing:

```powershell
# Create certificate and sign a package (interactive, will prompt)
.\installers\win-msix\sign.ps1 -MsixPath ".\output\MarkdownViewer_1.0.0.0_x64.msix" -Sign

# Use existing certificate
.\installers\win-msix\sign.ps1 -MsixPath ".\output\MarkdownViewer_1.0.0.0_x64.msix" -Sign -CertSubject "CN=MyExisting"

# Create certificate only (to be used later)
.\installers\win-msix\sign.ps1 -CreateCertOnly
```

The script will:
1. Check for existing certificate or create a new self-signed one
2. Add the certificate to Trusted People store (requires elevation on first run)
3. Sign the MSIX package

#### sign.ps1 Parameters

| Parameter | Description |
|-----------|-------------|
| `-MsixPath` | Path to MSIX file to sign |
| `-Sign` | Actually perform signing |
| `-CertSubject` | Certificate subject (default: CN=MarkdownViewerDev) |
| `-CreateCertOnly` | Only create certificate, don't sign |

#### Manual Signing

If you prefer manual control:

```powershell
# Create self-signed cert
$cert = New-SelfSignedCertificate -Type Custom -Subject "CN=MarkdownViewer" -KeyUsage DigitalSignature -FriendlyName "MarkdownViewer Dev" -CertStoreLocation "Cert:\CurrentUser\My"

# Export and trust (one-time)
$pwd = ConvertTo-SecureString -String "temp123" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath "dev.pfx" -Password $pwd
Import-PfxCertificate -FilePath "dev.pfx" -CertStoreLocation Cert:\LocalMachine\TrustedPeople -Password $pwd

# Sign the package
& "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign /fd SHA256 /sha1 $cert.Thumbprint "installers\win-msix\output\MarkdownViewer_1.0.0.0_x64.msix"
```

### Installing the MSIX (Sideload)

The MSIX is unsigned by default, so you need either:

1. **Developer Mode** (Settings > For Developers > Developer Mode)
   - Then double-click the .msix file

2. **Signed package** using sign.ps1:
   ```powershell
   # Build and sign in one step
   .\installers\win-msix\build.ps1 -Sign
   
   # Then double-click the .msix file
   ```

### Changing the App Name (for Store Availability)

The app name displayed in Windows and the Microsoft Store is controlled by the MSIX manifest. If the name "Markdown Viewer" is taken in the Store, you'll need to change it.

**Files to update:**

1. **`installers/win-msix/Package/AppxManifest.xml`**:
   ```xml
   <Properties>
     <DisplayName>Your New App Name</DisplayName>
     ...
   </Properties>
   
   <Applications>
     <Application ...>
       <uap:VisualElements DisplayName="Your New App Name" ...>
   ```

2. **`src/host/MarkdownViewerHost/MarkdownViewerHost.csproj`** (optional, for assembly info):
   ```xml
   <Product>Your New App Name</Product>
   ```

3. **`src/core/Open-Markdown.ps1`** - Update any user-facing strings:
   ```powershell
   $page.Caption = "Your New App Name"
   ```

4. **`src/host/MarkdownViewerHost/Program.cs`** - Update the TaskDialog:
   ```csharp
   Caption = "Your New App Name",
   ```

**Note:** The Store submission process will re-sign your package with Microsoft's certificate. The Publisher in the manifest will be updated to match your Store developer account.

### ARM64 Testing

To properly test ARM64 builds:

1. **Build for ARM64**:
   ```powershell
   .\installers\win-msix\build.ps1 -Architecture arm64 -DownloadPwsh
   ```

2. **Testing options**:
   - **ARM64 hardware**: Install the MSIX on a Windows ARM64 device (Surface Pro X, etc.)
   - **ARM64 VM**: Use Hyper-V with an ARM64 Windows VM (requires ARM64 host)
   - **Emulation testing**: x64 Windows can't run ARM64 packages natively

3. **Verify architecture**:
   After installation, check the app runs correctly by opening a .md file.

4. **Common issues**:
   - ARM64 PowerShell must be bundled (use `-DownloadPwsh`)
   - System pwsh on x64 won't work in ARM64 packages

## Debugging

### Debugging the Engine

Add `-Debug` or `Write-Host` statements to `Open-Markdown.ps1`:

```powershell
# Add at top of script
$DebugPreference = 'Continue'

# Then use
Write-Debug "Variable value: $variable"
```

### Debugging the Host EXE

1. Set `MarkdownViewerHost` as startup project in Visual Studio
2. Add command-line arguments in Project Properties > Debug:
   - Arguments: `C:\path\to\test.md`
3. Set breakpoints and press F5

### Viewing Generated HTML

The engine writes temporary HTML files to `%TEMP%`:
- `viewmd_<name>_<hash>.html` - Local images version
- `viewmd_<name>_<hash>_remote.html` - Remote images enabled

Open these in a text editor to inspect the generated HTML.

## Common Development Tasks

### Adding a New Language Alias for Syntax Highlighting

Edit `src/core/script.js` and add to the `LANG_MAP` object:

```javascript
const LANG_MAP = {
    // ...existing mappings...
    'newlang': 'existinglang',  // Add your alias
};
```

### Modifying the HTML Sanitizer

Edit `src/win/MarkdownViewer.psm1`, function `Invoke-HtmlSanitization`.

**Important:** Add corresponding tests in `tests/MarkdownViewer.Tests.ps1`.

### Adding a New Theme Variation

1. Edit `src/core/style.css` - Add new `[data-theme="..."][data-variation="N"]` rules
2. Edit `src/core/script.js` - Add variation name to `lightNames` or `darkNames` array

### Updating highlight.js

1. Download new bundle from https://highlightjs.org/download/
2. Replace `src/core/highlight.min.js`
3. Update `src/core/highlight-theme.css` if theme changed
4. Run tests to verify

## Troubleshooting

### "ConvertFrom-Markdown not found"

Ensure you're using PowerShell 7+, not Windows PowerShell 5.1:
```powershell
$PSVersionTable.PSVersion  # Should be 7.x
```

### Tests fail with "Module not found"

Ensure paths are correct after repository restructure:
```powershell
# Module should be at:
Test-Path "src\win\MarkdownViewer.psm1"
```

### MSIX build fails with "makeappx.exe not found"

Install Windows 10 SDK:
```powershell
winget install Microsoft.WindowsSDK.10.0.22621
```

### Solution doesn't build in Visual Studio

1. Close Visual Studio
2. Delete `bin/` and `obj/` folders
3. Delete `.vs/` folder
4. Reopen solution and rebuild

## Code Style

- **PowerShell:** Follow existing patterns, use `$ErrorActionPreference = 'Stop'`
- **C#:** Follow .NET conventions, nullable enabled
- **JavaScript:** No framework, vanilla JS with IIFEs for isolation
- **CSS:** CSS custom properties for theming

## Contributing

1. Create a feature branch
2. Make changes
3. Run all tests (Pester + xUnit)
4. Update documentation if needed
5. Submit pull request
