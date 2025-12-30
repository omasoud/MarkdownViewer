# MarkdownViewer.psm1 - Shared functions for Markdown Viewer

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
    Gets the base href for a file path.
.DESCRIPTION
    Converts a Windows file path to a file:// URL for use as the base href.
.PARAMETER FilePath
    The file path to convert.
.OUTPUTS
    The file:// URL string.
#>
function Get-FileBaseHref {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $dir = Split-Path -LiteralPath $FilePath

    if ($dir.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\?\UNC\server\share\path -> file://server/share/path/
        $unc = $dir.Substring(8)
        return 'file://' + ($unc.Replace('\', '/')) + '/'
    }

    if ($dir.StartsWith('\\', [StringComparison]::OrdinalIgnoreCase) -and
        -not $dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\server\share\path -> file://server/share/path/
        return 'file://' + ($dir.TrimStart('\').Replace('\', '/')) + '/'
    }

    if ($dir.StartsWith('\\?\', [StringComparison]::OrdinalIgnoreCase)) {
        # \\?\C:\path -> file:///C:/path/
        $norm = $dir.Substring(4)
        return 'file:///' + ($norm.Replace('\', '/')) + '/'
    }

    # C:\path -> file:///C:/path/
    return 'file:///' + ($dir.Replace('\', '/')) + '/'
}


<#
.SYNOPSIS
    Tests if a file has a Mark-of-the-Web (MOTW) zone identifier.
.DESCRIPTION
    Reads the Zone.Identifier alternate data stream to determine the security zone.
.PARAMETER FilePath
    The file path to check.
.OUTPUTS
    The zone ID (0-4) or $null if no zone identifier exists.
#>
function Test-Motw {
    [CmdletBinding()]
    [OutputType([System.Nullable[int]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $adsPath = $FilePath + ":Zone.Identifier"
    
    if (-not (Test-Path -LiteralPath $adsPath)) {
        return $null
    }
    
    try {
        $content = Get-Content -LiteralPath $adsPath -ErrorAction Stop
        foreach ($line in $content) {
            if ($line -match '^ZoneId=(\d+)') {
                return [int]$Matches[1]
            }
        }
    }
    catch {
        return $null
    }
    return $null
}


# Export functions
Export-ModuleMember -Function @(
    'Invoke-HtmlSanitization'
    'Test-RemoteImages'
    'Get-FileBaseHref'
    'Test-Motw'
)
