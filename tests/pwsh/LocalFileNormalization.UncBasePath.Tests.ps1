# LocalFileNormalization.UncBasePath.Tests.ps1
# Tests for link normalization when the markdown file is opened from a UNC path.
# Windows-only: UNC paths are a Windows-specific concept
#
# When a file is accessed via UNC path in PowerShell (e.g., \\localhost\c$\repo\file.md),
# PowerShell's Split-Path may return a PSProvider-prefixed path like:
#   Microsoft.PowerShell.Core\FileSystem::\\localhost\c$\repo
#
# This test file documents bugs where the PSProvider prefix leaks into the base href.

#Requires -Version 7.0

# Skip entire file on non-Windows platforms
if (-not $IsWindows) {
    Write-Host "Skipping $(Split-Path -Leaf $PSCommandPath): Windows-only tests (UNC paths)" -ForegroundColor Yellow
    return
}

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global
}

Describe 'Get-FileBaseHref with UNC Paths' {
    # Tests for Get-FileBaseHref when given UNC paths directly
    
    Context 'Standard UNC paths' {
        
        It 'Handles \\server\share\path correctly' {
            $result = Get-FileBaseHref -FilePath '\\server\share\docs\spec.md'
            $result | Should -Be 'file://server/share/docs/'
        }
        
        It 'Handles \\localhost\c$\path correctly' {
            $result = Get-FileBaseHref -FilePath '\\localhost\c$\repo\subdir\spec.md'
            $result | Should -Be 'file://localhost/c$/repo/subdir/'
        }
    }
    
    Context 'PSProvider-prefixed paths (bug scenario)' {
        # When PowerShell accesses a UNC path, Split-Path may return paths with 
        # PSProvider prefixes that should be stripped
        
        It 'Should strip Microsoft.PowerShell.Core\FileSystem:: prefix from UNC path' {
            $psProviderPath = 'Microsoft.PowerShell.Core\FileSystem::\\localhost\c$\repo\subdir\spec.md'
            $result = Get-FileBaseHref -FilePath $psProviderPath
            # IDEAL: should produce clean file:// URL without PSProvider prefix
            $result | Should -Be 'file://localhost/c$/repo/subdir/'
        }
        
        It 'Should strip FileSystem:: prefix from UNC path' {
            $psProviderPath = 'FileSystem::\\server\share\docs\spec.md'
            $result = Get-FileBaseHref -FilePath $psProviderPath
            $result | Should -Be 'file://server/share/docs/'
        }
    }
}

Describe 'Full Pipeline with UNC Base Path - Ideal Behavior' {
    # Tests that simulate opening a markdown file from a UNC path
    # and verifying link resolution works correctly
    
    BeforeAll {
        # Simulate base URL when file is opened from \\localhost\c$\repo\subdir\
        # CURRENT BUG: produces Microsoft.PowerShell.Core/FileSystem:://localhost/c$/...
        # IDEAL: should produce file://localhost/c$/repo/subdir/
        $script:IdealBaseUrl = 'file://localhost/c$/repo/subdir/'
        
        # What the buggy code currently produces
        $script:BuggyBaseUrl = 'file:///Microsoft.PowerShell.Core/FileSystem:://localhost/c$/repo/subdir/'
        
        <#
        .SYNOPSIS
            Extracts the href attribute from HTML produced by ConvertFrom-Markdown.
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
            Resolves a link against a base URL and returns the final URL.
        #>
        function script:Get-ResolvedUrl {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [string]$LinkTarget,
                
                [Parameter(Mandatory)]
                [string]$BaseUrl
            )
            
            $href = Get-MarkdownLinkHref -LinkTarget $LinkTarget
            if ($null -eq $href) { return $null }
            
            try {
                $resolved = [Uri]::new([Uri]$BaseUrl, $href)
                return $resolved.AbsoluteUri
            } catch {
                return "[ERROR]"
            }
        }
    }
    
    Context 'Relative paths from UNC base' {
        
        It 'Forward-slash relative path resolves correctly from UNC base' {
            $result = Get-ResolvedUrl -LinkTarget 'docs/spec.md' -BaseUrl $script:IdealBaseUrl
            $result | Should -Be 'file://localhost/c$/repo/subdir/docs/spec.md'
        }
        
        It 'Parent traversal resolves correctly from UNC base' {
            $result = Get-ResolvedUrl -LinkTarget '../docs/spec.md' -BaseUrl $script:IdealBaseUrl
            $result | Should -Be 'file://localhost/c$/repo/docs/spec.md'
        }
    }
}

Describe 'Get-FileBaseHref PSProvider Stripping - Ideal Behavior' {
    # These tests assert the IDEAL behavior where PSProvider prefixes are stripped.
    # Currently they FAIL, documenting bugs to fix.
    
    It 'Get-FileBaseHref should strip PSProvider prefix from path' {
        # Simulate what happens when PowerShell gives us a PSProvider-prefixed path
        $psProviderPath = 'Microsoft.PowerShell.Core\FileSystem::\\localhost\c$\repo\subdir\spec.md'
        $result = Get-FileBaseHref -FilePath $psProviderPath
        
        # IDEAL: clean file:// URL
        $result | Should -Be 'file://localhost/c$/repo/subdir/'
        # Should NOT contain PSProvider prefix
        $result | Should -Not -Match 'Microsoft\.PowerShell\.Core'
        $result | Should -Not -Match 'FileSystem:'
    }
}
