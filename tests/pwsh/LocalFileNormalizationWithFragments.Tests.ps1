# LocalFileNormalizationWithFragments.Tests.ps1 - Pester tests for local file path normalization WITH fragments
# Tests the fragment handling documented in dev\docs\local-file-normalization.md
# Windows-only: Tests Get-FileBaseHref from Windows module with Windows paths
#
# For each path type, we test:
# 1. A fragment without special characters: #Intro
# 2. A fragment with special characters (space and #): #Section #1 -> #Section%20%231
#
# Fragment rules:
# - Do not URL-encode the leading # (it separates the fragment from the path)
# - Do URL-encode characters inside the fragment that are not URI-safe (spaces, #, %, etc.)
#
# The tests exercise the ACTUAL code:
# - Get-FileBaseHref from MarkdownViewer.psm1
# - [Uri] class for URL resolution (equivalent to JS new URL())
# - Fragment extraction logic pattern from Open-Markdown.ps1

#Requires -Version 7.0

# Skip entire file on non-Windows platforms
if (-not $IsWindows) {
    Write-Host "Skipping $(Split-Path -Leaf $PSCommandPath): Windows-only tests (Get-FileBaseHref, Windows paths)" -ForegroundColor Yellow
    return
}

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global

    <#
    .SYNOPSIS
        URL-encodes fragment content (but not the leading #).
    .DESCRIPTION
        Encodes special characters in the fragment that are not URI-safe.
        Uses [Uri]::EscapeDataString which matches browser behavior.
    #>
    function ConvertTo-EncodedFragment {
        [CmdletBinding()]
        param([string]$Fragment)
        
        if (-not $Fragment) { return '' }
        if (-not $Fragment.StartsWith('#')) { $Fragment = "#$Fragment" }
        
        # Get the content after the leading #
        $content = $Fragment.Substring(1)
        
        # Use [Uri]::EscapeDataString which encodes all non-safe characters
        # This matches browser/JavaScript encodeURIComponent behavior
        $encoded = [Uri]::EscapeDataString($content)
        
        return "#$encoded"
    }

    <#
    .SYNOPSIS
        Converts a path/URL to a mdview:file:// URI with optional fragment.
    .DESCRIPTION
        This function replicates the actual normalization logic used by MarkdownViewer,
        including fragment handling from Open-Markdown.ps1.
    #>
    function ConvertTo-MdviewUriWithFragment {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$InputPath,
            
            [string]$Fragment = '',
            
            [string]$BaseDir = 'C:\repo'
        )
        
        $h = $InputPath.Trim()
        
        # Skip in-page anchors and already-custom protocol
        if ($h.StartsWith('#') -or $h.ToLower().StartsWith('mdview:')) {
            return $h
        }
        
        # Extract existing fragment using the same pattern as Open-Markdown.ps1
        $existingFragment = ''
        if ($h -match '^(?i)file:') {
            try {
                $uri = [Uri]$h
                $existingFragment = $uri.Fragment  # includes leading '#', or empty
                if ($existingFragment) {
                    # Remove fragment from path for processing
                    $h = $h.Substring(0, $h.Length - $existingFragment.Length)
                }
            } catch {}
        } else {
            # For paths (not file: URLs), check for # fragment
            # This matches the logic in Open-Markdown.ps1
            $hashIdx = $h.IndexOf('#')
            if ($hashIdx -ge 0) {
                $existingFragment = $h.Substring($hashIdx)
                $h = $h.Substring(0, $hashIdx)
            }
        }
        
        # Use provided fragment (encoded) or preserve existing fragment
        $finalFragment = if ($Fragment) { 
            ConvertTo-EncodedFragment $Fragment 
        } elseif ($existingFragment) { 
            $existingFragment 
        } else { 
            '' 
        }
        
        # Get base URL using the actual module function
        $baseUrl = Get-FileBaseHref -FilePath (Join-Path $BaseDir 'dummy.md')
        
        $abs = $null
        
        # Handle different input formats
        if ($h -match '^(?i)file:') {
            try {
                $uri = [Uri]$h
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^[A-Za-z]:[\\/]') {
            try {
                $uri = [Uri]::new($h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^\\\\') {
            try {
                $uri = [Uri]::new($h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h -match '^//([^/]+)/(.+)$') {
            $uncPath = '\\' + $Matches[1] + '\' + $Matches[2].Replace('/', '\')
            try {
                $uri = [Uri]::new($uncPath)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h.StartsWith('/') -and -not $h.StartsWith('//')) {
            try {
                $uri = [Uri]::new([Uri]$baseUrl, $h)
                $abs = $uri.AbsoluteUri
            } catch {
                return $null
            }
        }
        elseif ($h.StartsWith('~')) {
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
            try {
                $resolved = [Uri]::new([Uri]$baseUrl, $h)
                $abs = $resolved.AbsoluteUri
            } catch {
                return $null
            }
        }
        
        if ($abs -and $abs.ToLower().StartsWith('file:')) {
            return "mdview:$abs$finalFragment"
        }
        
        return $null
    }
}

Describe 'Local File Path Normalization With Fragments' {
    
    # Test fragments: simple and with special characters
    BeforeAll {
        $script:SimpleFragment = 'Intro'
        $script:SpecialFragment = 'Section #1'  # Contains space and #
        $script:EncodedSpecialFragment = 'Section%20%231'
    }
    
    Context 'Relative paths with fragments (Both OS)' {
        # Row 1: subdir\docs\spec.md, subdir/docs/spec.md
        
        It 'Relative backslash path with simple fragment: subdir\docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'subdir\docs\spec.md' -Fragment '#Intro' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md#Intro'
        }
        
        It 'Relative backslash path with special fragment: subdir\docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'subdir\docs\spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md#Section%20%231'
        }
        
        It 'Relative forward-slash path with simple fragment: subdir/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'subdir/docs/spec.md' -Fragment '#Intro' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md#Intro'
        }
        
        It 'Relative forward-slash path with special fragment: subdir/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'subdir/docs/spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/repo/subdir/docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Relative paths with parent traversal and fragments (Both OS)' {
        # Row 2: ..\docs\spec.md, ../docs/spec.md
        
        It 'Parent traversal backslash with simple fragment: ..\docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '..\docs\spec.md' -Fragment '#Intro' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md#Intro'
        }
        
        It 'Parent traversal backslash with special fragment: ..\docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '..\docs\spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md#Section%20%231'
        }
        
        It 'Parent traversal forward-slash with simple fragment: ../docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '../docs/spec.md' -Fragment '#Intro' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md#Intro'
        }
        
        It 'Parent traversal forward-slash with special fragment: ../docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '../docs/spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo\subdir'
            $result | Should -Be 'mdview:file:///C:/repo/docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows absolute paths with drive letter and fragments' {
        # Row 3: C:\docs\spec.md, C:\My Docs\spec.md
        
        It 'Drive path without spaces, simple fragment: C:\docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:\docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Intro'
        }
        
        It 'Drive path without spaces, special fragment: C:\docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:\docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Section%20%231'
        }
        
        It 'Drive path with spaces, simple fragment: C:\My Docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:\My Docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Intro'
        }
        
        It 'Drive path with spaces, special fragment: C:\My Docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:\My Docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows UNC paths (network share) with fragments' {
        # Row 4: \\server\share\docs\spec.md, \\server\share\My Docs\spec.md
        
        It 'UNC path without spaces, simple fragment: \\server\share\docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\server\share\docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Intro'
        }
        
        It 'UNC path without spaces, special fragment: \\server\share\docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\server\share\docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Section%20%231'
        }
        
        It 'UNC path with spaces, simple fragment: \\server\share\My Docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\server\share\My Docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Intro'
        }
        
        It 'UNC path with spaces, special fragment: \\server\share\My Docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\server\share\My Docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows UNC paths (loopback share) with fragments' {
        # Row 5: \\localhost\share\docs\spec.md, \\localhost\share\My Docs\spec.md
        
        It 'Localhost UNC without spaces, simple fragment: \\localhost\share\docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\localhost\share\docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://localhost/share/docs/spec.md#Intro'
        }
        
        It 'Localhost UNC without spaces, special fragment: \\localhost\share\docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\localhost\share\docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://localhost/share/docs/spec.md#Section%20%231'
        }
        
        It 'Localhost UNC with spaces, simple fragment: \\localhost\share\My Docs\spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\localhost\share\My Docs\spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://localhost/share/My%20Docs/spec.md#Intro'
        }
        
        It 'Localhost UNC with spaces, special fragment: \\localhost\share\My Docs\spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '\\localhost\share\My Docs\spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://localhost/share/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows file: URL (local drive) with fragments' {
        # Row 6: file:///C:/docs/spec.md, file:///C:/My Docs/spec.md, file:///C:/My%20Docs/spec.md
        
        It 'file: URL without spaces, simple fragment: file:///C:/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Intro'
        }
        
        It 'file: URL without spaces, special fragment: file:///C:/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Section%20%231'
        }
        
        It 'file: URL with unencoded spaces, simple fragment: file:///C:/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/My Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Intro'
        }
        
        It 'file: URL with unencoded spaces, special fragment: file:///C:/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/My Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Section%20%231'
        }
        
        It 'file: URL with encoded spaces, simple fragment: file:///C:/My%20Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/My%20Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Intro'
        }
        
        It 'file: URL with encoded spaces, special fragment: file:///C:/My%20Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/My%20Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows file: URL (UNC/share form) with fragments' {
        # Row 7: file://server/share/docs/spec.md, file://server/share/My Docs/spec.md, file://server/share/My%20Docs/spec.md
        
        It 'file: URL for UNC without spaces, simple fragment: file://server/share/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Intro'
        }
        
        It 'file: URL for UNC without spaces, special fragment: file://server/share/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Section%20%231'
        }
        
        It 'file: URL for UNC with unencoded spaces, simple fragment: file://server/share/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/My Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Intro'
        }
        
        It 'file: URL for UNC with unencoded spaces, special fragment: file://server/share/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/My Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Section%20%231'
        }
        
        It 'file: URL for UNC with encoded spaces, simple fragment: file://server/share/My%20Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/My%20Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Intro'
        }
        
        It 'file: URL for UNC with encoded spaces, special fragment: file://server/share/My%20Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file://server/share/My%20Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows absolute path with forward slashes and fragments' {
        # Row 8: C:/docs/spec.md, C:/My Docs/spec.md
        
        It 'Forward-slash drive path without spaces, simple fragment: C:/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Intro'
        }
        
        It 'Forward-slash drive path without spaces, special fragment: C:/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#Section%20%231'
        }
        
        It 'Forward-slash drive path with spaces, simple fragment: C:/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:/My Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Intro'
        }
        
        It 'Forward-slash drive path with spaces, special fragment: C:/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:/My Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///C:/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Windows UNC-like with forward slashes and fragments' {
        # Row 9: //server/share/docs/spec.md, //server/share/My Docs/spec.md
        
        It 'Forward-slash UNC without spaces, simple fragment: //server/share/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '//server/share/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Intro'
        }
        
        It 'Forward-slash UNC without spaces, special fragment: //server/share/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '//server/share/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/docs/spec.md#Section%20%231'
        }
        
        It 'Forward-slash UNC with spaces, simple fragment: //server/share/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '//server/share/My Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Intro'
        }
        
        It 'Forward-slash UNC with spaces, special fragment: //server/share/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '//server/share/My Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file://server/share/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Linux absolute path (POSIX) with fragments' {
        # Row 10: /home/user/docs/spec.md, /home/user/My Docs/spec.md
        # NOTE: On Windows, POSIX paths resolve against the base URL's drive
        
        It 'POSIX path without spaces, simple fragment: /home/user/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '/home/user/docs/spec.md' -Fragment '#Intro' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/docs/spec.md#Intro'
        }
        
        It 'POSIX path without spaces, special fragment: /home/user/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '/home/user/docs/spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/docs/spec.md#Section%20%231'
        }
        
        It 'POSIX path with spaces, simple fragment: /home/user/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '/home/user/My Docs/spec.md' -Fragment '#Intro' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/My%20Docs/spec.md#Intro'
        }
        
        It 'POSIX path with spaces, special fragment: /home/user/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '/home/user/My Docs/spec.md' -Fragment '#Section #1' -BaseDir 'C:\repo'
            $result | Should -Be 'mdview:file:///C:/home/user/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Linux file: URL (POSIX) with fragments' {
        # Row 11: file:///home/user/docs/spec.md, file:///home/user/My Docs/spec.md, file:///home/user/My%20Docs/spec.md
        
        It 'Linux file: URL without spaces, simple fragment: file:///home/user/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///home/user/docs/spec.md#Intro'
        }
        
        It 'Linux file: URL without spaces, special fragment: file:///home/user/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///home/user/docs/spec.md#Section%20%231'
        }
        
        It 'Linux file: URL with unencoded spaces, simple fragment: file:///home/user/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/My Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md#Intro'
        }
        
        It 'Linux file: URL with unencoded spaces, special fragment: file:///home/user/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/My Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md#Section%20%231'
        }
        
        It 'Linux file: URL with encoded spaces, simple fragment: file:///home/user/My%20Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/My%20Docs/spec.md' -Fragment '#Intro'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md#Intro'
        }
        
        It 'Linux file: URL with encoded spaces, special fragment: file:///home/user/My%20Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///home/user/My%20Docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be 'mdview:file:///home/user/My%20Docs/spec.md#Section%20%231'
        }
    }
    
    Context 'Linux home-relative path with fragments' {
        # Row 12: ~/docs/spec.md, ~/My Docs/spec.md
        
        BeforeAll {
            $script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $script:HomeUri = ([Uri]::new($script:HomeDir)).AbsoluteUri.TrimEnd('/')
        }
        
        It 'Home-relative path without spaces, simple fragment: ~/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '~/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md#Intro"
        }
        
        It 'Home-relative path without spaces, special fragment: ~/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '~/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md#Section%20%231"
        }
        
        It 'Home-relative path with spaces, simple fragment: ~/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '~/My Docs/spec.md' -Fragment '#Intro'
            $expected = "mdview:$($script:HomeUri)/My%20Docs/spec.md#Intro"
            $result | Should -Be $expected
        }
        
        It 'Home-relative path with spaces, special fragment: ~/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '~/My Docs/spec.md' -Fragment '#Section #1'
            $expected = "mdview:$($script:HomeUri)/My%20Docs/spec.md#Section%20%231"
            $result | Should -Be $expected
        }
    }
    
    Context 'Linux env-var path with fragments' {
        # Row 13: $HOME/docs/spec.md, $HOME/My Docs/spec.md
        
        BeforeAll {
            $script:HomeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
            $script:HomeUri = ([Uri]::new($script:HomeDir)).AbsoluteUri.TrimEnd('/')
        }
        
        It '$HOME path without spaces, simple fragment: $HOME/docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '$HOME/docs/spec.md' -Fragment '#Intro'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md#Intro"
        }
        
        It '$HOME path without spaces, special fragment: $HOME/docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '$HOME/docs/spec.md' -Fragment '#Section #1'
            $result | Should -Be "mdview:$($script:HomeUri)/docs/spec.md#Section%20%231"
        }
        
        It '$HOME path with spaces, simple fragment: $HOME/My Docs/spec.md#Intro' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '$HOME/My Docs/spec.md' -Fragment '#Intro'
            $expected = "mdview:$($script:HomeUri)/My%20Docs/spec.md#Intro"
            $result | Should -Be $expected
        }
        
        It '$HOME path with spaces, special fragment: $HOME/My Docs/spec.md#Section #1' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath '$HOME/My Docs/spec.md' -Fragment '#Section #1'
            $expected = "mdview:$($script:HomeUri)/My%20Docs/spec.md#Section%20%231"
            $result | Should -Be $expected
        }
    }
    
    Context 'Preserve existing fragments in paths' {
        # Test that existing fragments are preserved as-is when no new fragment is provided
        
        It 'Preserves existing simple fragment: C:\docs\spec.md#section-2' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'C:\docs\spec.md#section-2'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#section-2'
        }
        
        It 'Preserves existing fragment in file: URL: file:///C:/docs/spec.md#section-2' {
            $result = ConvertTo-MdviewUriWithFragment -InputPath 'file:///C:/docs/spec.md#section-2'
            $result | Should -Be 'mdview:file:///C:/docs/spec.md#section-2'
        }
    }
}

Describe 'Fragment Encoding Helper Function' {
    
    It 'Encodes space as %20' {
        $result = ConvertTo-EncodedFragment '#Section 1'
        $result | Should -Be '#Section%201'
    }
    
    It 'Encodes # as %23' {
        $result = ConvertTo-EncodedFragment '#Section#2'
        $result | Should -Be '#Section%232'
    }
    
    It 'Encodes both space and # correctly' {
        $result = ConvertTo-EncodedFragment '#Section #1'
        $result | Should -Be '#Section%20%231'
    }
    
    It 'Does not encode the leading #' {
        $result = ConvertTo-EncodedFragment '#Intro'
        $result | Should -Be '#Intro'
        $result | Should -Match '^#[^%]'  # Leading # should not be encoded
    }
    
    It 'Handles fragment without leading #' {
        $result = ConvertTo-EncodedFragment 'Intro'
        $result | Should -Be '#Intro'
    }
    
    It 'Encodes % as %25' {
        $result = ConvertTo-EncodedFragment '#50%off'
        $result | Should -Be '#50%25off'
    }
}
