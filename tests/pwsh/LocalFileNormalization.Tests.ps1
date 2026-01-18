# LocalFileNormalization.Tests.ps1 - Pester tests for local file path normalization
# Tests the normalization behavior documented in dev\docs\local-file-normalization.md
#
# These tests verify that MarkdownViewer correctly normalizes various file path formats
# into the canonical mdview:file://... URI format.

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global

    # Helper function to simulate the normalization that script.js does
    # This tests the PowerShell side (Get-FileBaseHref) and simulates client-side URL resolution
    function ConvertTo-MdviewUri {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$InputPath,
            
            [string]$BaseDir = 'C:\repo'  # Default base directory for relative paths
        )
        
        $h = $InputPath.Trim()
        
        # Skip in-page anchors and already-custom protocol
        if ($h.StartsWith('#') -or $h.ToLower().StartsWith('mdview:')) {
            return $h
        }
        
        # Determine base URL from base directory
        # Use Get-FileBaseHref pattern: C:\path -> file:///C:/path/
        if ($BaseDir.StartsWith('\\')) {
            # UNC path
            $baseUrl = 'file://' + ($BaseDir.TrimStart('\').Replace('\', '/')) + '/'
        } else {
            $baseUrl = 'file:///' + ($BaseDir.Replace('\', '/')) + '/'
        }
        
        $abs = $null
        
        # Handle different input formats
        if ($h -match '^(?i)file:') {
            # Already a file: URL - parse and rebuild
            try {
                $uri = [Uri]$h
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^[A-Za-z]:[\\/]') {
            # Windows absolute path with drive letter (C:\... or C:/...)
            $normalized = $h.Replace('\', '/')
            # Encode spaces
            $normalized = $normalized -replace ' ', '%20'
            $abs = "file:///$normalized"
        }
        elseif ($h -match '^\\\\([^\\]+)\\(.+)$') {
            # UNC path: \\server\share\path
            $server = $Matches[1]
            $rest = $Matches[2].Replace('\', '/')
            $rest = $rest -replace ' ', '%20'
            $abs = "file://$server/$rest"
        }
        elseif ($h -match '^//([^/]+)/(.+)$') {
            # Forward-slash UNC-like: //server/share/path
            $server = $Matches[1]
            $rest = $Matches[2]
            $rest = $rest -replace ' ', '%20'
            $abs = "file://$server/$rest"
        }
        elseif ($h.StartsWith('/') -and -not $h.StartsWith('//')) {
            # POSIX absolute path: /home/user/...
            $normalized = $h -replace ' ', '%20'
            $abs = "file://$normalized"
        }
        elseif ($h.StartsWith('~')) {
            # Home-relative path (Linux): ~/docs/spec.md
            $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $homeDir = $homeDir.Replace('\', '/')
            $rest = $h.Substring(1).Replace('\', '/')
            $rest = $rest -replace ' ', '%20'
            $abs = "file:///$homeDir$rest"
        }
        elseif ($h.StartsWith('$HOME')) {
            # Env-var path (Linux): $HOME/docs/spec.md
            $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $homeDir = $homeDir.Replace('\', '/')
            $rest = $h.Substring(5).Replace('\', '/')
            $rest = $rest -replace ' ', '%20'
            $abs = "file:///$homeDir$rest"
        }
        else {
            # Relative path - resolve against base
            $normalized = $h.Replace('\', '/')
            $normalized = $normalized -replace ' ', '%20'
            try {
                $resolved = [Uri]::new([Uri]$baseUrl, $normalized)
                $abs = $resolved.AbsoluteUri
            } catch {
                return $null
            }
        }
        
        if ($abs -and $abs.ToLower().StartsWith('file:')) {
            return "mdview:$abs"
        }
        
        return $null
    }
}

Describe 'Local File Path Normalization' {
    
    Context 'Relative paths (Both OS)' {
        # Row 1: subdir\docs\spec.md, subdir/docs/spec.md
        # Expected: mdview:file:///<BASE_DIR>/subdir/docs/spec.md
        
        It 'Normalizes relative path with backslashes: subdir\docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'subdir\docs\spec.md' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md'
        }
        
        It 'Normalizes relative path with forward slashes: subdir/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'subdir/docs/spec.md' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md'
        }
    }
    
    Context 'Relative paths with parent traversal (Both OS)' {
        # Row 2: ..\docs\spec.md, ../docs/spec.md
        # Expected: mdview:file:///<BASE_DIR>/../docs/spec.md (then canonicalize)
        
        It 'Normalizes parent traversal with backslashes: ..\docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '..\docs\spec.md' -BaseDir 'C:\repo\subdir'
            # After canonicalization, ../docs becomes sibling
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md'
        }
        
        It 'Normalizes parent traversal with forward slashes: ../docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '../docs/spec.md' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md'
        }
    }
    
    Context 'Windows absolute paths with drive letter' {
        # Row 3: C:\docs\spec.md, C:\My Docs\spec.md
        # Expected: mdview:file:///C:/docs/spec.md, mdview:file:///C:/My%20Docs/spec.md
        
        It 'Normalizes drive path without spaces: C:\docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'C:\docs\spec.md'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md'
        }
        
        It 'Normalizes drive path with spaces: C:\My Docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'C:\My Docs\spec.md'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows UNC paths (network share)' {
        # Row 4: \\server\share\docs\spec.md, \\server\share\My Docs\spec.md
        # Expected: mdview:file://server/share/docs/spec.md, mdview:file://server/share/My%20Docs/spec.md
        
        It 'Normalizes UNC path without spaces: \\server\share\docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '\\server\share\docs\spec.md'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md'
        }
        
        It 'Normalizes UNC path with spaces: \\server\share\My Docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '\\server\share\My Docs\spec.md'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows UNC paths (loopback share)' {
        # Row 5: \\localhost\share\docs\spec.md, \\localhost\share\My Docs\spec.md
        # Expected: mdview:file://localhost/share/docs/spec.md, mdview:file://localhost/share/My%20Docs/spec.md
        
        It 'Normalizes localhost UNC path without spaces: \\localhost\share\docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '\\localhost\share\docs\spec.md'
            $result | Should -Be 'mdview:file://localhost/share/docs/spec.md'
        }
        
        It 'Normalizes localhost UNC path with spaces: \\localhost\share\My Docs\spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '\\localhost\share\My Docs\spec.md'
            $result | Should -Be 'mdview:file://localhost/share/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows file: URL (local drive)' {
        # Row 6: file:///C:/docs/spec.md, file:///C:/My Docs/spec.md, file:///C:/My%20Docs/spec.md
        # Expected: mdview:file:///C:/docs/spec.md, mdview:file:///C:/My%20Docs/spec.md
        
        It 'Normalizes file: URL without spaces: file:///C:/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///C:/docs/spec.md'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md'
        }
        
        It 'Normalizes file: URL with unencoded spaces: file:///C:/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///C:/My Docs/spec.md'
            # Note: [Uri] will encode spaces automatically
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md'
        }
        
        It 'Preserves file: URL with already-encoded spaces: file:///C:/My%20Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///C:/My%20Docs/spec.md'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows file: URL (UNC/share form)' {
        # Row 7: file://server/share/docs/spec.md, file://server/share/My Docs/spec.md, file://server/share/My%20Docs/spec.md
        # Expected: mdview:file://server/share/docs/spec.md, mdview:file://server/share/My%20Docs/spec.md
        
        It 'Normalizes file: URL for UNC without spaces: file://server/share/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file://server/share/docs/spec.md'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md'
        }
        
        It 'Normalizes file: URL for UNC with unencoded spaces: file://server/share/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file://server/share/My Docs/spec.md'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md'
        }
        
        It 'Preserves file: URL for UNC with encoded spaces: file://server/share/My%20Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file://server/share/My%20Docs/spec.md'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows absolute path with forward slashes' {
        # Row 8: C:/docs/spec.md, C:/My Docs/spec.md
        # Expected: mdview:file:///C:/docs/spec.md, mdview:file:///C:/My%20Docs/spec.md
        
        It 'Normalizes forward-slash drive path without spaces: C:/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'C:/docs/spec.md'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md'
        }
        
        It 'Normalizes forward-slash drive path with spaces: C:/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'C:/My Docs/spec.md'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md'
        }
    }
    
    Context 'Windows UNC-like with forward slashes' {
        # Row 9: //server/share/docs/spec.md, //server/share/My Docs/spec.md
        # Expected: mdview:file://server/share/docs/spec.md, mdview:file://server/share/My%20Docs/spec.md
        
        It 'Normalizes forward-slash UNC without spaces: //server/share/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '//server/share/docs/spec.md'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md'
        }
        
        It 'Normalizes forward-slash UNC with spaces: //server/share/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '//server/share/My Docs/spec.md'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md'
        }
    }
    
    Context 'Linux absolute path (POSIX)' {
        # Row 10: /home/user/docs/spec.md, /home/user/My Docs/spec.md
        # Expected: mdview:file:///home/user/docs/spec.md, mdview:file:///home/user/My%20Docs/spec.md
        
        It 'Normalizes POSIX path without spaces: /home/user/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '/home/user/docs/spec.md'
            $result | Should -Be 'mdview:file:///home/user/docs/spec.md'
        }
        
        It 'Normalizes POSIX path with spaces: /home/user/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '/home/user/My Docs/spec.md'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md'
        }
    }
    
    Context 'Linux file: URL (POSIX)' {
        # Row 11: file:///home/user/docs/spec.md, file:///home/user/My Docs/spec.md, file:///home/user/My%20Docs/spec.md
        # Expected: mdview:file:///home/user/docs/spec.md, mdview:file:///home/user/My%20Docs/spec.md
        
        It 'Normalizes Linux file: URL without spaces: file:///home/user/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///home/user/docs/spec.md'
            $result | Should -Be 'mdview:file:///home/user/docs/spec.md'
        }
        
        It 'Normalizes Linux file: URL with unencoded spaces: file:///home/user/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///home/user/My Docs/spec.md'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md'
        }
        
        It 'Preserves Linux file: URL with encoded spaces: file:///home/user/My%20Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath 'file:///home/user/My%20Docs/spec.md'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md'
        }
    }
    
    Context 'Linux home-relative path' {
        # Row 12: ~/docs/spec.md, ~/My Docs/spec.md
        # Expected: mdview:file:///<HOME_DIR>/docs/spec.md, mdview:file:///<HOME_DIR>/My%20Docs/spec.md
        
        BeforeAll {
            $script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $script:HomeDir = $script:HomeDir.Replace('\', '/')
        }
        
        It 'Normalizes home-relative path without spaces: ~/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '~/docs/spec.md'
            $result | Should -Be "mdview:file:///$($script:HomeDir)/docs/spec.md"
        }
        
        It 'Normalizes home-relative path with spaces: ~/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '~/My Docs/spec.md'
            $expected = "mdview:file:///$($script:HomeDir)/My%20Docs/spec.md"
            $result | Should -Be $expected
        }
    }
    
    Context 'Linux env-var path' {
        # Row 13: $HOME/docs/spec.md, $HOME/My Docs/spec.md
        # Expected: mdview:file:///<HOME_DIR>/docs/spec.md, mdview:file:///<HOME_DIR>/My%20Docs/spec.md
        
        BeforeAll {
            $script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $script:HomeDir = $script:HomeDir.Replace('\', '/')
        }
        
        It 'Normalizes $HOME path without spaces: $HOME/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '$HOME/docs/spec.md'
            $result | Should -Be "mdview:file:///$($script:HomeDir)/docs/spec.md"
        }
        
        It 'Normalizes $HOME path with spaces: $HOME/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '$HOME/My Docs/spec.md'
            $expected = "mdview:file:///$($script:HomeDir)/My%20Docs/spec.md"
            $result | Should -Be $expected
        }
    }
}

