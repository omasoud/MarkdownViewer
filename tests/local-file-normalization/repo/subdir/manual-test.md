# Local File Normalization - Manual Test

Open this file with MarkdownViewer from `C:\repo\subdir\manual-test.md`.

## Required Directory Structure

```
C:\
├── repo\
│   ├── subdir\
│   │   ├── manual-test.md       ← OPEN THIS FILE
│   │   └── docs\
│   │       ├── spec1.md
│   │       └── spec2.md
│   └── docs\
│       ├── spec3.md
│       └── spec4.md
├── spec5.md
├── spec7.md
├── spec11.md
├── spec15.md
└── My Docs\
    ├── spec6.md
    ├── spec8.md
    ├── spec12.md
    ├── spec16.md
    └── spec17.md

\\orthanc\share\
├── spec9.md
├── spec13.md
├── spec18.md
└── My Docs\
    ├── spec10.md
    ├── spec14.md
    ├── spec19.md
    └── spec20.md
```

## Setup Instructions

1. Copy `tests\local-file-normalization\repo` to `C:\repo`
2. Copy `tests\local-file-normalization\root-specs\*` to `C:\`
3. Copy `tests\local-file-normalization\share-specs\*` to `\\orthanc\share\`

## Test Cases

| # | Link Syntax |  Click to Test | #section-1 | #Section #1 |
|---|-------------|---------------|------------|-------------|
| **Relative Paths** ||||||
| 1 | `docs\spec1.md` | [spec1](docs\spec1.md) | [frag1](docs\spec1.md#section-1) | [frag1s](docs\spec1.md#Section%20%231) |
| 2 | `docs/spec2.md` | [spec2](docs/spec2.md) | [frag2](docs/spec2.md#section-1) | [frag2s](docs/spec2.md#Section%20%231) |
| **Parent Traversal** ||||||
| 3 | `..\docs\spec3.md` | [spec3](..\docs\spec3.md) | [frag3](..\docs\spec3.md#section-1) | [frag3s](..\docs\spec3.md#Section%20%231) |
| 4 | `../docs/spec4.md` | [spec4](../docs/spec4.md) | [frag4](../docs/spec4.md#section-1) | [frag4s](../docs/spec4.md#Section%20%231) |
| **Windows Absolute (backslash)** ||||||
| 5 | `C:\spec5.md` | [spec5](C:\spec5.md) | [frag5](C:\spec5.md#section-1) | [frag5s](C:\spec5.md#Section%20%231) |
| 6 | `C:\My Docs\spec6.md` | [spec6](C:\My Docs\spec6.md) | [frag6](C:\My Docs\spec6.md#section-1) | [frag6s](C:\My Docs\spec6.md#Section%20%231) |
| **Windows Absolute (forward slash)** ||||||
| 7 | `C:/spec7.md` | [spec7](C:/spec7.md) | [frag7](C:/spec7.md#section-1) | [frag7s](C:/spec7.md#Section%20%231) |
| 8 | `C:/My Docs/spec8.md` | [spec8](C:/My Docs/spec8.md) | [frag8](C:/My Docs/spec8.md#section-1) | [frag8s](C:/My Docs/spec8.md#Section%20%231) |
| **UNC Paths (\\server)** ||||||
| 9 | `\\orthanc\share\spec9.md` | [spec9](\\orthanc\share\spec9.md) | [frag9](\\orthanc\share\spec9.md#section-1) | [frag9s](\\orthanc\share\spec9.md#Section%20%231) |
| 10 | `\\orthanc\share\My Docs\spec10.md` | [spec10](\\orthanc\share\My Docs\spec10.md) | [frag10](\\orthanc\share\My Docs\spec10.md#section-1) | [frag10s](\\orthanc\share\My Docs\spec10.md#Section%20%231) |
| **UNC Paths (\\localhost)** ||||||
| 11 | `\\localhost\c$\spec11.md` | [spec11](\\localhost\c$\spec11.md) | [frag11](\\localhost\c$\spec11.md#section-1) | [frag11s](\\localhost\c$\spec11.md#Section%20%231) |
| 12 | `\\localhost\c$\My Docs\spec12.md` | [spec12](\\localhost\c$\My Docs\spec12.md) | [frag12](\\localhost\c$\My Docs\spec12.md#section-1) | [frag12s](\\localhost\c$\My Docs\spec12.md#Section%20%231) |
| **UNC-like (//server)** ||||||
| 13 | `//orthanc/share/spec13.md` | [spec13](//orthanc/share/spec13.md) | [frag13](//orthanc/share/spec13.md#section-1) | [frag13s](//orthanc/share/spec13.md#Section%20%231) |
| 14 | `//orthanc/share/My Docs/spec14.md` | [spec14](//orthanc/share/My Docs/spec14.md) | [frag14](//orthanc/share/My Docs/spec14.md#section-1) | [frag14s](//orthanc/share/My Docs/spec14.md#Section%20%231) |
| **file:/// URLs (local drive)** ||||||
| 15 | `file:///C:/spec15.md` | [spec15](file:///C:/spec15.md) | [frag15](file:///C:/spec15.md#section-1) | [frag15s](file:///C:/spec15.md#Section%20%231) |
| 16 | `file:///C:/My Docs/spec16.md` | [spec16](file:///C:/My Docs/spec16.md) | [frag16](file:///C:/My Docs/spec16.md#section-1) | [frag16s](file:///C:/My Docs/spec16.md#Section%20%231) |
| 17 | `file:///C:/My%20Docs/spec17.md` | [spec17](file:///C:/My%20Docs/spec17.md) | [frag17](file:///C:/My%20Docs/spec17.md#section-1) | [frag17s](file:///C:/My%20Docs/spec17.md#Section%20%231) |
| **file:// URLs (UNC form)** ||||||
| 18 | `file://orthanc/share/spec18.md` | [spec18](file://orthanc/share/spec18.md) | [frag18](file://orthanc/share/spec18.md#section-1) | [frag18s](file://orthanc/share/spec18.md#Section%20%231) |
| 19 | `file://orthanc/share/My Docs/spec19.md` | [spec19](file://orthanc/share/My Docs/spec19.md) | [frag19](file://orthanc/share/My Docs/spec19.md#section-1) | [frag19s](file://orthanc/share/My Docs/spec19.md#Section%20%231) |
| 20 | `file://orthanc/share/My%20Docs/spec20.md` | [spec20](file://orthanc/share/My%20Docs/spec20.md) | [frag20](file://orthanc/share/My%20Docs/spec20.md#section-1) | [frag20s](file://orthanc/share/My%20Docs/spec20.md#Section%20%231) |
