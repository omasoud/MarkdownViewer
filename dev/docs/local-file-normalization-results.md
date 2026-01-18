| Form (examples)                         | OS      | Type                                    | Ideal normalized form (mdview:file://…)                                  | Pass |
| --------------------------------------- | ------- | --------------------------------------- | ------------------------------------------------------------------------ | ---- |
| `subdir\docs\spec.md`                   | Both    | Relative path (backslash)               | `mdview:file:///<BASE_DIR>/subdir/docs/spec.md`                          | ❌   |
| `subdir/docs/spec.md`                   | Both    | Relative path (forward slash)           | `mdview:file:///<BASE_DIR>/subdir/docs/spec.md`                          | ✅   |
| `..\docs\spec.md`                       | Both    | Relative path, parent traversal (\\)    | `mdview:file:///<BASE_DIR>/../docs/spec.md` *(then canonicalize)*        | ❌   |
| `../docs/spec.md`                       | Both    | Relative path, parent traversal (/)     | `mdview:file:///<BASE_DIR>/../docs/spec.md` *(then canonicalize)*        | ✅   |
| `C:\docs\spec.md`                       | Windows | Absolute path (drive, backslash)        | `mdview:file:///C:/docs/spec.md`                                         | ❌   |
| `C:\My Docs\spec.md`                    | Windows | Absolute path (drive, with spaces)      | `mdview:file:///C:/My%20Docs/spec.md`                                    | ❌   |
| `C:/docs/spec.md`                       | Windows | Absolute path (drive, forward slash)    | `mdview:file:///C:/docs/spec.md`                                         | ✅   |
| `C:/My Docs/spec.md`                    | Windows | Absolute path (drive, / with spaces)    | `mdview:file:///C:/My%20Docs/spec.md`                                    | ❌   |
| `\\server\share\docs\spec.md`           | Windows | UNC path (network share)                | `mdview:file://server/share/docs/spec.md`                                | ❌   |
| `\\server\share\My Docs\spec.md`        | Windows | UNC path (with spaces)                  | `mdview:file://server/share/My%20Docs/spec.md`                           | ❌   |
| `\\localhost\share\docs\spec.md`        | Windows | UNC path (loopback share)               | `mdview:file://localhost/share/docs/spec.md`                             | ❌   |
| `\\localhost\share\My Docs\spec.md`     | Windows | UNC path (loopback, with spaces)        | `mdview:file://localhost/share/My%20Docs/spec.md`                        | ❌   |
| `//server/share/docs/spec.md`           | Windows | UNC-like (forward-slash form)           | `mdview:file://server/share/docs/spec.md`                                | ✅   |
| `//server/share/My Docs/spec.md`        | Windows | UNC-like (forward-slash, spaces)        | `mdview:file://server/share/My%20Docs/spec.md`                           | ❌   |
| `file:///C:/docs/spec.md`               | Windows | `file:` URL (local drive)               | `mdview:file:///C:/docs/spec.md`                                         | ✅   |
| `file:///C:/My Docs/spec.md`            | Windows | `file:` URL (unencoded spaces)          | `mdview:file:///C:/My%20Docs/spec.md`                                    | ❌   |
| `file:///C:/My%20Docs/spec.md`          | Windows | `file:` URL (encoded spaces)            | `mdview:file:///C:/My%20Docs/spec.md`                                    | ✅   |
| `file://server/share/docs/spec.md`      | Windows | `file:` URL (UNC/share form)            | `mdview:file://server/share/docs/spec.md`                                | ✅   |
| `file://server/share/My Docs/spec.md`   | Windows | `file:` URL (UNC, unencoded spaces)     | `mdview:file://server/share/My%20Docs/spec.md`                           | ❌   |
| `file://server/share/My%20Docs/spec.md` | Windows | `file:` URL (UNC, encoded spaces)       | `mdview:file://server/share/My%20Docs/spec.md`                           | ✅   |
| `/home/user/docs/spec.md`               | Linux   | Absolute path (POSIX)                   | `mdview:file:///home/user/docs/spec.md`                                  | ✅   |
| `/home/user/My Docs/spec.md`            | Linux   | Absolute path (POSIX, spaces)           | `mdview:file:///home/user/My%20Docs/spec.md`                             | ❌   |
| `file:///home/user/docs/spec.md`        | Linux   | `file:` URL (POSIX)                     | `mdview:file:///home/user/docs/spec.md`                                  | ✅   |
| `file:///home/user/My Docs/spec.md`     | Linux   | `file:` URL (POSIX, unencoded spaces)   | `mdview:file:///home/user/My%20Docs/spec.md`                             | ❌   |
| `file:///home/user/My%20Docs/spec.md`   | Linux   | `file:` URL (POSIX, encoded spaces)     | `mdview:file:///home/user/My%20Docs/spec.md`                             | ✅   |
| `~/docs/spec.md`                        | Linux   | Home-relative path                      | `mdview:file:///<HOME_DIR>/docs/spec.md`                                 | ✅   |
| `~/My Docs/spec.md`                     | Linux   | Home-relative path (spaces)             | `mdview:file:///<HOME_DIR>/My%20Docs/spec.md`                            | ❌   |
| `$HOME/docs/spec.md`                    | Linux   | Env-var path                            | `mdview:file:///<HOME_DIR>/docs/spec.md`                                 | ✅   |
| `$HOME/My Docs/spec.md`                 | Linux   | Env-var path (spaces)                   | `mdview:file:///<HOME_DIR>/My%20Docs/spec.md`                            | ❌   |

`<BASE_DIR>` = the directory containing the current Markdown file, expressed as a file-URL path segment (Windows example: `C:/repo`; Linux example: `home/user/repo`). `<HOME_DIR>` similarly (e.g., `home/user`).
