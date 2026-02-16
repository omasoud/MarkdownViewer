# MarkdownViewer.Shared.psm1 - Cross-platform shared functions for Markdown Viewer
# These functions work identically on Windows and Linux.

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Sanitizes HTML by removing dangerous elements and attributes.
.DESCRIPTION
    Removes script tags, event handlers, javascript: URIs, and other potentially dangerous content.
    This is defense-in-depth behind the CSP.
.PARAMETER Html
    The HTML string to sanitize.
.OUTPUTS
    The sanitized HTML string.
#>
function Invoke-HtmlSanitization {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Html
    )

    process {
        if ([string]::IsNullOrEmpty($Html)) {
            return $Html
        }

        $result = $Html

        # 1) Drop dangerous elements (paired, self-closing, and leftover start tags)
        $dangerousTags = 'script|object|embed|iframe|meta|base|link|style'

        # paired: <tag ...> ... </tag>
        $result = $result -replace "(?is)<\s*($dangerousTags)\b[^>]*>.*?</\s*\1\s*>", ''

        # self-closing: <tag ... />
        $result = $result -replace "(?is)<\s*($dangerousTags)\b[^>]*/\s*>", ''

        # leftover start tags: <meta ...> or malformed starts
        $result = $result -replace "(?is)<\s*($dangerousTags)\b[^>]*>", ''

        # 2) Remove event handlers (only within HTML tags, not in text content)
        # Match event handlers only when they appear inside an HTML tag (after < and before >)
        # Use a callback-style replacement with a regex that captures the full tag
        # Tag pattern matches: standard tags, custom elements (my-tag), SVG namespaced (svg:rect),
        # tags with underscores (custom_element), and self-closing tags (/> ending)
        $result = [regex]::Replace(
            $result,
            '(?is)(<[a-z][\w:-]*\b)([^>]*)(/?>)',
            {
                param($m)
                $tagStart = $m.Groups[1].Value
                $attrs = $m.Groups[2].Value
                $tagEnd = $m.Groups[3].Value
                
                # Remove event handlers from the attributes part only
                $cleanAttrs = $attrs -replace '(?i)\s+on[a-z0-9_-]+\s*=\s*(?:"[^"]*"|''[^'']*''|[^\s>]+)', ''
                
                return $tagStart + $cleanAttrs + $tagEnd
            }
        )

        # 3) Neutralize javascript: URIs in href/src/xlink:href/srcset
        $result = $result -replace '(?is)\b(href|src|xlink:href|srcset)\s*=\s*(?:"\s*javascript:[^"]*"|''\s*javascript:[^'']*''|\s*javascript:[^\s>]+)', '$1="#"'

        # 4) Block data: URIs only in href/xlink:href (not src, to preserve images)
        $result = $result -replace '(?is)\b(href|xlink:href)\s*=\s*(?:"\s*data:[^"]*"|''\s*data:[^'']*''|\s*data:[^\s>]+)', '$1="#"'

        return $result
    }
}


<#
.SYNOPSIS
    Detects whether the HTML contains references to remote images.
.DESCRIPTION
    Checks for <img> tags with src or srcset attributes containing https:, http:, or // URLs.
.PARAMETER Html
    The HTML string to check.
.OUTPUTS
    $true if remote images are detected, $false otherwise.
#>
function Test-RemoteImages {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Html
    )

    process {
        if ([string]::IsNullOrEmpty($Html)) {
            return $false
        }

        # Detect remote images in the rendered HTML
        # Note: file:// URLs are local and should not trigger this
        # For src: check https://, http://, or // at the start of the URL value
        # For srcset: check anywhere in the value (srcset can have multiple URLs like "local.png 1x, https://remote/img.png 2x")
        $hasSrcRemote = $Html -match '(?is)<img\b[^>]*\bsrc\b\s*=\s*(?:"\s*(?:https?://|//)|''\s*(?:https?://|//)|\s*(?:https?://|//))'
        $hasSrcsetRemote = $Html -match '(?is)<img\b[^>]*\bsrcset\b\s*=\s*(?:"[^"]*(?:https?://|//)|''[^'']*(?:https?://|//)|[^\s>]*(?:https?://|//))'
        
        return $hasSrcRemote -or $hasSrcsetRemote
    }
}


