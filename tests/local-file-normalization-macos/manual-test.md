# Local File Normalization - Manual Test (macOS)

Open this file with MarkView from `/Users/markview/markview-test/repo/subdir/manual-test.md`.

## Required Directory Structure

```
/Users/markview/markview-test/
├── repo/
│   ├── subdir/
│   │   ├── manual-test.md       <- OPEN THIS FILE
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

Run `dev/scripts/test/Deploy-LinkTests-macOS.ps1` from the repository root.

## Test Cases

The Windows version tests backslash paths, drive letters, and UNC paths. On macOS,
backslash is not a path separator and drive/UNC forms are not native, so this
fixture covers POSIX paths and `file:///` URLs.

| # | Link Syntax | Click to Test | #section-1 | #Section #1 |
|---|-------------|---------------|------------|-------------|
| **Relative Path** ||||||
| 1 | `docs/spec1.md` | [spec1](docs/spec1.md) | [frag1](docs/spec1.md#section-1) | [frag1s](docs/spec1.md#Section%20%231) |
| **Parent Traversal** ||||||
| 2 | `../docs/spec3.md` | [spec3](../docs/spec3.md) | [frag3](../docs/spec3.md#section-1) | [frag3s](../docs/spec3.md#Section%20%231) |
| **macOS Absolute** ||||||
| 3 | `/Users/markview/markview-test/spec5.md` | [spec5](/Users/markview/markview-test/spec5.md) | [frag5](/Users/markview/markview-test/spec5.md#section-1) | [frag5s](/Users/markview/markview-test/spec5.md#Section%20%231) |
| 4 | `/Users/markview/markview-test/My%20Docs/spec6.md` | [spec6](/Users/markview/markview-test/My%20Docs/spec6.md) | [frag6](/Users/markview/markview-test/My%20Docs/spec6.md#section-1) | [frag6s](/Users/markview/markview-test/My%20Docs/spec6.md#Section%20%231) |
| **file:/// URLs** ||||||
| 5 | `file:///Users/markview/markview-test/spec7.md` | [spec7](file:///Users/markview/markview-test/spec7.md) | [frag7](file:///Users/markview/markview-test/spec7.md#section-1) | [frag7s](file:///Users/markview/markview-test/spec7.md#Section%20%231) |
| 6 | `file:///Users/markview/markview-test/My Docs/spec8.md` | [spec8](file:///Users/markview/markview-test/My Docs/spec8.md) | [frag8](file:///Users/markview/markview-test/My Docs/spec8.md#section-1) | [frag8s](file:///Users/markview/markview-test/My Docs/spec8.md#Section%20%231) |
| 7 | `file:///Users/markview/markview-test/My%20Docs/spec9.md` | [spec9](file:///Users/markview/markview-test/My%20Docs/spec9.md) | [frag9](file:///Users/markview/markview-test/My%20Docs/spec9.md#section-1) | [frag9s](file:///Users/markview/markview-test/My%20Docs/spec9.md#Section%20%231) |
