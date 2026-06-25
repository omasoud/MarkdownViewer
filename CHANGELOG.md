# Changelog

All notable changes to MarkView are documented in this file.

## 1.3.0 - Unreleased

This is the in-progress Linux branch work. It has not been merged to `main` yet.

### Added

- Linux support through `src/linux/markview`, `src/linux/MarkdownViewer.psm1`, Freedesktop desktop integration, and Snap packaging for amd64 and arm64 with bundled PowerShell.
- macOS support through `src/mac/markview`, `src/mac/MarkdownViewer.psm1`, an Apple Silicon app bundle/DMG build path, and protocol/file activation host.
- Cross-platform local-file normalization fixtures and Pester coverage for Windows, Linux, and macOS.
- Shared cross-platform module support in `src/core/MarkdownViewer.Shared.psm1`.
- Release metadata validation through `dev/scripts/Test-VersionConsistency.ps1`.

### Changed

- Refactored the platform modules so shared rendering, local-link, and path-normalization behavior can be reused across Windows, Linux, and macOS.
- Expanded user and developer documentation for Linux, macOS, Snap, DMG, and cross-platform architecture.
- Updated MSIX staging to include the shared module and support architecture-specific bundled PowerShell downloads.

### Fixed

- Preserved linked Markdown fragment navigation with the `_fragment` query contract and browser-side scrolling.
- Improved local asset and link URI handling for Linux browsers.
- Converted image dimension units during HTML link repair so rendered images keep expected sizing across platforms.
- Hardened Linux browser launch/output directory behavior and PowerShell extraction errors.

## 1.2.0 - 2026-02-23

Baseline changelog entry for the current `main` release, published as the Microsoft Store MSIX app.

### Added

- Microsoft Store/MSIX distribution for Windows with bundled PowerShell 7.
- Windows file association support for `.md` and `.markdown` files.
- `mdview:` protocol support for opening linked local Markdown files.
- Syntax highlighting, dark/light theme controls, theme variations, and document-title/favicon rendering.
- Security protections for rendered Markdown, including HTML sanitization, a strict CSP, remote-image opt-in, and Mark-of-the-Web warnings.

### Changed

- Documented Store installation, sideloaded MSIX builds, and per-user ad-hoc installation paths.
- Standardized release version metadata around `1.2.0`.