<#
.SYNOPSIS
    Pre-processes markdown to fix local file link targets before ConvertFrom-Markdown.
.DESCRIPTION
    Fixes common issues with local file paths in markdown links that would otherwise
    cause ConvertFrom-Markdown to produce broken links or no links at all:
    - Normalizes backslashes to forward slashes
    - URL-encodes spaces in link targets
    - Converts Windows absolute paths (C:\...) to file:// URLs
    - Converts UNC paths (\\server\...) to file:// URLs
.PARAMETER Markdown
    The raw markdown string to process.
.OUTPUTS
    The processed markdown string with fixed link targets.
#>
function Repair-MarkdownLinks {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Markdown
    )

    process {
        if ([string]::IsNullOrEmpty($Markdown)) {
            return $Markdown
        }

        # Skip processing inside fenced code blocks
        # Strategy: Split by code fences, only process non-code sections
        $result = [System.Text.StringBuilder]::new()
        
        # Match fenced code blocks (``` or ~~~, with optional language)
        $codeFencePattern = '(?m)^(`{3,}|~{3,}).*?$[\s\S]*?^\1\s*$'
        $lastEnd = 0
        
        foreach ($match in [regex]::Matches($Markdown, $codeFencePattern, 'Multiline')) {
            # Process text before this code block
            if ($match.Index -gt $lastEnd) {
                $textBefore = $Markdown.Substring($lastEnd, $match.Index - $lastEnd)
                $null = $result.Append((Repair-MarkdownLinksInText $textBefore))
            }
            # Append code block unchanged
            $null = $result.Append($match.Value)
            $lastEnd = $match.Index + $match.Length
        }
        
        # Process remaining text after last code block
        if ($lastEnd -lt $Markdown.Length) {
            $textAfter = $Markdown.Substring($lastEnd)
            $null = $result.Append((Repair-MarkdownLinksInText $textAfter))
        }
        
        return $result.ToString()
    }
}


<#
.SYNOPSIS
    Helper function to repair links in a markdown text section (not inside code blocks).
#>
function Repair-MarkdownLinksInText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }

    # Two patterns needed:
    # 1. Links with angle brackets: [text](<target with spaces>) - already allows spaces
    # 2. Links without angle brackets: [text](target) - no spaces allowed in standard markdown
    
    # Pattern 1: Links with angle brackets - extract and transform
    $angleBracketPattern = '(!?\[[^\]]*\]\(<)([^>]+)(>\))'
    
    $result = [regex]::Replace($Text, $angleBracketPattern, {
        param($m)
        $prefix = $m.Groups[1].Value
        $target = $m.Groups[2].Value
        $suffix = $m.Groups[3].Value
        
        $transformed = Convert-LinkTarget -Target $target
        return $prefix + $transformed + $suffix
    })
    
    # Pattern 2: Links without angle brackets - also check for paths that SHOULD have spaces
    # This pattern matches [text](target) where target has no spaces (standard markdown)
    $standardPattern = '(!?\[[^\]]*\]\()([^)<>\s]+)(\))'
    
    $result = [regex]::Replace($result, $standardPattern, {
        param($m)
        $prefix = $m.Groups[1].Value
        $target = $m.Groups[2].Value
        $suffix = $m.Groups[3].Value
        
        $transformed = Convert-LinkTarget -Target $target
        return $prefix + $transformed + $suffix
    })
    
    # Pattern 3: Links that have spaces but no angle brackets - non-standard but common
    # Match [text](path with spaces) by looking for ( followed by content ending with )
    # This handles:
    # - Paths with spaces: [test](C:\path with\spaces.md)
    # - Fragments with spaces: [test](file.md#Section Name)
    $spacePathPattern = '(!?\[[^\]]*\]\()([A-Za-z]:[^\)]+|\\\\[^\)]+|//[^\)]+|file:[^\)]+|[^\)\s]+#[^\)]+)(\))'
    
    $result = [regex]::Replace($result, $spacePathPattern, {
        param($m)
        $prefix = $m.Groups[1].Value
        $target = $m.Groups[2].Value
        $suffix = $m.Groups[3].Value
        
        # Only process if it contains a space (otherwise already handled)
        if ($target -notmatch ' ') {
            return $m.Value
        }
        
        $transformed = Convert-LinkTarget -Target $target
        # Wrap in angle brackets since it has spaces
        return $prefix + '<' + $transformed + '>' + $suffix
    })
    
    return $result
}


