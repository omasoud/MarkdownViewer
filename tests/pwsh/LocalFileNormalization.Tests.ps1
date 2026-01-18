# LocalFileNormalization.Tests.ps1 - Pester tests for local file path normalization
# Tests the normalization behavior documented in dev\docs\local-file-normalization.md
#
# These tests verify that MarkdownViewer correctly normalizes various file path formats
# into the canonical mdview:file://... URI format.
#
# The tests exercise the ACTUAL code:
# - Get-FileBaseHref from MarkdownViewer.psm1
# - [Uri] class for URL resolution (equivalent to JS new URL())
# - Fragment extraction logic pattern from Open-Markdown.ps1

#Requires -Version 7.0

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global

    <#
    .SYNOPSIS
        Converts a relative or absolute path/URL to a mdview:file:// URI.
    .DESCRIPTION
        This function replicates the actual normalization logic used by MarkdownViewer:
        1. Get-FileBaseHref (from MarkdownViewer.psm1) converts file paths to file:// base URLs
        2. [Uri]::new() resolves relative URLs against the base (same as JS new URL())
        3. The result is prefixed with "mdview:" for the custom protocol
    .NOTES
        This exercises the real Get-FileBaseHref function and .NET Uri resolution,
        which is equivalent to the JavaScript URL resolution in script.js.
    #>
    function ConvertTo-MdviewUri {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$InputPath,
            
            [string]$BaseDir = 'C:\repo'
        )
        
        $h = $InputPath.Trim()
        
        # Skip in-page anchors and already-custom protocol (matches script.js logic)
        if ($h.StartsWith('#') -or $h.ToLower().StartsWith('mdview:')) {
            return $h
        }
        
        # Get base URL using the actual module function
        # We need a fake "file" in the base dir to get the directory URL
        $baseUrl = Get-FileBaseHref -FilePath (Join-Path $BaseDir 'dummy.md')
        
        $abs = $null
        
        # Handle different input formats - this mirrors script.js rewriteMarkdownLinks()
        if ($h -match '^(?i)file:') {
            # Already a file: URL - use [Uri] to normalize (handles encoding)
            try {
                $uri = [Uri]$h
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^[A-Za-z]:[\\/]') {
            # Windows absolute path with drive letter - convert to file: URL
            # [Uri] constructor handles the conversion
            try {
                $uri = [Uri]::new($h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^\\\\') {
            # UNC path: \\server\share\path - convert to file: URL
            try {
                $uri = [Uri]::new($h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^//([^/]+)/(.+)$') {
            # Forward-slash UNC-like: //server/share/path
            # Convert to proper UNC then to URI
            $uncPath = '\\' + $Matches[1] + '\' + $Matches[2].Replace('/', '\')
            try {
                $uri = [Uri]::new($uncPath)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h.StartsWith('/') -and -not $h.StartsWith('//')) {
            # POSIX absolute path: /home/user/...
            # This is what JS new URL() would produce with a file:// base
            try {
                $uri = [Uri]::new([Uri]$baseUrl, $h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h.StartsWith('~')) {
            # Home-relative path (Linux): ~/docs/spec.md
            $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $expandedPath = $homeDir + $h.Substring(1)
            try {
                $uri = [Uri]::new($expandedPath)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h.StartsWith('$HOME')) {
            # Env-var path (Linux): $HOME/docs/spec.md
            $homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $expandedPath = $homeDir + $h.Substring(5)
            try {
                $uri = [Uri]::new($expandedPath)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        else {
            # Relative path - resolve against base using [Uri] (same as JS new URL(href, base))
            try {
                $resolved = [Uri]::new([Uri]$baseUrl, $h)
                $abs = $resolved.AbsoluteUri
            } catch {
                return $null
            }
        }
        
        # Only return mdview: URI for file: URLs (matches script.js logic)
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
            # [Uri] canonicalizes the path, removing the ..
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
            # [Uri] will encode spaces automatically
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
        # NOTE: On Windows, POSIX paths resolve against the base URL's drive
        
        It 'Normalizes POSIX path without spaces: /home/user/docs/spec.md' {
            # On Windows with base C:\repo, /home resolves to C:/home
            $result = ConvertTo-MdviewUri -InputPath '/home/user/docs/spec.md' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/docs/spec.md'
        }
        
        It 'Normalizes POSIX path with spaces: /home/user/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '/home/user/My Docs/spec.md' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/My%20Docs/spec.md'
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
            # Get what [Uri] produces for the home dir
            $script:HomeUri = ([Uri]::new($script:HomeDir)).AbsoluteUri.TrimEnd('/')
        }
        
        It 'Normalizes home-relative path without spaces: ~/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '~/docs/spec.md'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md"
        }
        
        It 'Normalizes home-relative path with spaces: ~/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '~/My Docs/spec.md'
            $result | Should -Be "mdview:$($script:HomeUri)/My%20Docs/spec.md"
        }
    }
    
    Context 'Linux env-var path' {
        # Row 13: $HOME/docs/spec.md, $HOME/My Docs/spec.md
        # Expected: mdview:file:///<HOME_DIR>/docs/spec.md, mdview:file:///<HOME_DIR>/My%20Docs/spec.md
        
        BeforeAll {
            $script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $script:HomeUri = ([Uri]::new($script:HomeDir)).AbsoluteUri.TrimEnd('/')
        }
        
        It 'Normalizes $HOME path without spaces: $HOME/docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '$HOME/docs/spec.md'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md"
        }
        
        It 'Normalizes $HOME path with spaces: $HOME/My Docs/spec.md' {
            $result = ConvertTo-MdviewUri -InputPath '$HOME/My Docs/spec.md'
            $result | Should -Be "mdview:$($script:HomeUri)/My%20Docs/spec.md"
        }
    }
}

Describe 'Get-FileBaseHref Function (Direct Module Tests)' {
    # Tests for the actual module function directly
    
    Context 'Windows drive paths' {
        It 'Converts C:\docs\spec.md to file:///C:/docs/' {
            $result = Get-FileBaseHref -FilePath 'C:\docs\spec.md'
            $result | Should -Be 'file:///C:/docs/'
        }
        
        It 'Converts C:\My Docs\spec.md to file:///C:/My Docs/' {
            # Note: Get-FileBaseHref does NOT encode spaces - that's handled by Uri later
            $result = Get-FileBaseHref -FilePath 'C:\My Docs\spec.md'
            $result | Should -Be 'file:///C:/My Docs/'
        }
        
        It 'Handles nested directories: C:\repo\subdir\docs\spec.md' {
            $result = Get-FileBaseHref -FilePath 'C:\repo\subdir\docs\spec.md'
            $result | Should -Be 'file:///C:/repo/subdir/docs/'
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
        
        It 'Handles UNC path with spaces: \\server\share\My Docs\spec.md' {
            $result = Get-FileBaseHref -FilePath '\\server\share\My Docs\spec.md'
            $result | Should -Be 'file://server/share/My Docs/'
        }
    }
    
    Context 'Long path prefix (\\?\)' {
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

Describe 'Uri Class Behavior (Foundation for URL Resolution)' {
    # These tests verify the .NET Uri class behavior that our normalization relies on
    # This is the same behavior as JavaScript's new URL() in the browser
    
    Context 'Relative URL resolution' {
        It 'Resolves relative path against base' {
            $base = [Uri]'file:///C:/repo/'
            $resolved = [Uri]::new($base, 'subdir/spec.md')
            $resolved.AbsoluteUri | Should -Be 'file:///C:/repo/subdir/spec.md'
        }
        
        It 'Resolves parent traversal (..) correctly' {
            $base = [Uri]'file:///C:/repo/subdir/'
            $resolved = [Uri]::new($base, '../docs/spec.md')
            $resolved.AbsoluteUri | Should -Be 'file:///C:/repo/docs/spec.md'
        }
        
        It 'Encodes spaces in resolved URLs' {
            $base = [Uri]'file:///C:/repo/'
            $resolved = [Uri]::new($base, 'My Docs/spec.md')
            $resolved.AbsoluteUri | Should -Be 'file:///C:/repo/My%20Docs/spec.md'
        }
    }
    
    Context 'Absolute path handling' {
        It 'Converts Windows path to file: URL' {
            $uri = [Uri]::new('C:\docs\spec.md')
            $uri.AbsoluteUri | Should -Be 'file:///C:/docs/spec.md'
        }
        
        It 'Converts UNC path to file: URL' {
            $uri = [Uri]::new('\\server\share\docs\spec.md')
            $uri.AbsoluteUri | Should -Be 'file://server/share/docs/spec.md'
        }
        
        It 'Encodes spaces in paths' {
            $uri = [Uri]::new('C:\My Docs\spec.md')
            $uri.AbsoluteUri | Should -Be 'file:///C:/My%20Docs/spec.md'
        }
    }
}
