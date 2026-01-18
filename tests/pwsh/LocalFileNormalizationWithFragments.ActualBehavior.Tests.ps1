# LocalFileNormalizationWithFragments.ActualBehavior.Tests.ps1
# Tests for the ACTUAL behavior of ConvertFrom-Markdown + URL resolution with fragments.
#
# This file tests the full pipeline: ConvertFrom-Markdown (renders href) + URL resolution.
# Tests assert IDEAL behavior - failures document bugs that need fixing.
#
# Key findings from testing:
# 1. Simple fragments (#section-1) work fine with forward-slash paths
# 2. Unencoded special characters in fragments (#Section #1) break links (space in href)
# 3. Pre-encoded fragments (#Section%20%231) work correctly
# 4. Backslash paths have the same issues as non-fragment tests (%5C encoding)

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global

    <#
    .SYNOPSIS
        Extracts the href attribute from HTML produced by ConvertFrom-Markdown.
    .RETURNS
        The href value, or $null if no anchor was created.
    #>
    function script:Get-MarkdownLinkHref {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$LinkTarget
        )
        
        $markdown = "[test]($LinkTarget)"
        $html = (ConvertFrom-Markdown -InputObject $markdown).Html
        
        if ($html -match '<a\s+href="([^"]*)"') {
            return $Matches[1]
        }
        return $null
    }

    <#
    .SYNOPSIS
        Simulates the full URL resolution pipeline with a base URL.
    .DESCRIPTION
        Gets the href from ConvertFrom-Markdown, then resolves against base URL.
        Returns the final resolved URL or $null if not a link.
    #>
    function script:Get-ResolvedLinkUrl {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$LinkTarget,
            
            [string]$BaseDir = 'C:\repo\subdir'
        )
        
        $href = Get-MarkdownLinkHref -LinkTarget $LinkTarget
        if ($null -eq $href) { return $null }
        
        # Get base URL using the actual module function
        $baseUrl = Get-FileBaseHref -FilePath (Join-Path $BaseDir 'test.md')
        
        try {
            $resolved = [Uri]::new([Uri]$baseUrl, $href)
            return $resolved.AbsoluteUri
        } catch {
            return "[ERROR: $($_.Exception.Message)]"
        }
    }
}