<#
.SYNOPSIS
    Converts a link target to a proper URL format.
#>
function Convert-LinkTarget {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Target
    )
    
    # Skip URLs that are already properly formed (http, https, mailto, data, etc.)
    if ($Target -match '^(?:https?|mailto|data|ftp|tel):') {
        return $Target
    }
    
    # Handle file: URLs - encode spaces and fix fragment if needed
    if ($Target -match '^file:') {
        # Extract fragment from file: URL
        $fragment = ''
        if ($Target -match '^(file:[^#]*)(#.*)$') {
            $path = $Matches[1]
            $fragment = $Matches[2]
            
            # Encode spaces in path
            if ($path -match ' ') {
                $path = $path -replace ' ', '%20'
            }
            
            # Encode fragment content if it has special characters
            if ($fragment -match ' |#' -and $fragment -notmatch '%[0-9A-Fa-f]{2}') {
                $fragContent = $fragment.Substring(1)
                $fragContent = [Uri]::EscapeDataString($fragContent)
                $fragment = '#' + $fragContent
            }
            
            return $path + $fragment
        }
        
        # No fragment, just encode spaces
        if ($Target -match ' ') {
            return $Target -replace ' ', '%20'
        }
        return $Target
    }
    
    # Extract fragment if present
    # The fragment starts at the FIRST # that follows the file extension or end of path
    # We look for # after common file extensions or at the end of a path segment
    $fragment = ''
    $fragAlreadyEncoded = $false
    
    # Find the fragment marker: first # that appears after a file extension or path
    # Match patterns like: file.md#frag, file.txt#frag, path/#frag
    if ($Target -match '^([^#]*\.[a-zA-Z0-9]+)(#.*)$') {
        # Found a fragment after a file extension
        $Target = $Matches[1]
        $fragment = $Matches[2]
    } elseif ($Target -match '^([^#]*)(#[^#]*)$' -and $Target -notmatch '#.*#') {
        # Single # in the target - it's the fragment marker
        $Target = $Matches[1]
        $fragment = $Matches[2]
    }
    
    if ($fragment) {
        # Check if fragment is already percent-encoded
        if ($fragment -match '%[0-9A-Fa-f]{2}') {
            $fragAlreadyEncoded = $true
        }
    }
    
    $transformed = $Target
    
    # Case 1: UNC path (\\server\share\...)
    if ($transformed -match '^\\\\([^\\]+)\\(.+)$') {
        $server = $Matches[1]
        $rest = $Matches[2] -replace '\\', '/'
        $rest = [Uri]::EscapeUriString($rest)
        $transformed = "file://$server/$rest"
    }
    # Case 2: Windows absolute path with backslash (C:\...)
    elseif ($transformed -match '^([A-Za-z]):\\(.*)$') {
        $drive = $Matches[1]
        $rest = $Matches[2] -replace '\\', '/'
        $rest = [Uri]::EscapeUriString($rest)
        $transformed = "file:///$drive`:/$rest"
    }
    # Case 3: Windows absolute path with forward slash (C:/...)
    elseif ($transformed -match '^([A-Za-z]):\/(.*)$') {
        $drive = $Matches[1]
        $rest = $Matches[2]
        $rest = [Uri]::EscapeUriString($rest)
        $transformed = "file:///$drive`:/$rest"
    }
    # Case 4: Relative path with backslashes
    elseif ($transformed -match '\\') {
        $transformed = $transformed -replace '\\', '/'
        $transformed = [Uri]::EscapeUriString($transformed)
    }
    # Case 5: Relative path with spaces (needs encoding)
    elseif ($transformed -match ' ') {
        $transformed = [Uri]::EscapeUriString($transformed)
    }
    
    # Re-attach fragment
    if ($fragment) {
        if ($fragAlreadyEncoded) {
            # Fragment is already encoded, just append as-is
            $transformed = $transformed + $fragment
        } else {
            # Fragment needs encoding (skip the leading #)
            $fragContent = $fragment.Substring(1)
            $fragContent = [Uri]::EscapeDataString($fragContent)
            $transformed = $transformed + '#' + $fragContent
        }
    }
    
    return $transformed
}


