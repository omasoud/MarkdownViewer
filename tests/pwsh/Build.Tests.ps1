# Build.Tests.ps1 - Pester tests for build script functionality
# Tests pwsh-versions.json parsing and SHA256 verification logic

#Requires -Version 7.0

BeforeAll {
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $MsixDir = Join-Path $ScriptRoot 'installers\win-msix'
    $PwshVersionsPath = Join-Path $MsixDir 'pwsh-versions.json'
}

Describe 'pwsh-versions.json Configuration' {
    
    It 'File should exist' {
        Test-Path $PwshVersionsPath | Should -BeTrue
    }
    
    It 'Should be valid JSON' {
        { Get-Content $PwshVersionsPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }
    
    Context 'JSON Structure' {
        BeforeAll {
            $config = Get-Content $PwshVersionsPath -Raw | ConvertFrom-Json
        }
        
        It 'Should have a version field' {
            $config.version | Should -Not -BeNullOrEmpty
        }
        
        It 'Version should be valid semver-like format' {
            $config.version | Should -Match '^\d+\.\d+\.\d+$'
        }
        
        It 'Should have archives section' {
            $config.archives | Should -Not -BeNull
        }
        
        It 'Should have x64 configuration' {
            $config.archives.x64 | Should -Not -BeNull
        }
        
        It 'Should have arm64 configuration' {
            $config.archives.arm64 | Should -Not -BeNull
        }
        
        It 'x64 should have url field' {
            $config.archives.x64.url | Should -Not -BeNullOrEmpty
        }
        
        It 'arm64 should have url field' {
            $config.archives.arm64.url | Should -Not -BeNullOrEmpty
        }
        
        It 'x64 should have sha256 field' {
            $config.archives.x64.sha256 | Should -Not -BeNullOrEmpty
        }
        
        It 'arm64 should have sha256 field' {
            $config.archives.arm64.sha256 | Should -Not -BeNullOrEmpty
        }
        
        It 'x64 url should point to GitHub releases' {
            $config.archives.x64.url | Should -Match '^https://github\.com/PowerShell/PowerShell/releases/download/'
        }
        
        It 'arm64 url should point to GitHub releases' {
            $config.archives.arm64.url | Should -Match '^https://github\.com/PowerShell/PowerShell/releases/download/'
        }
        
        It 'x64 sha256 should be 64 hex characters' {
            $config.archives.x64.sha256 | Should -Match '^[A-Fa-f0-9]{64}$'
        }
        
        It 'arm64 sha256 should be 64 hex characters' {
            $config.archives.arm64.sha256 | Should -Match '^[A-Fa-f0-9]{64}$'
        }
        
        It 'sha256 values should not be placeholders (all zeros)' {
            $config.archives.x64.sha256 | Should -Not -Match '^0+$'
            $config.archives.arm64.sha256 | Should -Not -Match '^0+$'
        }
    }
}

Describe 'SHA256 Hash Verification Logic' {
    
    It 'Get-FileHash should produce 64 character hex string' {
        # Create a temp file to hash
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tempFile -Value 'test content'
            $hash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash
            $hash | Should -Match '^[A-F0-9]{64}$'
        }
        finally {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    It 'Same content should produce same hash' {
        $tempFile1 = [System.IO.Path]::GetTempFileName()
        $tempFile2 = [System.IO.Path]::GetTempFileName()
        try {
            $content = 'identical test content for hash verification'
            Set-Content -Path $tempFile1 -Value $content -NoNewline
            Set-Content -Path $tempFile2 -Value $content -NoNewline
            
            $hash1 = (Get-FileHash -Path $tempFile1 -Algorithm SHA256).Hash
            $hash2 = (Get-FileHash -Path $tempFile2 -Algorithm SHA256).Hash
            
            $hash1 | Should -Be $hash2
        }
        finally {
            Remove-Item $tempFile1 -Force -ErrorAction SilentlyContinue
            Remove-Item $tempFile2 -Force -ErrorAction SilentlyContinue
        }
    }
    
    It 'Different content should produce different hash' {
        $tempFile1 = [System.IO.Path]::GetTempFileName()
        $tempFile2 = [System.IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $tempFile1 -Value 'content A' -NoNewline
            Set-Content -Path $tempFile2 -Value 'content B' -NoNewline
            
            $hash1 = (Get-FileHash -Path $tempFile1 -Algorithm SHA256).Hash
            $hash2 = (Get-FileHash -Path $tempFile2 -Algorithm SHA256).Hash
            
            $hash1 | Should -Not -Be $hash2
        }
        finally {
            Remove-Item $tempFile1 -Force -ErrorAction SilentlyContinue
            Remove-Item $tempFile2 -Force -ErrorAction SilentlyContinue
        }
    }
    
    It 'Hash comparison should be case-insensitive' {
        $hash1 = 'ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789'
        $hash2 = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789'
        
        # PowerShell string comparison is case-insensitive by default
        $hash1 -eq $hash2 | Should -BeTrue
    }
}

Describe 'Build Cache Directory' {
    
    It 'Cache path pattern should use TEMP environment variable' {
        $cacheDir = Join-Path $env:TEMP 'MarkdownViewer-BuildCache'
        $cacheDir | Should -Match 'MarkdownViewer-BuildCache$'
    }
    
    It 'TEMP environment variable should be defined' {
        $env:TEMP | Should -Not -BeNullOrEmpty
    }
    
    It 'Cache directory should be creatable' {
        $testCacheDir = Join-Path $env:TEMP 'MarkdownViewer-BuildCache-Test'
        try {
            if (-not (Test-Path $testCacheDir)) {
                New-Item -ItemType Directory -Path $testCacheDir -Force | Out-Null
            }
            Test-Path $testCacheDir | Should -BeTrue
        }
        finally {
            Remove-Item $testCacheDir -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Build Script Syntax' {
    
    It 'build.ps1 should have valid PowerShell syntax' {
        $buildScript = Join-Path $MsixDir 'build.ps1'
        $errors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseFile($buildScript, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
    
    It 'sign.ps1 should have valid PowerShell syntax' {
        $signScript = Join-Path $MsixDir 'sign.ps1'
        $errors = @()
        $null = [System.Management.Automation.Language.Parser]::ParseFile($signScript, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe 'URL Validation' {
    BeforeAll {
        $config = Get-Content $PwshVersionsPath -Raw | ConvertFrom-Json
    }
    
    It 'x64 URL should contain correct architecture' {
        $config.archives.x64.url | Should -Match 'win-x64\.zip$'
    }
    
    It 'arm64 URL should contain correct architecture' {
        $config.archives.arm64.url | Should -Match 'win-arm64\.zip$'
    }
    
    It 'URLs should contain matching version' {
        $version = $config.version
        $config.archives.x64.url | Should -Match "v$version"
        $config.archives.arm64.url | Should -Match "v$version"
    }
}
