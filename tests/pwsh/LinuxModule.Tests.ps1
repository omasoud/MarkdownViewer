# LinuxModule.Tests.ps1 - Pester tests for the Linux platform module
# Tests Get-FileBaseHref (Linux paths), Test-Motw (no-op), and module exports

#Requires -Version 7.0

# Skip entire file outside Linux
if (-not $IsLinux) {
    Write-Host "Skipping $(Split-Path -Leaf $PSCommandPath): Linux-only tests" -ForegroundColor Yellow
    return
}

BeforeAll {
    $ErrorActionPreference = 'Stop'
    
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src/linux/MarkdownViewer.psm1'
    
    Import-Module $ModulePath -Force -Global
}

AfterAll {
    Remove-Module MarkdownViewer -Force -ErrorAction SilentlyContinue
}

Describe 'Module Exports (Linux)' {
    
    It 'Exports all required shared functions' {
        $exported = (Get-Module MarkdownViewer).ExportedFunctions.Keys
        $exported | Should -Contain 'Invoke-HtmlSanitization'
        $exported | Should -Contain 'Test-RemoteImages'
        $exported | Should -Contain 'Repair-MarkdownLinks'
        $exported | Should -Contain 'Repair-HtmlLinks'
    }
    
    It 'Exports all required platform functions' {
        $exported = (Get-Module MarkdownViewer).ExportedFunctions.Keys
        $exported | Should -Contain 'Get-FileBaseHref'
        $exported | Should -Contain 'Test-Motw'
        $exported | Should -Contain 'Clear-FileTrustMarker'
        $exported | Should -Contain 'Get-MarkViewOutputDirectory'
        $exported | Should -Contain 'Start-DefaultBrowser'
        $exported | Should -Contain 'Initialize-PlatformUI'
        $exported | Should -Contain 'Show-MotwWarning'
        $exported | Should -Contain 'Show-FileNotFound'
        $exported | Should -Contain 'Show-ErrorDialog'
    }
    
    It 'Has the same shared function set as the Windows module' {
        # Load the Windows module exports list to compare shared functions
        $winModulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src/win/MarkdownViewer.psm1'
        $winContent = Get-Content $winModulePath -Raw
        
        $sharedFunctions = @(
            'Invoke-HtmlSanitization'
            'Test-RemoteImages'
            'Repair-MarkdownLinks'
            'Repair-HtmlLinks'
        )
        
        $exported = (Get-Module MarkdownViewer).ExportedFunctions.Keys
        foreach ($fn in $sharedFunctions) {
            $exported | Should -Contain $fn
            # Also verify the Windows module exports it
            $winContent | Should -Match $fn
        }
    }
}

Describe 'Get-FileBaseHref (Linux)' {
    
    Context 'Standard Linux paths' {
        It 'Converts /home/user/docs/file.md correctly' {
            $result = Get-FileBaseHref -FilePath '/home/user/docs/file.md'
            $result | Should -Be 'file:///home/user/docs/'
        }
        
        It 'Converts /tmp/file.md correctly' {
            $result = Get-FileBaseHref -FilePath '/tmp/file.md'
            $result | Should -Be 'file:///tmp/'
        }
        
        It 'Handles nested directories' {
            $result = Get-FileBaseHref -FilePath '/home/user/projects/repo/docs/spec.md'
            $result | Should -Be 'file:///home/user/projects/repo/docs/'
        }
    }
    
    Context 'Paths with spaces' {
        It 'Preserves spaces in directory names' {
            $result = Get-FileBaseHref -FilePath '/home/user/My Documents/file.md'
            $result | Should -Be 'file:///home/user/My Documents/'
        }
        
        It 'Handles multiple spaces in path' {
            $result = Get-FileBaseHref -FilePath '/home/user/My Files/Sub Dir/file.md'
            $result | Should -Be 'file:///home/user/My Files/Sub Dir/'
        }
    }
    
    Context 'Root-level paths' {
        It 'Handles file directly in root' {
            $result = Get-FileBaseHref -FilePath '/file.md'
            $result | Should -Be 'file:///'
        }
    }
}

Describe 'Test-Motw (Linux)' {
    
    It 'Returns $null for any file' {
        Test-Motw -FilePath '/tmp/any-file.md' | Should -BeNullOrEmpty
    }
    
    It 'Returns $null for non-existent file' {
        Test-Motw -FilePath '/tmp/nonexistent-file-12345.md' | Should -BeNullOrEmpty
    }
    
    It 'Returns $null for existing file' {
        $tempFile = [IO.Path]::GetTempFileName()
        try {
            Test-Motw -FilePath $tempFile | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Initialize-PlatformUI (Linux)' {
    
    It 'Does not throw' {
        { Initialize-PlatformUI } | Should -Not -Throw
    }
}

Describe 'Platform Contract (Linux)' {

    It 'Clear-FileTrustMarker does not throw' {
        { Clear-FileTrustMarker -FilePath '/tmp/any-file.md' } | Should -Not -Throw
    }

    It 'Get-MarkViewOutputDirectory returns ~/MarkView and creates it' {
        $result = Get-MarkViewOutputDirectory
        $result | Should -Be (Join-Path $HOME 'MarkView')
        $result | Should -Exist
    }
}

Describe 'Shared Functions (via Linux module)' {
    
    Context 'Invoke-HtmlSanitization' {
        It 'Removes script tags' {
            $result = Invoke-HtmlSanitization -Html '<p>hello</p><script>alert(1)</script>'
            $result | Should -Be '<p>hello</p>'
        }
        
        It 'Handles empty string' {
            $result = Invoke-HtmlSanitization -Html ''
            $result | Should -Be ''
        }
    }
    
    Context 'Test-RemoteImages' {
        It 'Detects remote src' {
            $result = Test-RemoteImages -Html '<img src="https://example.com/img.png">'
            $result | Should -BeTrue
        }
        
        It 'Returns false for local images' {
            $result = Test-RemoteImages -Html '<img src="file:///tmp/img.png">'
            $result | Should -BeFalse
        }
    }
    
    Context 'Repair-MarkdownLinks' {
        It 'Passes through clean markdown' {
            $md = '[link](https://example.com)'
            $result = Repair-MarkdownLinks -Markdown $md
            $result | Should -Be $md
        }
        
        It 'Handles empty string' {
            $result = Repair-MarkdownLinks -Markdown ''
            $result | Should -Be ''
        }
    }
    
    Context 'Repair-HtmlLinks' {
        It 'Passes through clean HTML' {
            $html = '<a href="https://example.com">link</a>'
            $result = Repair-HtmlLinks -Html $html
            $result | Should -Be $html
        }
        
        It 'Handles empty string' {
            $result = Repair-HtmlLinks -Html ''
            $result | Should -Be ''
        }
    }
}
