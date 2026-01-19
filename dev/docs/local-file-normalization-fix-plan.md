# Local File Normalization Fix Plan

## Problem Summary

`ConvertFrom-Markdown` has several bugs that prevent local file links from working correctly:

| Issue | Example Input | Current Output | Expected |
|-------|---------------|----------------|----------|
| Backslashes encoded as %5C | `[x](docs\spec.md)` | `href="docs%5Cspec.md"` | `href="docs/spec.md"` |
| Unencoded spaces break links | `[x](My Docs/spec.md)` | No link created | `href="My%20Docs/spec.md"` |
| UNC paths lose first backslash | `[x](\\server\share\f.md)` | `href="%5Cserver%5Cshare..."` | `href="file://server/share/f.md"` |
| C:\ paths broken | `[x](C:\spec.md)` | `href="C%3A%5Cspec.md"` | `href="file:///C:/spec.md"` |
| Fragments double-encoded in C:/ paths | `[x](C:/spec.md#s1)` | `href="C:/spec.md%23s1"` | `href="file:///C:/spec.md#s1"` |

## Solution Architecture

We cannot modify `ConvertFrom-Markdown` (built-in cmdlet), so we implement a two-phase fix:

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│    Markdown     │ ──► │ Repair-MarkdownLinks │ ──► │ ConvertFrom-Markdown│
│    (raw text)   │     │   (pre-process)      │     │                     │
└─────────────────┘     └──────────────────────┘     └──────────┬──────────┘
                                                                │
                        ┌──────────────────────┐                │
                        │ Invoke-HtmlSanitize  │ ◄──────────────┘
                        │                      │
                        └──────────┬───────────┘
                                   │
                        ┌──────────▼───────────┐
                        │  Repair-HtmlLinks    │
                        │   (post-process)     │
                        └──────────────────────┘
```

### Phase 1: Pre-process Markdown (`Repair-MarkdownLinks`)

Fix link syntax **before** `ConvertFrom-Markdown` so links are created:

1. **Encode spaces** in link targets: `[x](My Docs/f.md)` → `[x](My%20Docs/f.md)`
2. **Normalize backslashes** to forward slashes: `[x](docs\f.md)` → `[x](docs/f.md)`
3. **Convert Windows absolute paths** to file:// URLs: `[x](C:\f.md)` → `[x](file:///C:/f.md)`
4. **Convert UNC paths** to file:// URLs: `[x](\\server\share\f.md)` → `[x](file://server/share/f.md)`

### Phase 2: Post-process HTML (`Repair-HtmlLinks`)

Fix any remaining encoding issues in the rendered HTML:

1. **Decode %5C** to `/` in href/src attributes
2. **Fix double-encoded fragments**: `%23` → `#` when followed by valid fragment chars
3. **Fix orphaned UNC paths**: `href="%5Cserver..."` → `href="file://server/..."`

## Implementation Details

### New Functions in MarkdownViewer.psm1

```powershell
function Repair-MarkdownLinks {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Markdown)
    # Pre-processes markdown to fix link targets
}

function Repair-HtmlLinks {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Html)
    # Post-processes HTML to fix href/src encoding issues
}
```

### Integration in Open-Markdown.ps1

```powershell
# Before:
$html = (ConvertFrom-Markdown -Path $p).Html
$html = Invoke-HtmlSanitization -Html $html

# After:
$md = Get-Content -Raw -LiteralPath $p
$md = Repair-MarkdownLinks -Markdown $md
$html = (ConvertFrom-Markdown -InputObject $md).Html
$html = Invoke-HtmlSanitization -Html $html
$html = Repair-HtmlLinks -Html $html
```

## Detailed Repair Logic

### Repair-MarkdownLinks (Pre-processing)

Regex to match markdown link/image targets:
```
(?<prefix>!?\[[^\]]*\]\()(?<target>[^)\s]+)(?<suffix>\))
```

For each match, transform `<target>`:

1. **If starts with `\\`** (UNC path):
   - Convert to `file://server/share/path`
   - URL-encode special chars (space → %20)

2. **If matches `^[A-Z]:[/\\]`** (Windows absolute):
   - Convert to `file:///C:/path`
   - Normalize backslashes to forward slashes
   - URL-encode special chars

3. **If contains backslash** (relative with backslash):
   - Normalize backslashes to forward slashes

4. **If contains unencoded space**:
   - URL-encode the space

5. **Preserve fragments**: Handle `#fragment` at end of target

### Repair-HtmlLinks (Post-processing)

For each `href="..."` and `src="..."`:

1. **Decode %5C** → `/`
2. **Decode %3A** → `:` (only after drive letter)
3. **Decode %23** → `#` (only for fragments, not in path)
4. **Fix orphaned UNC**: If href starts with `%5C` or `/` followed by server pattern, convert to `file://`

## Test Coverage

Existing tests will verify the fix:

| Test File | Purpose | Expected After Fix |
|-----------|---------|-------------------|
| LocalFileNormalization.ActualBehavior.Tests.ps1 | Full pipeline tests | All 18 pass |
| LocalFileNormalizationWithFragments.ActualBehavior.Tests.ps1 | Fragment tests | All 22 pass |
| LocalFileNormalization.UncBasePath.Tests.ps1 | UNC base path | All 7 pass (already passing) |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Over-aggressive URL encoding | Only encode within link targets, not display text |
| Breaking valid encoded URLs | Skip targets that start with `http:`, `https:`, `mailto:`, etc. |
| Performance with large files | Use compiled regex, single-pass processing |
| Breaking code blocks | Exclude fenced code blocks from pre-processing |

## Implementation Checklist

- [x] 1. Add `Repair-MarkdownLinks` function to MarkdownViewer.psm1
- [x] 2. Add `Repair-HtmlLinks` function to MarkdownViewer.psm1
- [x] 3. Update `Open-Markdown.ps1` to use new functions
- [x] 4. Run unit tests to verify fixes
- [ ] 5. Manual testing with sample files

## References

- [local-file-normalization.md](local-file-normalization.md) - Original specification
- [local-file-normalization-results.md](local-file-normalization-results.md) - Test matrix
- [tests/local-file-normalization/](../../tests/local-file-normalization/) - Manual test files
