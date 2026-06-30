# MarkView Release Process

This document describes the maintainer-facing release process for MarkView across Windows, macOS, and Linux. It is safe to keep in the public repository: it documents release policy, required checks, artifact locations, and expected publication flow without storing private account details or credentials.

## Release Model

MarkView releases are versioned from the canonical app version in:

```text
src/host/MarkdownViewerHost/MarkdownViewerHost.csproj
```

The `<Version>` value is the canonical three-part version, for example `1.3.0`. Platform packaging derives its own form from that value:

| Surface | Version form | Example |
| --- | --- | --- |
| Source, Snap, DMG | Three-part | `1.3.0` |
| MSIX identity, assembly, Windows package filenames | Four-part | `1.3.0.0` |

Use `dev/scripts/Test-VersionConsistency.ps1` to propagate and validate derived version references.

```powershell
.\dev\scripts\Test-VersionConsistency.ps1 -Fix
.\dev\scripts\Test-VersionConsistency.ps1
```

## Platform Matrix

| Platform | Public channel | Artifact | Architecture policy |
| --- | --- | --- | --- |
| Windows | Microsoft Store | MSIX/MSIXUPLOAD | x64 only unless intentionally expanded |
| macOS | GitHub Releases | `MarkView_<version>_arm64.dmg` | Apple Silicon arm64 |
| Linux | Snap Store | `markdownviewer_<version>_<arch>.snap` | amd64 and arm64 |

Windows Store packages are submitted unsigned; Microsoft Store signs the published app. macOS public DMGs must be Developer ID signed, notarized, stapled, and Gatekeeper-validated. Linux snaps are published through Snap Store channels.

## Common Release Checks

Start every release from a known repository state:

```powershell
git status --short --branch
git log -5 --decorate --oneline
git tag --list "v*" --sort=creatordate
```

Before publishing any platform, verify the intended version and run the relevant test suite for that platform. At minimum, update `CHANGELOG.md` before the final rollup tag and GitHub Release page are finalized.

## Windows Store Release

Windows packaging is driven by the WAP project:

```text
installers/win-msix/MarkdownViewer.wapproj
```

Build from Visual Studio Developer PowerShell:

```powershell
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
. "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation

.\dev\scripts\Test-VersionConsistency.ps1
.\tests\Invoke-AllTests.ps1 -Output Minimal
```

For a direct package build:

```powershell
msbuild .\installers\win-msix\MarkdownViewer.wapproj /p:Platform=x64 /p:Configuration=Release /v:m /restore
```

Validate the staged payload:

```powershell
.\tests\Test-StagedPayload.ps1 -StagingDir .\installers\win-msix\obj\Staging\x64\Release
```

Verify the bundled PowerShell runtime:

```powershell
.\installers\win-msix\obj\Staging\x64\Release\pwsh\pwsh.exe -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

Expected Store submission artifacts are under:

```text
installers/win-msix/output/
```

Submit the `.msixupload` when available. The Store submission artifact should be unsigned.

## macOS DMG Release

macOS packaging lives under:

```text
installers/macos-dmg/
```

For public distribution, use the release helper:

```bash
cd installers/macos-dmg

MARKVIEW_CODESIGN_IDENTITY="Developer ID Application: <identity>" \
  ./scripts/Release-MarkViewDmg.sh --keychain-profile <notary-profile>
```

The release helper builds the app bundle, signs the app and DMG, submits the DMG for notarization, staples the notarization ticket, and runs Gatekeeper validation. The final artifact is:

```text
installers/macos-dmg/output/MarkView_<version>_arm64.dmg
```

Record the SHA-256 checksum:

```bash
shasum -a 256 installers/macos-dmg/output/MarkView_<version>_arm64.dmg
```

Run the platform tests:

```bash
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester tests -Output Minimal'
```

## Linux Snap Release

Linux Snap packaging lives under:

```text
installers/linux-snap/
```

Build and test each architecture on a suitable Ubuntu builder. Full Snapcraft packing for `core24` should run on an Ubuntu 24.04/core24-compatible environment.

```bash
bash installers/linux-snap/build.sh arm64 --stage-only
installers/linux-snap/staged/pwsh/pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString(); ConvertFrom-Markdown -InputObject "# ok" | Out-Null'
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester tests -Output Minimal'
bash installers/linux-snap/build.sh arm64
```

Repeat for `amd64`. Snap artifacts are written to:

```text
installers/linux-snap/output/markdownviewer_<version>_<arch>.snap
```

Upload to `latest/edge`, smoke test, then promote both architectures to `latest/stable`.

## Tags

Use platform tags when platforms ship at different moments:

```text
v<version>-linux
v<version>-macos
v<version>-windows
```

Use `v<version>` for the canonical all-platform release state. Do not move a public tag unless the release owner explicitly decides that the tag should point at a later release-documentation-only commit.

## GitHub Release Page

The canonical GitHub Release page for `v<version>` should be a release notes and routing page. It does not need to host every installable artifact.

Include:

- what changed in the release
- platform availability
- Microsoft Store link for Windows
- GitHub DMG link and SHA-256 for macOS
- Snap Store link and install command for Linux
- known limitations, including architecture scope

Checksums should be listed only for files hosted directly on the GitHub Release.

## Post-Publish Checklist

After all platforms are published:

1. Verify each public channel shows the intended version.
2. Update `CHANGELOG.md` with the actual release history.
3. Commit and push release documentation changes.
4. Create or update platform tags as needed.
5. Update the canonical GitHub Release page.
6. Confirm the working tree is clean.