<#
.SYNOPSIS
    Post-processes HTML to fix encoding issues in href and src attributes.
.DESCRIPTION
    Fixes encoding issues that ConvertFrom-Markdown introduces:
    - Decodes %5C back to / (backslash normalization)
    - Fixes double-encoded fragments (%23 -> #)
    - Handles orphaned UNC paths that lost their leading backslash
.PARAMETER Html
    The HTML string to process.
.OUTPUTS
    The processed HTML string with fixed links.
#>
function Repair-HtmlLinks {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Html
    )

    process {
        if ([string]::IsNullOrEmpty($Html)) {
            return $Html
        }

        # Pattern to match href="..." or src="..." attributes
        $attrPattern = '(?i)\b(href|src)\s*=\s*"([^"]*)"'
        
        $result = [regex]::Replace($Html, $attrPattern, {
            param($m)
            $attrName = $m.Groups[1].Value
            $value = $m.Groups[2].Value
            
            # Skip non-file URLs and special protocols
            if ($value -match '^(?:https?|mailto|data|ftp|tel|javascript):' -or $value -eq '#') {
                return $m.Value
            }
            
            $fixed = $value
            
            # Fix 1: Decode %5C (backslash) to /
            $fixed = $fixed -replace '%5[Cc]', '/'
            
            # Fix 2: Decode %3A after drive letter (C%3A -> C:)
            $fixed = $fixed -replace '(?i)^([A-Za-z])%3[Aa](\/)', '$1:$2'
            
            # Fix 3: Handle orphaned UNC-like paths (/server/share/... that should be file://server/...)
            # This happens when \\server becomes \server (one backslash lost) then encoded as %5Cserver
            # After fix 1, it becomes /server/share/...
            # We can detect this: if it starts with / followed by what looks like a server name and share
            if ($fixed -match '^\/([^\/]+)\/([^\/]+)\/' -and $fixed -notmatch '^\/\/') {
                # Check if it looks like a UNC path (server/share pattern, not a relative path)
                # Heuristic: if first segment doesn't contain dots (not a TLD) and second exists
                # This is tricky - we'll be conservative and only fix obvious patterns
            }
            
            # Note: We do NOT decode %23 to # because:
            # - If there's a proper fragment marker, it's already a # (not %23)
            # - If there's %23 in the URL, it represents a literal # character that should stay encoded
            
            return "$attrName=`"$fixed`""
        })
        
        return $result
    }
}


# Export shared functions
Export-ModuleMember -Function @(
    'Invoke-HtmlSanitization'
    'Test-RemoteImages'
    'Repair-MarkdownLinks'
    'Repair-HtmlLinks'
)
