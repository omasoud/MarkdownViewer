# LocalFileNormalization.ActualBehavior.Tests.ps1
# Tests documenting the ACTUAL behavior of ConvertFrom-Markdown link processing
# These tests document bugs - they will need updating when bugs are fixed.
#
# The difference between this and LocalFileNormalization.Tests.ps1:
# - LocalFileNormalization.Tests.ps1 tests IDEAL behavior (what SHOULD happen)
# - This file tests ACTUAL behavior (what ConvertFrom-Markdown DOES produce)

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    <#
    .SYNOPSIS
        Extracts the href attribute from HTML produced by ConvertFrom-Markdown.
    .DESCRIPTION
        Takes a markdown link, converts it via ConvertFrom-Markdown, and extracts
        the resulting href value to see what the markdown parser actually produces.
    #>
    function Get-MarkdownLinkHref {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$LinkText,
            
            [Parameter(Mandatory)]
            [string]$LinkTarget
        )
        
        $markdown = "[$LinkText]($LinkTarget)"
        $html = (ConvertFrom-Markdown -InputObject $markdown).Html
        
        # Extract href from <a href="...">
        if ($html -match '<a\s+href="([^"]*)"') {
            return $Matches[1]
        }
        
        # If no <a> tag found, return special marker
        return '[NOT_A_LINK]'
    }
    
    <#
    .SYNOPSIS
        Simulates what new URL(href, base).href produces in JavaScript.
    .DESCRIPTION
        Takes an href (as produced by ConvertFrom-Markdown) and a base URL,
        and returns what the browser/JS would produce.
    #>
    function Resolve-JsUrl {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Href,
            
            [Parameter(Mandatory)]
            [string]$BaseUrl
        )
        
        if ($Href -eq '[NOT_A_LINK]') {
            return '[NOT_A_LINK]'
        }
        
        try {
            $base = [Uri]$BaseUrl
            $resolved = [Uri]::new($base, $Href)
            return $resolved.AbsoluteUri
        } catch {
            return "[ERROR: $_]"
        }
    }
}

