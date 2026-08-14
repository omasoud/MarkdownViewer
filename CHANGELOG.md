# Changelog

All notable changes to MarkView are documented in this file.

## 1.4.0 - Unreleased

Cross-platform feature release adding offline math typesetting.

### Added

- Added inline (`$...$`) and display (`$$...$$`) math typesetting with the
  bundled KaTeX 0.18.3 browser runtime.
- Added accessible HTML and MathML equation output, bounded rendering limits,
  horizontally scrollable display equations, and readable fallback source.
- Added content-addressed local KaTeX asset delivery so JavaScript, CSS, and
  fonts remain together and load without a network connection.
- Added math-specific converter, sanitizer, browser-contract, concurrency,
  fallback, and cross-platform packaging tests plus a manual rendering fixture.

### Changed

- Bumped versioned components to `1.4.0` (`1.4.0.0` for Windows package and
  assembly metadata).
- Expanded Windows MSIX, Linux Snap, macOS app-bundle, and ad-hoc Windows
  staging to include the pinned KaTeX runtime, font files, provenance, and MIT
  license notices.
- Extended the strict Content Security Policy with local font loading while
  retaining the existing no-network script and connection restrictions.

### Fixed

- Fixed macOS Developer ID packaging so the bundled PowerShell runtime retains
  the standard .NET Hardened Runtime exceptions and remains launchable after
  signing.

### Known limitations

- PowerShell's Markdown converter can interpret unescaped dollar-delimited
  currency as math. Escape literal currency dollar signs, such as
  `\$12.50`. This upstream behavior is tracked in
  [PowerShell/PowerShell#27792](https://github.com/PowerShell/PowerShell/issues/27792).

## 1.3.1 - 2026-07-11

Windows hotfix release for the Microsoft Store.

### Changed

- Bumped versioned components to `1.3.1` (`1.3.1.0` for Windows package and assembly metadata).
- Expanded packaged activation diagnostics and regression coverage for Explorer multi-file selection.

### Fixed

- Fixed Windows Explorer multi-file activation so each selected Markdown file opens exactly once instead of producing duplicate or rapidly multiplying browser tabs.
- Prevented duplicate file paths in a packaged activation payload from launching more than one renderer.
- Retried transient temporary-HTML sharing violations while preserving stable per-document output filenames.

## 1.3.0 - 2026-06-27

Cross-platform release line. The Linux Snap was tagged as `v1.3.0-linux` on 2026-06-26; the source and macOS release tags were created on 2026-06-27.

### Added

- macOS support through `src/mac/markview`, `src/mac/MarkdownViewer.psm1`, an Apple Silicon app bundle/DMG build path, and protocol/file activation host.
- macOS DMG build, signing, notarization, bundled PowerShell trimming, and bundled runtime verification scripts.
- macOS local-file normalization fixtures and Pester coverage.
- Store/listing metadata for the Linux Snap release.

### Changed

- Bumped all versioned components to `1.3.0`.
- Updated bundled PowerShell to `7.6.3` for Linux Snap and Windows MSIX packaging.
- Expanded user and developer documentation for Linux, macOS, Snap, DMG, and cross-platform architecture.
- Renamed the Linux Snap package to `markdownviewer` and refreshed launcher usage output.

### Fixed

- Preserved linked Markdown fragment navigation with the `_fragment` query contract and browser-side scrolling.
- Improved local asset and link URI handling for Linux browsers.
- Converted image dimension units during HTML link repair so rendered images keep expected sizing across platforms.
- Hardened Linux browser launch/output directory behavior and PowerShell extraction errors.

## 1.2.0 - 2026-02-23

Tagged as `v1.2.0.0` after Linux and shared-core work. This version was not published to the Microsoft Store.

### Added

- Initial Linux support through `src/linux/markview`, `src/linux/MarkdownViewer.psm1`, Freedesktop desktop integration, and Snap packaging.
- Shared cross-platform module support in `src/core/MarkdownViewer.Shared.psm1`.
- `_fragment` query parameter handling and browser-side scrolling for linked Markdown fragments.
- Linux and shared local-file normalization fixtures and Pester coverage.
- Release metadata validation through `dev/scripts/Test-VersionConsistency.ps1`.

### Changed

- Refactored the Windows module so rendering, local-link, and path-normalization behavior could move into shared code.
- Updated MSIX staging to include the shared module.
- Improved Linux browser launch behavior, output directory handling, and highlight asset copying.
- Standardized version metadata around `1.2.0`.

### Fixed

- Improved PowerShell extraction error handling in the build script.
- Added regression coverage for local-file normalization and fragment preservation.

## 1.0.1 - 2026-01-20

Tagged as `v1.0.1` on 2026-01-18 and published as the Microsoft Store MSIX app on 2026-01-20.

### Added

- Microsoft Store/MSIX distribution for Windows with bundled PowerShell 7.
- Windows file association support for `.md` and `.markdown` files.
- `mdview:` protocol support for opening linked local Markdown files.
- Full-trust Windows host, activation handling, and AppInstance-based file/protocol activation tests.
- Local Markdown link normalization and repair, including UNC paths, PSProvider prefixes, and fragment handling.
- Syntax highlighting, dark/light theme controls, theme variations, and document-title/favicon rendering.
- MarkView branding assets, privacy policy, Store screenshots, and in-app help/about dialog.
- MSIX staging, signing, PowerShell trimming, bundled runtime verification, and staged payload tests.

### Changed

- Ported the packaged Windows host to .NET Framework 4.8.1 for MSIX activation behavior.
- Expanded developer documentation for Windows packaging, activation testing, and the MSIX build flow.
- Added version display to rendered HTML output and standardized release metadata around `1.0.1`.

### Fixed

- Normalized package language codes and improved host process handling/logging.
- Improved protocol and file activation diagnostics for packaged E2E tests.
