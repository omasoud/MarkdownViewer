# .NET Framework 4.8.1 Port Implementation Plan

## Overview

This plan documents the port of MarkdownViewerHost from .NET 10 to .NET Framework 4.8.1. The goal is to eliminate .NET 10 runtime bundling since .NET Framework 4.8.1 is pre-installed on Windows 11 systems.

Reference implementation: [solution3.txt](../dev/docs/solution3.txt)

---

## Phase 1: Project File Updates

- [x] 1.1 Update `MarkdownViewerHost.csproj`
  - [x] 1.1.1 Change SDK from `Microsoft.NET.Sdk` to `Microsoft.NET.Sdk.WindowsDesktop`
  - [x] 1.1.2 Change TargetFramework from `net10.0-windows10.0.19041.0` to `net481`
  - [x] 1.1.3 Remove `RuntimeIdentifiers` property (not needed for net481)
  - [x] 1.1.4 Remove `<Nullable>enable</Nullable>` (not supported in C# 7.3)
  - [x] 1.1.5 Remove `<ImplicitUsings>enable</ImplicitUsings>` (not supported)
  - [x] 1.1.6 Add `Microsoft.Windows.SDK.Contracts` NuGet package for WinRT activation APIs

- [x] 1.2 Update `MarkdownViewerHost.Tests.csproj`
  - [x] 1.2.1 Change TargetFramework to `net481`
  - [x] 1.2.2 Remove `<Nullable>enable</Nullable>`
  - [x] 1.2.3 Remove `<ImplicitUsings>enable</ImplicitUsings>`

---

## Phase 2: Source Code Updates

- [x] 2.1 Create `ProcessArgumentQuoter.cs`
  - [x] 2.1.1 Implement `QuoteArgument()` method for proper CreateProcess escaping
  - [x] 2.1.2 Handle spaces, quotes, and trailing backslashes correctly

- [x] 2.2 Update `Abstractions.cs`
  - [x] 2.2.1 Convert file-scoped namespace to block namespace
  - [x] 2.2.2 Add explicit `using` statements
  - [x] 2.2.3 Replace `record ActivationResult` with `sealed class ActivationResult`
  - [x] 2.2.4 Remove nullable annotations (`string?` → `string`)
  - [x] 2.2.5 Update `DefaultProcessLauncher.LaunchProcess()` to use `Arguments` string with `ProcessArgumentQuoter`
  - [x] 2.2.6 Remove `using System.Text.Json` and `TestSignalRecord` class

- [x] 2.3 Update `ActivationHandler.cs`
  - [x] 2.3.1 Convert file-scoped namespace to block namespace
  - [x] 2.3.2 Add explicit `using` statements
  - [x] 2.3.3 Remove nullable annotations
  - [x] 2.3.4 Replace `nameof()` with string literals
  - [x] 2.3.5 Replace `switch` expression with if-else chain
  - [x] 2.3.6 Replace `_log?.Invoke()` with `if (_log != null) _log()`
  - [x] 2.3.7 Add manual `SerializeTestSignal()` and `EscapeJsonString()` methods
  - [x] 2.3.8 Replace string interpolation in format strings with `string.Format()`

- [x] 2.4 Update `Program.cs`
  - [x] 2.4.1 Convert file-scoped namespace to block namespace
  - [x] 2.4.2 Add explicit `using` statements
  - [x] 2.4.3 Replace string interpolation with `string.Format()`

- [x] 2.5 Update `HelpDialogManager.cs`
  - [x] 2.5.1 Convert `using` declarations to `using` blocks
  - [x] 2.5.2 Replace `string.Contains(x, StringComparison)` with `IndexOf() >= 0`

- [x] 2.6 Update `IconHelper.cs`
  - [x] 2.6.1 Add explicit `using` statements
  - [x] 2.6.2 Convert `using` declarations to `using` blocks
  - [x] 2.6.3 Replace `nameof()` with string literal

---

## Phase 3: Test Code Updates

- [x] 3.1 Update `HostTests.cs`
  - [x] 3.1.1 Convert file-scoped namespace to block namespace
  - [x] 3.1.2 Add explicit `using` statements
  - [x] 3.1.3 Remove nullable annotations
  - [x] 3.1.4 Replace `ArgumentList` test with `ProcessArgumentQuoter` test
  - [x] 3.1.5 Replace `string.Contains()` with `IndexOf() >= 0`
  - [x] 3.1.6 Update `ActivationResult` constructor calls (named parameters)

---

## Phase 4: Build Script Updates

- [x] 4.1 Update `build.ps1`
  - [x] 4.1.1 Replace `dotnet publish -r $rid --self-contained false` with `msbuild /p:Configuration=$Config /restore /t:Build`
  - [x] 4.1.2 Update host file copy to only copy `MarkdownViewerHost.exe` (no `.dll`, `.runtimeconfig.json`, `.deps.json`)
  - [x] 4.1.3 Update output path to `bin\{Configuration}\net481\`

- [x] 4.2 Update `stage.ps1`
  - [x] 4.2.1 Simplify host file list to only `MarkdownViewerHost.exe`

---

## Phase 5: Verification

- [x] 5.1 Build verification
  - [x] 5.1.1 Build `MarkdownViewerHost.csproj` - SUCCESS
  - [x] 5.1.2 Build `MarkdownViewerHost.Tests.csproj` - SUCCESS
  - [x] 5.1.3 Verify output contains only `MarkdownViewerHost.exe` (no runtime files)

- [x] 5.2 Test verification
  - [x] 5.2.1 Run xUnit tests (43 passed, 0 failed)
  - [x] 5.2.2 Run Pester tests (192 passed, 0 failed, 23 skipped)

- [x] 5.3 Confirm no .NET 10 bundling
  - [x] 5.3.1 Build output in `bin\Release\net481\` contains:
    - `MarkdownViewerHost.exe` (82 KB)
    - `MarkdownViewerHost.exe.config` (176 bytes)
    - `MarkdownViewerHost.pdb` (23 KB)
  - [x] 5.3.2 No `.dll`, `.runtimeconfig.json`, or `.deps.json` files present

---

## Summary of Changes

### Files Created
- `src/host/MarkdownViewerHost/ProcessArgumentQuoter.cs` - Argument quoting helper
- `src/host/MarkdownViewerHost/Directory.Build.targets` - Clears RuntimeIdentifier when passed by WAP project

### Files Modified
- `src/host/MarkdownViewerHost/MarkdownViewerHost.csproj` - Framework/SDK changes, clear RuntimeIdentifier
- `src/host/MarkdownViewerHost/Abstractions.cs` - .NET Framework compatibility
- `src/host/MarkdownViewerHost/ActivationHandler.cs` - .NET Framework compatibility
- `src/host/MarkdownViewerHost/Program.cs` - .NET Framework compatibility
- `src/host/MarkdownViewerHost/HelpDialogManager.cs` - .NET Framework compatibility
- `src/host/MarkdownViewerHost/IconHelper.cs` - .NET Framework compatibility
- `tests/MarkdownViewerHost.Tests/MarkdownViewerHost.Tests.csproj` - Framework changes
- `tests/MarkdownViewerHost.Tests/HostTests.cs` - .NET Framework compatibility
- `installers/win-msix/MarkdownViewer.wapproj` - Simplified ProjectReference for .NET Framework
- `installers/win-msix/build/Directory.Build.targets` - Use MSBuild instead of dotnet publish, simplified content
- `installers/win-msix/build.ps1` - Use msbuild instead of dotnet publish
- `installers/win-msix/build/stage.ps1` - Simplify host file list

### Key Technical Changes
1. **Target Framework**: `net10.0-windows10.0.19041.0` → `net481`
2. **SDK**: `Microsoft.NET.Sdk` → `Microsoft.NET.Sdk.WindowsDesktop`
3. **Process Arguments**: `ArgumentList` API → `Arguments` string with `ProcessArgumentQuoter`
4. **JSON Serialization**: `System.Text.Json` → Manual `EscapeJsonString()` helper
5. **Build Command**: `dotnet publish --self-contained false` → `msbuild /p:Configuration=Release`
6. **Output Files**: 4 files (exe, dll, runtimeconfig, deps) → 1 file (exe only)