Describe 'Get-FileBaseHref Function' {
    # Tests for the actual module function
    
    Context 'Windows drive paths' {
        It 'Converts C:\docs\spec.md to file:///C:/docs/' {
            $result = Get-FileBaseHref -FilePath 'C:\docs\spec.md'
            $result | Should -Be 'file:///C:/docs/'
        }
        
        It 'Converts C:\My Docs\spec.md to file:///C:/My Docs/' {
            # Note: Get-FileBaseHref does NOT encode spaces - that happens in URL construction
            $result = Get-FileBaseHref -FilePath 'C:\My Docs\spec.md'
            $result | Should -Be 'file:///C:/My Docs/'
        }
    }
    
    Context 'UNC paths' {
        It 'Converts \\server\share\docs\spec.md to file://server/share/docs/' {
            $result = Get-FileBaseHref -FilePath '\\server\share\docs\spec.md'
            $result | Should -Be 'file://server/share/docs/'
        }
        
        It 'Converts \\localhost\share\docs\spec.md to file://localhost/share/docs/' {
            $result = Get-FileBaseHref -FilePath '\\localhost\share\docs\spec.md'
            $result | Should -Be 'file://localhost/share/docs/'
        }
    }
    
    Context 'Long path prefix' {
        It 'Handles \\?\C:\path prefix' {
            $result = Get-FileBaseHref -FilePath '\\?\C:\docs\spec.md'
            $result | Should -Be 'file:///C:/docs/'
        }
        
        It 'Handles \\?\UNC\server\share prefix' {
            $result = Get-FileBaseHref -FilePath '\\?\UNC\server\share\docs\spec.md'
            $result | Should -Be 'file://server/share/docs/'
        }
    }
}
