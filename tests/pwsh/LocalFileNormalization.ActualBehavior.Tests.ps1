# LocalFileNormalization.ActualBehavior.Tests.ps1
# Tests that verify ConvertFrom-Markdown produces IDEAL link behavior.
# These tests FAIL when bugs exist, documenting what needs fixing.

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    <#
    .SYNOPSIS
        Extracts the href attribute from HTML produced by ConvertFrom-Markdown.
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
        
        if ($html -match '<a\s+href="([^"]*)"') {
            return $Matches[1]
        }
        return '[NOT_A_LINK]'
    }
    
    <#
    .SYNOPSIS
        Simulates what new URL(href, base).href produces.
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
            return "[ERROR]"
        }
    }
}

Describe 'ConvertFrom-Markdown Link Processing - Ideal Behavior' {
    # These tests verify IDEAL behavior. Failures indicate bugs to fix.
    
    BeforeAll {
        $script:BaseUrl = 'file:///C:/repo/subdir/'
    }
    
    Context 'Relative paths' {
        
        It 'Backslash relative path should produce working href' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'docs\spec.md'
            # IDEAL: backslash should be converted to forward slash, not encoded
            $href | Should -Be 'docs/spec.md'
        }
        
        It 'Forward-slash relative path produces working href' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'docs/spec.md'
            $href | Should -Be 'docs/spec.md'
        }
    }
    
    Context 'Parent traversal (..)' {
        
        It 'Backslash parent traversal should produce working href' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '..\docs\spec.md'
            # IDEAL: backslash should be converted to forward slash
            $href | Should -Be '../docs/spec.md'
        }
        
        It 'Forward-slash parent traversal produces working href' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '../docs/spec.md'
            $href | Should -Be '../docs/spec.md'
        }
    }
    
    Context 'Windows absolute paths (C:\)' {
        
        It 'Windows absolute path should convert to file: URL' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:\docs\spec.md'
            # IDEAL: should become file:///C:/docs/spec.md
            $href | Should -Be 'file:///C:/docs/spec.md'
        }
        
        It 'Windows path with spaces should become link with encoded spaces' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:\My Docs\spec.md'
            # IDEAL: should create link with %20 encoding
            $href | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows forward-slash absolute paths (C:/)' {
        
        It 'C:/ path should convert to file: URL' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'C:/docs/spec.md'
            # IDEAL: should become file:///C:/docs/spec.md
            $href | Should -Be 'file:///C:/docs/spec.md'
        }
    }
    
    Context 'UNC paths (\\server)' {
        
        It 'UNC path should convert to file: URL' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '\\server\share\docs\spec.md'
            # IDEAL: should become file://server/share/docs/spec.md
            $href | Should -Be 'file://server/share/docs/spec.md'
        }
        
        It 'UNC path with spaces should become link with encoded spaces' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '\\server\share\My Docs\spec.md'
            # IDEAL: should create link with %20 encoding
            $href | Should -Be 'file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'Forward-slash UNC paths (//server)' {
        
        It '//server path should convert to file: URL' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget '//server/share/docs/spec.md'
            # IDEAL: should become file://server/share/docs/spec.md
            $href | Should -Be 'file://server/share/docs/spec.md'
        }
    }
    
    Context 'file: URLs (should work)' {
        
        It 'file:/// URL href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file:///C:/docs/spec.md'
            $href | Should -Be 'file:///C:/docs/spec.md'
        }
        
        It 'file:// UNC URL href is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file://server/share/docs/spec.md'
            $href | Should -Be 'file://server/share/docs/spec.md'
        }
        
        It 'file:/// URL with encoded spaces is preserved' {
            $href = Get-MarkdownLinkHref -LinkText 'spec' -LinkTarget 'file:///C:/My%20Docs/spec.md'
            $href | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
}
