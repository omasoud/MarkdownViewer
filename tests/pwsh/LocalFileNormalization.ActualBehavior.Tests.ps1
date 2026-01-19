# LocalFileNormalization.ActualBehavior.Tests.ps1
# Tests that verify the FULL PIPELINE produces correct file: URLs.
# Pipeline: Repair-MarkdownLinks → ConvertFrom-Markdown → Repair-HtmlLinks → URL resolution
#
# These tests assert IDEAL behavior. All tests should pass when the fix is implemented.

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    # Import the module with the repair functions
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    Import-Module $ModulePath -Force -Global
    
    <#
    .SYNOPSIS
        Extracts the href attribute from HTML produced by the full pipeline.
        Uses Repair-MarkdownLinks before ConvertFrom-Markdown and Repair-HtmlLinks after.
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
        
        # Full pipeline: repair markdown → convert → repair HTML
        $markdown = Repair-MarkdownLinks -Markdown $markdown
        $html = (ConvertFrom-Markdown -InputObject $markdown).Html
        $html = Repair-HtmlLinks -Html $html
        
        if ($html -match '<a\s+href="([^"]*)"') {
            return $Matches[1]
        }
        return $null  # No link created
    }
    
    <#
    .SYNOPSIS
        Simulates the full pipeline: Repair → ConvertFrom-Markdown → Repair → URL resolution.
        Returns the final resolved URL (without mdview: prefix for comparison).
    #>
    function Get-ResolvedLinkUrl {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$LinkTarget,
            
            [Parameter(Mandatory)]
            [string]$BaseUrl
        )
        
        $href = Get-MarkdownLinkHref -LinkText 'test' -LinkTarget $LinkTarget
        
        if ($null -eq $href) {
            return $null  # Link not created by markdown parser
        }
        
        # Simulate script.js: new URL(href, base).href
        try {
            $base = [Uri]$BaseUrl
            $resolved = [Uri]::new($base, $href)
            return $resolved.AbsoluteUri
        } catch {
            return "[RESOLUTION_ERROR]"
        }
    }
}

Describe 'Full Pipeline Link Resolution - Ideal Behavior' {
    # Tests verify the ENTIRE pipeline produces correct URLs.
    # Failures indicate bugs in ConvertFrom-Markdown or resolution logic.
    
    BeforeAll {
        # Base URL simulating a file opened from C:\repo\subdir\test.md
        $script:BaseUrl = 'file:///C:/repo/subdir/'
    }
    
    Context 'Relative paths' {
        
        It 'Backslash relative path should resolve correctly: docs\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md'
        }
        
        It 'Forward-slash relative path resolves correctly: docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md'
        }
    }
    
    Context 'Parent traversal (..)' {
        
        It 'Backslash parent traversal should resolve correctly: ..\docs\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '..\docs\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/repo/docs/spec.md'
        }
        
        It 'Forward-slash parent traversal resolves correctly: ../docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '../docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/repo/docs/spec.md'
        }
    }
    
    Context 'Windows absolute paths with backslash (C:\)' {
        
        It 'C:\ path should resolve to file: URL: C:\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/spec.md'
        }
        
        It 'C:\ path with spaces should create link and resolve: C:\My Docs\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:\My Docs\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows absolute paths with forward slash (C:/)' {
        
        It 'C:/ path resolves to file: URL: C:/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/spec.md'
        }
        
        It 'C:/ path with spaces should create link and resolve: C:/My Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:/My Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'UNC paths with backslash (\\server)' {
        
        It 'UNC path should resolve to file: URL: \\server\share\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '\\server\share\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/spec.md'
        }
        
        It 'UNC path with spaces should create link and resolve: \\server\share\My Docs\spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '\\server\share\My Docs\spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'UNC-like paths with forward slash (//server)' {
        
        It '//server path resolves to file: URL: //server/share/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '//server/share/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/spec.md'
        }
        
        It '//server path with spaces should create link and resolve: //server/share/My Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget '//server/share/My Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'file:/// URLs (local drive)' {
        
        It 'file:/// URL resolves correctly: file:///C:/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/spec.md'
        }
        
        It 'file:/// URL with unencoded spaces should create link: file:///C:/My Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/My Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
        
        It 'file:/// URL with encoded spaces resolves correctly: file:///C:/My%20Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/My%20Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'file:// URLs (UNC form)' {
        
        It 'file:// UNC URL resolves correctly: file://server/share/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file://server/share/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/spec.md'
        }
        
        It 'file:// UNC URL with unencoded spaces should create link: file://server/share/My Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file://server/share/My Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/My%20Docs/spec.md'
        }
        
        It 'file:// UNC URL with encoded spaces resolves correctly: file://server/share/My%20Docs/spec.md' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file://server/share/My%20Docs/spec.md' -BaseUrl $script:BaseUrl
            $result | Should -Be 'file://server/share/My%20Docs/spec.md'
        }
    }
}
