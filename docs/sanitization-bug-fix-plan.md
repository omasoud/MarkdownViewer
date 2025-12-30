# Sanitization Bug Fix Plan

## Overview

Bug: The HTML sanitization regex in `Open-Markdown.ps1` incorrectly strips content from inside code blocks that matches the event handler pattern (e.g., `OnBootSec=5m`, `OnUnitActiveSec=30m`).

**Root cause**: The regex `'(?is)\s+on[a-z0-9_-]+\s*=\s*(?:"[^"]*"|''[^'']*''|[^\s>]+)'` uses case-insensitive matching and matches any text starting with `on...=`, not just HTML attributes within tags.

## Phases

### Phase 1: Unit Test Infrastructure

- [x] 1.1 Create test directory structure and Pester test file
- [x] 1.2 Create test helper to invoke the sanitization logic
- [x] 1.3 Write a reproducer test for the bug (should fail initially)

### Phase 2: Bug Fix

- [x] 2.1 Fix the event handler regex to only match actual HTML attributes within tags
- [x] 2.2 Verify the reproducer test passes

### Phase 3: Comprehensive Test Coverage

- [x] 3.1 Add tests for dangerous tag removal (script, iframe, object, embed, etc.)
- [x] 3.2 Add tests for event handler removal (onclick, onerror, etc.)
- [x] 3.3 Add tests for javascript: URI neutralization
- [x] 3.4 Add tests for data: URI blocking in href (but allowed in img src)
- [x] 3.5 Add tests for remote image detection
- [x] 3.6 Add tests for edge cases (nested tags, malformed HTML, etc.)
- [x] 3.7 Add tests for `Get-FileBaseHref` function
- [x] 3.8 Add tests for `Test-Motw` function

### Phase 4: Validation

- [x] 4.1 Run full test suite and ensure all tests pass
- [x] 4.2 Manual verification with the original bug scenario
