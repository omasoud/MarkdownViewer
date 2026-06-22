# MacModule.Tests.ps1 - Pester tests for the macOS platform module

#Requires -Version 7.0

# Skip entire file outside macOS
if (-not $IsMacOS) {
    Write-Host "Skipping $(Split-Path -Leaf $PSCommandPath): macOS-only tests" -ForegroundColor Yellow
    return
}

BeforeAll {
    $ErrorActionPreference = 'Stop'

    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ModulePath = Join-Path $ScriptRoot 'src/mac/MarkdownViewer.psm1'

    Import-Module $ModulePath -Force -Global
}

AfterAll {
    Remove-Module MarkdownViewer -Force -ErrorAction SilentlyContinue
}

Describe 'Module Exports (macOS)' {

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
}

Describe 'Get-FileBaseHref (macOS)' {

    Context 'Standard macOS paths' {
        It 'Converts /Users/user/docs/file.md correctly' {
            $result = Get-FileBaseHref -FilePath '/Users/user/docs/file.md'
            $result | Should -Be 'file:///Users/user/docs/'
        }

        It 'Converts /tmp/file.md correctly' {
            $result = Get-FileBaseHref -FilePath '/tmp/file.md'
            $result | Should -Be 'file:///tmp/'
        }

        It 'Handles nested project directories' {
            $result = Get-FileBaseHref -FilePath '/Users/user/projects/repo/docs/spec.md'
            $result | Should -Be 'file:///Users/user/projects/repo/docs/'
        }
    }

    Context 'Paths with spaces' {
        It 'Preserves spaces in directory names' {
            $result = Get-FileBaseHref -FilePath '/Users/user/My Documents/file.md'
            $result | Should -Be 'file:///Users/user/My Documents/'
        }

        It 'Handles iCloud Drive style paths' {
            $result = Get-FileBaseHref -FilePath '/Users/user/Library/Mobile Documents/com~apple~CloudDocs/file.md'
            $result | Should -Be 'file:///Users/user/Library/Mobile Documents/com~apple~CloudDocs/'
        }
    }

    Context 'Root-level paths' {
        It 'Handles file directly in root' {
            $result = Get-FileBaseHref -FilePath '/file.md'
            $result | Should -Be 'file:///'
        }
    }
}

Describe 'Test-Motw and Clear-FileTrustMarker (macOS)' {

    It 'Returns $null for a non-quarantined file' {
        $tempFile = [IO.Path]::GetTempFileName()
        try {
            Test-Motw -FilePath $tempFile | Should -BeNullOrEmpty
        }
        finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Detects and clears com.apple.quarantine' {
        $tempFile = [IO.Path]::GetTempFileName()
        try {
            & /usr/bin/xattr -w com.apple.quarantine '0081;00000000;MarkViewTests;' $tempFile
            $LASTEXITCODE | Should -Be 0

            Test-Motw -FilePath $tempFile | Should -Be 3

            Clear-FileTrustMarker -FilePath $tempFile
            Test-Motw -FilePath $tempFile | Should -BeNullOrEmpty
        }
        finally {
            & /usr/bin/xattr -d com.apple.quarantine $tempFile 2>$null
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Does not throw when clearing a file without quarantine' {
        $tempFile = [IO.Path]::GetTempFileName()
        try {
            { Clear-FileTrustMarker -FilePath $tempFile } | Should -Not -Throw
        }
        finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Get-MarkViewOutputDirectory (macOS)' {

    It 'Returns ~/Library/Caches/MarkView and creates it' {
        $result = Get-MarkViewOutputDirectory
        $result | Should -Be (Join-Path $HOME 'Library/Caches/MarkView')
        $result | Should -Exist
    }
}

Describe 'Start-DefaultBrowser (macOS)' {

    It 'Uses /usr/bin/open' {
        $modulePath = (Get-Module MarkdownViewer).Path
        $moduleContent = Get-Content -LiteralPath $modulePath -Raw
        $moduleContent | Should -Match "Start-Process '/usr/bin/open'"
    }
}

Describe 'Initialize-PlatformUI (macOS)' {

    It 'Does not throw' {
        { Initialize-PlatformUI } | Should -Not -Throw
    }
}

Describe 'Shared Functions (via macOS module)' {

    Context 'Invoke-HtmlSanitization' {
        It 'Removes script tags' {
            $result = Invoke-HtmlSanitization -Html '<p>hello</p><script>alert(1)</script>'
            $result | Should -Be '<p>hello</p>'
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
}