Describe 'ConvertFrom-Markdown Actual Link Behavior' {
    # These tests document what ConvertFrom-Markdown ACTUALLY produces
    # Many of these are BUGS that need fixing
    
    BeforeAll {
        $script:BaseUrl = 'file:///C:/repo/subdir/'
    }
    
    Context 'Relative paths - Backslash handling' {
        
        It 'ACTUAL: Backslash relative path gets URL-encoded (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'subdir\docs\spec.md'
            # ConvertFrom-Markdown encodes \ as %5C instead of converting to /
            $href | Should -Be 'subdir%5Cdocs%5Cspec.md'
        }
        
        It 'ACTUAL: Forward-slash relative path works correctly' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'subdir/docs/spec.md'
            $href | Should -Be 'subdir/docs/spec.md'
        }
        
        It 'ACTUAL: Resolved backslash URL - .NET decodes %5C to / (but JS may differ)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'subdir\docs\spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            # .NET Uri decodes %5C to / during resolution, but browser JS keeps %5C
            # This test documents .NET behavior; actual browser behavior differs
            $resolved | Should -Be 'file:///C:/repo/subdir/subdir/docs/spec.md'
        }
        
        It 'ACTUAL: Resolved forward-slash URL is correct' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'subdir/docs/spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            $resolved | Should -Be 'file:///C:/repo/subdir/subdir/docs/spec.md'
        }
    }
    
    Context 'Parent traversal (..)' {
        
        It 'ACTUAL: Backslash parent traversal encodes backslash (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '..\docs\spec.md'
            $href | Should -Be '..%5Cdocs%5Cspec.md'
        }
        
        It 'ACTUAL: Forward-slash parent traversal works' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '../docs/spec.md'
            $href | Should -Be '../docs/spec.md'
        }
    }
    
    Context 'Windows absolute paths (C:\)' {
        
        It 'ACTUAL: Windows absolute path encodes backslashes (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:\docs\spec.md'
            # Backslashes become %5C, colon stays
            $href | Should -Be 'C:%5Cdocs%5Cspec.md'
        }
        
        It 'ACTUAL: Windows path with spaces is NOT converted to link (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:\My Docs\spec.md'
            # Markdown parser fails to create link when URL has unescaped spaces
            $href | Should -Be '[NOT_A_LINK]'
        }
        
        It 'ACTUAL: Resolved C:\ URL - .NET errors on invalid scheme' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:\docs\spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            # .NET Uri fails because C: looks like a scheme but %5C is invalid
            # Browser JS would resolve this differently
            $resolved | Should -Match '^\[ERROR'
        }
    }
    
    Context 'Windows forward-slash absolute paths (C:/)' {
        
        It 'ACTUAL: C:/ path href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:/docs/spec.md'
            $href | Should -Be 'C:/docs/spec.md'
        }
        
        It 'ACTUAL: Resolved C:/ URL - .NET treats as absolute file URL' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:/docs/spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            # .NET Uri interprets C: as a scheme with / path start
            # This actually resolves to file:///C:/docs/spec.md - surprisingly correct!
            $resolved | Should -Be 'file:///C:/docs/spec.md'
        }
    }
    
    Context 'UNC paths (\\server)' {
        
        It 'ACTUAL: UNC path loses first backslash (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '\\server\share\docs\spec.md'
            # First \ is lost/escaped by markdown parser, second becomes %5C
            $href | Should -Be '%5Cserver%5Cshare%5Cdocs%5Cspec.md'
        }
        
        It 'ACTUAL: UNC path with spaces is NOT converted to link (BUG)' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '\\server\share\My Docs\spec.md'
            $href | Should -Be '[NOT_A_LINK]'
        }
    }
    
    Context 'Forward-slash UNC paths (//server)' {
        
        It 'ACTUAL: //server path href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '//server/share/docs/spec.md'
            $href | Should -Be '//server/share/docs/spec.md'
        }
        
        It 'ACTUAL: Resolved //server URL inherits file: scheme' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '//server/share/docs/spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            # Protocol-relative URL inherits scheme from base - this actually works!
            $resolved | Should -Be 'file://server/share/docs/spec.md'
        }
    }
    
    Context 'file: URLs (should work)' {
        
        It 'ACTUAL: file:/// URL href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file:///C:/docs/spec.md'
            $href | Should -Be 'file:///C:/docs/spec.md'
        }
        
        It 'ACTUAL: file:// UNC URL href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file://server/share/docs/spec.md'
            $href | Should -Be 'file://server/share/docs/spec.md'
        }
        
        It 'ACTUAL: file:/// URL with encoded spaces works' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file:///C:/My%20Docs/spec.md'
            $href | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
        
        It 'ACTUAL: file:/// URL resolves correctly' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file:///C:/docs/spec.md'
            $resolved = Resolve-JsUrl -Href $href -BaseUrl $script:BaseUrl
            $resolved | Should -Be 'file:///C:/docs/spec.md'
        }
    }
}

Describe 'Summary: Bug Categories' {
    # This describe block summarizes the bugs found
    
    It 'BUG: Backslashes are URL-encoded to %5C instead of converted to forward slashes' {
        # Affects: relative paths with \, parent traversal with \, Windows paths, UNC paths
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
    
    It 'BUG: Paths with unescaped spaces do not render as links' {
        # Affects: Any path containing spaces without %20 encoding
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
    
    It 'BUG: UNC paths (\\server) lose the first backslash' {
        # The leading \\ becomes %5C (single backslash)
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
    
    It 'BUG: Windows absolute paths (C:\, C:/) are treated as relative' {
        # No recognition of drive letters as absolute paths
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
    
    It 'WORKS: file: URLs work correctly' {
        # Workaround: Use file:///C:/path or file://server/share/path
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
    
    It 'WORKS: Forward-slash UNC (//server) inherits file: scheme from base' {
        # This accidentally works via protocol-relative URL behavior
        $true | Should -BeTrue -Because 'This is a documentation test'
    }
}
