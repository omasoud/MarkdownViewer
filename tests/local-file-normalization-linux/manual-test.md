# Local File Normalization - Manual Test (Linux)

Open this file with MarkView from `/tmp/markview-test/repo/subdir/manual-test.md`.

## Required Directory Structure

```
/tmp/markview-test/
├── repo/
│   ├── subdir/
│   │   ├── manual-test.md       ← OPEN THIS FILE
│   │   └── docs/
│   │       └── spec1.md
│   └── docs/
│       └── spec3.md
├── spec5.md
├── spec7.md
└── My Docs/
    ├── spec6.md
    ├── spec8.md
    └── spec9.md
```

## Setup Instructions

Run `dev/scripts/test/Deploy-LinkTests-Linux.ps1` from the repository root.

## Test Cases

The Windows version tests both backslash and forward-slash variants for relative/parent
paths. On Linux backslash is not a path separator, so only forward-slash is tested.

| # | Link Syntax | Click to Test | #section-1 | #Section #1 |
|---|-------------|---------------|------------|-------------|
| **Relative Path** ||||||
| 1 | `docs/spec1.md` | [spec1](docs/spec1.md) | [frag1](docs/spec1.md#section-1) | [frag1s](docs/spec1.md#Section%20%231) |
| **Parent Traversal** ||||||
| 2 | `../docs/spec3.md` | [spec3](../docs/spec3.md) | [frag3](../docs/spec3.md#section-1) | [frag3s](../docs/spec3.md#Section%20%231) |
| **Linux Absolute** ||||||
| 3 | `/tmp/markview-test/spec5.md` | [spec5](/tmp/markview-test/spec5.md) | [frag5](/tmp/markview-test/spec5.md#section-1) | [frag5s](/tmp/markview-test/spec5.md#Section%20%231) |
| 4 | `/tmp/markview-test/My%20Docs/spec6.md` | [spec6](/tmp/markview-test/My%20Docs/spec6.md) | [frag6](/tmp/markview-test/My%20Docs/spec6.md#section-1) | [frag6s](/tmp/markview-test/My%20Docs/spec6.md#Section%20%231) |
| **file:/// URLs** ||||||
| 5 | `file:///tmp/markview-test/spec7.md` | [spec7](file:///tmp/markview-test/spec7.md) | [frag7](file:///tmp/markview-test/spec7.md#section-1) | [frag7s](file:///tmp/markview-test/spec7.md#Section%20%231) |
| 6 | `file:///tmp/markview-test/My Docs/spec8.md` | [spec8](file:///tmp/markview-test/My Docs/spec8.md) | [frag8](file:///tmp/markview-test/My Docs/spec8.md#section-1) | [frag8s](file:///tmp/markview-test/My Docs/spec8.md#Section%20%231) |
| 7 | `file:///tmp/markview-test/My%20Docs/spec9.md` | [spec9](file:///tmp/markview-test/My%20Docs/spec9.md) | [frag9](file:///tmp/markview-test/My%20Docs/spec9.md#section-1) | [frag9s](file:///tmp/markview-test/My%20Docs/spec9.md#Section%20%231) |
