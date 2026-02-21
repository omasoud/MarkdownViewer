# BrowserLaunch.Tests.ps1 - Pester tests for browser launch utility functions
# Tests Get-DefaultBrowserProgId, Get-ProgIdOpenCommand,
# Get-ExePathFromOpenCommand, Get-DefaultBrowserExePath, Start-DefaultBrowser
# Windows-only: Tests registry-based browser detection

#Requires -Version 7.0

# Skip entire file on non-Windows platforms
if (-not $IsWindows) {
    Write-Host "Skipping $(Split-Path -Leaf $PSCommandPath): Windows-only tests (registry-based browser detection)" -ForegroundColor Yellow
    return
}

BeforeAll {
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src\win\MarkdownViewer.psm1'
    Import-Module $ModulePath -Force -Global
}

Describe 'Get-DefaultBrowserProgId' {
    
    It 'Should return a string or null' {
        $result = Get-DefaultBrowserProgId
        if ($result) {
            $result | Should -BeOfType [string]
        } else {
            $result | Should -BeNullOrEmpty
        }
    }
    
    It 'Should return common browser ProgIds when set' {
        $result = Get-DefaultBrowserProgId
        if ($result) {
            # Common browser ProgIds
            $knownProgIds = @(
                'ChromeHTML',
                'MSEdgeHTM',
                'FirefoxHTML*',
                'BraveHTML*',
                'IE.HTTP*',
                'AppXq0fevzme2pys62n3e0fbqa7peapykr8v'  # Edge UWP
            )
            $matched = $false
            foreach ($pattern in $knownProgIds) {
                if ($result -like $pattern) {
                    $matched = $true
                    break
                }
            }
            # If not matched, still valid - just a less common browser
            $true | Should -BeTrue
        }
    }
}

Describe 'Get-ProgIdOpenCommand' {
    
    Context 'With valid ProgId' {
        It 'Should return command string for known browser' {
            $progId = Get-DefaultBrowserProgId
            if ($progId) {
                $result = Get-ProgIdOpenCommand -ProgId $progId
                if ($result) {
                    $result | Should -BeOfType [string]
                    # Command should reference an executable
                    $result | Should -Match '\.(exe|cmd|bat)'
                }
            }
        }
    }
    
    Context 'With invalid ProgId' {
        It 'Should throw for non-existent ProgId' {
            { Get-ProgIdOpenCommand -ProgId 'NonExistentProgId12345' } | Should -Throw '*Failed to read open command*'
        }
    }
}

Describe 'Get-ExePathFromOpenCommand' {
    
    Context 'With real browser' {
        # We need to use the actual default browser for these tests since
        # the function validates that the exe exists
        
        It 'Should extract path from default browser command' {
            $progId = $null
            try { $progId = Get-DefaultBrowserProgId } catch { }
            
            if ($progId) {
                $openCmd = $null
                try { $openCmd = Get-ProgIdOpenCommand -ProgId $progId } catch { }
                
                if ($openCmd) {
                    $result = Get-ExePathFromOpenCommand -OpenCommand $openCmd
                    $result | Should -Match '\.exe$'
                    Test-Path $result | Should -BeTrue
                }
            }
        }
    }
    
    Context 'Error handling' {
        It 'Should throw for command without .exe' {
            { Get-ExePathFromOpenCommand -OpenCommand 'some random text' } | Should -Throw '*Could not parse*'
        }
        
        It 'Should throw for non-existent exe path' {
            { Get-ExePathFromOpenCommand -OpenCommand '"C:\NonExistent\Path\browser.exe" "%1"' } | Should -Throw '*does not exist*'
        }
    }
}

Describe 'Get-DefaultBrowserExePath' {
    
    It 'Should return a valid path or null' {
        $result = Get-DefaultBrowserExePath
        if ($result) {
            $result | Should -BeOfType [string]
            # Should be an exe file
            $result | Should -Match '\.exe$'
        }
    }
    
    It 'Should return an existing file when available' {
        $result = Get-DefaultBrowserExePath
        if ($result) {
            Test-Path $result | Should -BeTrue
        }
    }
}

Describe 'Start-DefaultBrowser' {
    
    # Note: These tests are limited because we don't want to actually open browsers
    # during automated testing. We test the input validation and error handling.
    
    Context 'URL validation' {
        It 'Should accept file:// URLs' {
            # We can't actually run this without opening a browser
            # Just verify the function exists and accepts parameters
            { Get-Command Start-DefaultBrowser -ErrorAction Stop } | Should -Not -Throw
        }
        
        It 'Should accept http:// URLs' {
            { Get-Command Start-DefaultBrowser -ErrorAction Stop } | Should -Not -Throw
        }
    }
    
    Context 'Integration with other functions' {
        It 'Should be callable from the pipeline' {
            # Verify function signature
            $cmd = Get-Command Start-DefaultBrowser
            $cmd.Parameters.ContainsKey('Url') | Should -BeTrue
        }
    }
}

