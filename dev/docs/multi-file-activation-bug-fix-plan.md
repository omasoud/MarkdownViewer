# Multi-File Activation Bug Fix Plan

## Overview

Bug: Opening multiple Markdown files from Windows Explorer launches duplicate browser tabs. Two selected files produce four tabs; three selected files attempt nine launches, typically producing eight tabs plus a `WriteAllText` sharing-violation dialog. Larger selections can cause a rapidly growing number of renderer processes and tabs.

**Root cause**: Explorer starts multiple packaged host processes for the selection, while each host ignores its process-specific file argument and handles the same `AppInstance` activation payload containing the full selection. Each of the `n` hosts therefore launches the renderer for all `n` files. The MSIX file association does not explicitly declare the intended `MultiSelectModel="Player"` behavior, and concurrent renderers for the same source file then collide while writing the same stable temporary HTML path.

## Phases

### Phase 1: Reproducer and Regression Test Infrastructure

- [x] 1.1 Add a packaged multi-file reproducer that records host starts, activation payloads, and renderer launches
- [x] 1.2 Extend `ActivationDriver` and its shell helpers to create a file activation payload from multiple paths
- [x] 1.3 Add a manifest contract test that requires an explicit `MultiSelectModel="Player"` file association
- [x] 1.4 Add host tests for multi-file and duplicate activation payloads
- [x] 1.5 Verify the reproducer fails with duplicate renderer launches before applying the fix

### Phase 2: MSIX and Host Activation Fix

- [x] 2.1 Change the MSIX file association to `uap3:FileTypeAssociation` with `MultiSelectModel="Player"`
- [x] 2.2 Verify the built package preserves the `Player` multi-selection model
- [x] 2.3 Make exactly one host authoritative for each packaged multi-file activation payload
- [x] 2.4 Prevent additional per-file host processes from expanding the same shared activation payload
- [x] 2.5 Deduplicate activation paths using Windows path comparison semantics before launching renderers
- [x] 2.6 Preserve single-file, protocol, Start Menu, and unpackaged command-line activation behavior

### Phase 3: Temporary HTML Write Hardening

- [x] 3.1 Make concurrent writes for the same source file tolerant of transient sharing violations
- [x] 3.2 Preserve the stable per-source HTML filename and document identity behavior
- [x] 3.3 Ensure write hardening does not mask duplicate activation by creating additional browser tabs
- [x] 3.4 Add a focused test for simultaneous render attempts targeting the same temporary HTML file

### Phase 4: Comprehensive Test Coverage

- [x] 4.1 Add host tests for one, two, three, duplicate, and empty file activation payloads
- [x] 4.2 Add packaged activation coverage asserting one renderer launch per distinct selected file
- [x] 4.3 Add coverage for selections above the Windows default multi-selection threshold
- [x] 4.4 Assert that multi-file activation produces no error dialog or unhandled sharing violation
- [x] 4.5 Verify existing file and protocol activation tests still pass

### Phase 5: Validation

- [ ] 5.1 Run the full unit, PowerShell, staged-payload, and packaged activation test suites
- [ ] 5.2 Install the test MSIX and manually open 1, 2, 3, and more than 15 selected Markdown files from Explorer
- [ ] 5.3 Verify exactly one browser tab opens for each selected file with no duplicates or dialogs
- [ ] 5.4 Inspect the host log and confirm each distinct path launches the renderer exactly once
- [ ] 5.5 Re-test single-file opening, `mdview:` linked-file navigation, and Start Menu help behavior
