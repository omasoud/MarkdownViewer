# Local File Normalization - Manual Test Document

## Setup Instructions

Before testing, create copies of a simple test file named `spec.md` in the following locations.

### Create spec.md

Create a simple `spec.md` file with this content:

```markdown
# Test Specification

This is the test spec file.

## Section 1

Content for section 1.
```

### Required File Locations

Place copies of `spec.md` in these locations:

| Location | Path |
|----------|------|
| **This file's directory** | Place this test file at `C:\repo\subdir\test.md` |
| **Subdirectory** | `C:\repo\subdir\subdir\docs\spec.md` (for `subdir/docs/spec.md` relative test) |
| **Parent's sibling** | `C:\repo\docs\spec.md` (for `../docs/spec.md` test from `C:\repo\subdir\`) |
| **Drive root docs** | `C:\docs\spec.md` (for absolute path tests) |
| **Path with spaces** | `C:\My Docs\spec.md` |
| **UNC share** | `\\orthanc\share\docs\spec.md` |
| **UNC share with spaces** | `\\orthanc\share\My Docs\spec.md` |
| **Localhost share** | `\\localhost\c$\docs\spec.md` (or create a local share) |

### Network Share Setup (for UNC tests)

If `\\orthanc\share` doesn't exist, either:
1. Create a shared folder on a machine named `orthanc`
2. Or substitute with an existing network share and update links below

### Place This Test File

**IMPORTANT:** Place this file at `C:\repo\subdir\test.md` for the relative path tests to work correctly.

---

## Test Matrix

Click each link below to verify it opens `spec.md` correctly in MarkdownViewer.

| Form (examples) | OS | Type | Test Link | Result |
|-----------------|-----|------|-----------|--------|
| `subdir\docs\spec.md` | Both | Relative path (backslash) | [subdir\docs\spec.md](subdir\docs\spec.md) | ☐ |
| `subdir/docs/spec.md` | Both | Relative path (forward slash) | [subdir/docs/spec.md](subdir/docs/spec.md) | ☐ |
| `..\docs\spec.md` | Both | Relative path (parent, backslash) | [..\docs\spec.md](..\docs\spec.md) | ☐ |
| `../docs/spec.md` | Both | Relative path (parent, forward slash) | [../docs/spec.md](../docs/spec.md) | ☐ |
| `C:\docs\spec.md` | Windows | Absolute path (drive) | [C:\docs\spec.md](C:\docs\spec.md) | ☐ |
| `C:\My Docs\spec.md` | Windows | Absolute path (drive, spaces) | [C:\My Docs\spec.md](C:\My Docs\spec.md) | ☐ |
| `\\orthanc\share\docs\spec.md` | Windows | UNC path (network share) | [\\orthanc\share\docs\spec.md](\\orthanc\share\docs\spec.md) | ☐ |
| `\\orthanc\share\My Docs\spec.md` | Windows | UNC path (spaces) | [\\orthanc\share\My Docs\spec.md](\\orthanc\share\My Docs\spec.md) | ☐ |
| `\\localhost\c$\docs\spec.md` | Windows | UNC path (loopback) | [\\localhost\c$\docs\spec.md](\\localhost\c$\docs\spec.md) | ☐ |
| `file:///C:/docs/spec.md` | Windows | file: URL (local drive) | [file:///C:/docs/spec.md](file:///C:/docs/spec.md) | ☐ |
| `file:///C:/My%20Docs/spec.md` | Windows | file: URL (encoded spaces) | [file:///C:/My%20Docs/spec.md](file:///C:/My%20Docs/spec.md) | ☐ |
| `file://orthanc/share/docs/spec.md` | Windows | file: URL (UNC form) | [file://orthanc/share/docs/spec.md](file://orthanc/share/docs/spec.md) | ☐ |
| `file://orthanc/share/My%20Docs/spec.md` | Windows | file: URL (UNC, encoded) | [file://orthanc/share/My%20Docs/spec.md](file://orthanc/share/My%20Docs/spec.md) | ☐ |
| `C:/docs/spec.md` | Windows | Absolute path (forward slashes) | [C:/docs/spec.md](C:/docs/spec.md) | ☐ |
| `C:/My Docs/spec.md` | Windows | Absolute path (forward, spaces) | [C:/My Docs/spec.md](C:/My Docs/spec.md) | ☐ |
| `//orthanc/share/docs/spec.md` | Windows | UNC-like (forward slashes) | [//orthanc/share/docs/spec.md](//orthanc/share/docs/spec.md) | ☐ |
| `//orthanc/share/My Docs/spec.md` | Windows | UNC-like (forward, spaces) | [//orthanc/share/My Docs/spec.md](//orthanc/share/My Docs/spec.md) | ☐ |

---

## Quick Test Checklist

### Minimum Required Setup

For basic testing, you only need:

1. ☐ Place this file at `C:\repo\subdir\test.md`
2. ☐ Create `C:\repo\subdir\subdir\docs\spec.md` (for relative path test)
3. ☐ Create `C:\repo\docs\spec.md` (for parent traversal test)
4. ☐ Create `C:\docs\spec.md` (for absolute path tests)

### Full Test Setup (includes network)

1. ☐ All items from minimum setup
2. ☐ Create `C:\My Docs\spec.md`
3. ☐ Create `\\orthanc\share\docs\spec.md`
4. ☐ Create `\\orthanc\share\My Docs\spec.md`

---

## Notes

- **Linux paths**: `/home/user/docs/spec.md`, `~/docs/spec.md`, and `$HOME/docs/spec.md` are Linux-only and cannot be tested on Windows
- **file: URLs with unencoded spaces**: `file:///C:/My Docs/spec.md` may not render as a clickable link in all markdown renderers
- **Result column**: Mark ☐ as ☑ (pass) or ☒ (fail) after testing each link