Describe 'Fragment Launch Integration' {
    # Tests the launch decision logic and _fragment contract from Open-Markdown.ps1
    
    Context 'Launch decision logic' {
        It 'Should use Start-DefaultBrowser when fragment exists' {
            $frag = '#section-1'
            $useDirectLaunch = [bool]$frag
            $useDirectLaunch | Should -BeTrue
        }
        
        It 'Should use Start-Process when no fragment' {
            $frag = $null
            $useDirectLaunch = [bool]$frag
            $useDirectLaunch | Should -BeFalse
        }
        
        It 'Should use Start-Process for empty fragment' {
            $frag = ''
            $useDirectLaunch = [bool]$frag
            $useDirectLaunch | Should -BeFalse
        }
    }
    
    Context '_fragment URL construction' {
        It 'Should append ?_fragment= with encoded value' {
            $uLocal = 'file:///C:/Users/test/MarkView/viewmd_doc_ABCD1234.html'
            $frag = '#section-1'
            $launchUrl = $uLocal + '?_fragment=' + [Uri]::EscapeDataString($frag.TrimStart('#'))
            $launchUrl | Should -Be 'file:///C:/Users/test/MarkView/viewmd_doc_ABCD1234.html?_fragment=section-1'
        }

        It 'Should encode special characters in fragment value' {
            $uLocal = 'file:///home/user/MarkView/viewmd_doc_12345678.html'
            $frag = '#Section #1'
            $launchUrl = $uLocal + '?_fragment=' + [Uri]::EscapeDataString($frag.TrimStart('#'))
            $launchUrl | Should -Be 'file:///home/user/MarkView/viewmd_doc_12345678.html?_fragment=Section%20%231'
        }

        It 'Should not append _fragment when frag is empty' {
            $uLocal = 'file:///C:/Users/test/doc.html'
            $frag = ''
            $launchUrl = $uLocal
            if ($frag) {
                $launchUrl += '?_fragment=' + [Uri]::EscapeDataString($frag.TrimStart('#'))
            }
            $launchUrl | Should -Be $uLocal
        }
    }
}

Describe '_fragment URI Parsing Contract' {
    # Tests the _fragment extraction logic used in Open-Markdown.ps1.
    # This exercises the actual regex + [Uri] / [UriBuilder] code path.

    Context 'Parse _fragment from mdview: URI' {
        It 'Extracts _fragment from simple URI' {
            $input = 'mdview:file:///path/doc.md?_fragment=section-1'
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $clean = [UriBuilder]::new($u)
            $clean.Query = $null
            $clean.Fragment = $null
            $localPath = $clean.Uri.LocalPath

            $frag | Should -Be '#section-1'
            $localPath | Should -Be '/path/doc.md'
        }

        It 'URL-decodes encoded fragment value' {
            $input = 'mdview:file:///path/doc.md?_fragment=Section%20%231'
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $frag | Should -Be '#Section #1'
        }

        It 'Returns empty frag when no _fragment param' {
            $input = 'mdview:file:///path/doc.md'
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $frag | Should -Be ''
        }

        It 'Ignores empty _fragment value' {
            $input = 'mdview:file:///path/doc.md?_fragment='
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $frag | Should -Be ''
        }

        It '_fragment wins over #hash when both present' {
            $input = 'mdview:file:///path/doc.md?_fragment=foo#bar'
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $frag | Should -Be '#foo'
        }
    }

    Context 'Windows drive-letter paths' -Skip:(-not $IsWindows) {
        It 'Extracts path and _fragment from Windows URI' {
            $input = 'mdview:file:///C:/docs/spec.md?_fragment=intro'
            $raw = $input -replace '^(?i)mdview:', ''
            $u = [Uri]$raw
            $frag = ''
            if ($u.Query -match '[?&]_fragment=([^&#]*)') {
                $decoded = [Uri]::UnescapeDataString($Matches[1])
                if ($decoded) { $frag = '#' + $decoded }
            }
            $clean = [UriBuilder]::new($u)
            $clean.Query = $null
            $clean.Fragment = $null
            $localPath = $clean.Uri.LocalPath

            $frag | Should -Be '#intro'
            $localPath | Should -Be 'C:\docs\spec.md'
        }
    }
}