Describe 'Full Pipeline with Fragments - Ideal Behavior' {
    # Tests assert IDEAL behavior. Failures document bugs.
    
    BeforeAll {
        $script:SimpleFragment = '#section-1'
        $script:SpecialFragment = '#Section #1'
        $script:EncodedSpecialFragment = '#Section%20%231'
    }
    
    Context 'Forward-slash relative paths with fragments' {
        
        It 'Forward-slash path with simple fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs/spec.md#section-1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md#section-1'
        }
        
        It 'Forward-slash path with pre-encoded special fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs/spec.md#Section%20%231' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md#Section%20%231'
        }
        
        It 'Forward-slash path with unencoded special fragment should resolve correctly' {
            # IDEAL: Should create a link and resolve, but ConvertFrom-Markdown breaks on unencoded space
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs/spec.md#Section #1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Backslash relative paths with fragments' {
        # Backslash paths have same issues as non-fragment tests (backslash encoded as %5C)
        
        It 'Backslash path with simple fragment should resolve correctly' {
            # IDEAL: backslash normalized to forward slash
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs\spec.md#section-1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md#section-1'
        }
        
        It 'Backslash path with pre-encoded special fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'docs\spec.md#Section%20%231' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/subdir/docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Parent traversal with fragments' {
        
        It 'Forward-slash parent traversal with simple fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget '../docs/spec.md#section-1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/docs/spec.md#section-1'
        }
        
        It 'Forward-slash parent traversal with pre-encoded special fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget '../docs/spec.md#Section%20%231' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/docs/spec.md#Section%20%231'
        }
        
        It 'Backslash parent traversal with simple fragment should resolve correctly' {
            # IDEAL: backslash normalized, .. resolved
            $result = Get-ResolvedLinkUrl -LinkTarget '..\docs\spec.md#section-1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'file:///C:/repo/docs/spec.md#section-1'
        }
    }
    
    Context 'file:/// URLs with fragments' {
        
        It 'file:/// URL with simple fragment should pass through correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/docs/spec.md#section-1'
            $result | Should -Be 'file:///C:/docs/spec.md#section-1'
        }
        
        It 'file:/// URL with pre-encoded special fragment should pass through correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/docs/spec.md#Section%20%231'
            $result | Should -Be 'file:///C:/docs/spec.md#Section%20%231'
        }
        
        It 'file:/// URL with unencoded special fragment should work' {
            # IDEAL: Should create a link, but space in href breaks it
            $result = Get-ResolvedLinkUrl -LinkTarget 'file:///C:/docs/spec.md#Section #1'
            $result | Should -Be 'file:///C:/docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows absolute paths with fragments' {
        
        It 'C:/ path with simple fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:/docs/spec.md#section-1'
            $result | Should -Be 'file:///C:/docs/spec.md#section-1'
        }
        
        It 'C:/ path with pre-encoded special fragment should resolve correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:/docs/spec.md#Section%20%231'
            $result | Should -Be 'file:///C:/docs/spec.md#Section%20%231'
        }
        
        It 'C:\ path with simple fragment should resolve correctly' {
            # IDEAL: backslash normalized
            $result = Get-ResolvedLinkUrl -LinkTarget 'C:\docs\spec.md#section-1'
            $result | Should -Be 'file:///C:/docs/spec.md#section-1'
        }
    }
    
    Context 'file:// UNC URLs with fragments' {
        
        It 'file:// UNC URL with simple fragment should pass through correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file://server/share/docs/spec.md#section-1'
            $result | Should -Be 'file://server/share/docs/spec.md#section-1'
        }
        
        It 'file:// UNC URL with pre-encoded special fragment should pass through correctly' {
            $result = Get-ResolvedLinkUrl -LinkTarget 'file://server/share/docs/spec.md#Section%20%231'
            $result | Should -Be 'file://server/share/docs/spec.md#Section%20%231'
        }
    }
}

Describe 'ConvertFrom-Markdown Fragment Handling' {
    # Direct tests of ConvertFrom-Markdown's href output for fragments
    
    Context 'Simple fragments (no special characters)' {
        
        It 'Should preserve simple fragment: #section-1' {
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#section-1'
            $href | Should -Be 'docs/spec.md#section-1'
        }
        
        It 'Should preserve simple fragment: #introduction' {
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#introduction'
            $href | Should -Be 'docs/spec.md#introduction'
        }
    }
    
    Context 'Pre-encoded special fragments' {
        
        It 'Should preserve pre-encoded fragment: #Section%20%231' {
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#Section%20%231'
            $href | Should -Be 'docs/spec.md#Section%20%231'
        }
        
        It 'Should preserve pre-encoded space: #section%201' {
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#section%201'
            $href | Should -Be 'docs/spec.md#section%201'
        }
    }
    
    Context 'Unencoded special fragments (BUG: breaks links)' {
        
        It 'IDEAL: Fragment with space should create a link' {
            # BUG: Unencoded space in href causes ConvertFrom-Markdown to not create a link
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#Section 1'
            $href | Should -Not -BeNullOrEmpty
            $href | Should -Be 'docs/spec.md#Section%201'
        }
        
        It 'IDEAL: Fragment with # should create a link' {
            # BUG: Unencoded # in fragment causes ConvertFrom-Markdown issues
            $href = Get-MarkdownLinkHref -LinkTarget 'docs/spec.md#Section #1'
            $href | Should -Not -BeNullOrEmpty
            $href | Should -Be 'docs/spec.md#Section%20%231'
        }
    }
}
