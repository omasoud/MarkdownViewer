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
??? MarkdownViewer.sln           # Visual Studio solution
??? src/
?   ??? core/                    # Cross-platform engine + assets
?   ?   ??? Open-Markdown.ps1    # Main PowerShell engine
?   ?   ??? script.js            # Client-side JavaScript
?   ?   ??? style.css            # Client-side CSS
?   ?   ??? highlight.min.js     # Syntax highlighting
?   ?   ??? highlight-theme.css  # Highlight.js theme
?   ?   ??? icons/               # Application icons
?   ??? win/                     # Windows-specific files
?   ?   ??? MarkdownViewer.psm1  # Shared PowerShell module
?   ?   ??? viewmd.vbs           # VBScript launcher (ad-hoc)
?   ?   ??? uninstall.vbs        # Silent uninstall helper
?   ??? host/                    # MSIX Host EXE
?       ??? MarkdownViewerHost/  # .NET 10 project
??? installers/
?   ??? win-adhoc/               # Per-user ad-hoc installer
?   ??? win-msix/                # MSIX packaging
??? tests/
?   ??? MarkdownViewer.Tests.ps1 # Pester tests (PowerShell)
?   ??? MarkdownViewerHost.Tests/# xUnit tests (C#)
??? dev/
    ??? docs/                    # Developer documentation
```

## Building

### Option 1: Visual Studio

1. Open `MarkdownViewer.sln` in Visual Studio 2022
2. Select Build > Build Solution (Ctrl+Shift+B)
3. Projects build to their respective `bin/Debug/` directories

### Option 2: Command Line

```powershell
# Build entire solution
dotnet build MarkdownViewer.sln

# Build specific project
dotnet build src/host/MarkdownViewerHost/MarkdownViewerHost.csproj

# Build for release
dotnet build MarkdownViewer.sln -c Release
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
dotnet test MarkdownViewer.sln

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

The MSIX package bundles the Host EXE, PowerShell runtime, and engine files.

```powershell
# Build MSIX package (builds everything)
.\installers\win-msix\build.ps1

# Build with specific options
.\installers\win-msix\build.ps1 -Configuration Release -Architecture x64 -Version "1.0.0.0"

# Skip building Host EXE (if already built)
.\installers\win-msix\build.ps1 -SkipBuild

# Skip bundling PowerShell (uses system pwsh, smaller package for dev testing)
.\installers\win-msix\build.ps1 -SkipPwsh
```

**Output:** `installers/win-msix/output/MarkdownViewer_1.0.0.0_x64.msix`

**Prerequisites for MSIX:**
- Windows 10 SDK installed (provides `makeappx.exe`)
- For proper icons, either:
  - Create PNG assets in `installers/win-msix/Package/Assets/`
  - Or install ImageMagick (the script will generate assets from the ICO)

### Installing the MSIX (Sideload)

The MSIX is unsigned, so you need either:

1. **Developer Mode** (Settings > For Developers > Developer Mode)
   - Then double-click the .msix file

2. **Self-signed certificate** (for testing):
   ```powershell
   # Create self-signed cert
   $cert = New-SelfSignedCertificate -Type Custom -Subject "CN=MarkdownViewer" -KeyUsage DigitalSignature -FriendlyName "MarkdownViewer Dev" -CertStoreLocation "Cert:\CurrentUser\My"
   
   # Sign the package
   & "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign /fd SHA256 /a /f cert.pfx /p password "installers\win-msix\output\MarkdownViewer_1.0.0.0_x64.msix"
   ```

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
