# Stage.Tests.ps1 - Pester tests for the MSIX staging script
# Tests directory structure, file copying, and validation logic

#Requires -Version 7.0

BeforeAll {
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $MsixDir = Join-Path $ScriptRoot 'installers\win-msix'
    $BuildDir = Join-Path $MsixDir 'build'
    $StageScript = Join-Path $BuildDir 'stage.ps1'
    $CoreDir = Join-Path $ScriptRoot 'src\core'
    $WinDir = Join-Path $ScriptRoot 'src\win'
    $HostProjectDir = Join-Path $ScriptRoot 'src\host\MarkdownViewerHost'
}

Describe 'stage.ps1 Script' {
    
    It 'Script file should exist' {
        Test-Path $StageScript | Should -BeTrue
    }
    
    It 'Should have valid PowerShell syntax' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($StageScript, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
    
    It 'Should require PowerShell 7' {
        $content = Get-Content $StageScript -Raw
        $content | Should -Match '#Requires -Version 7'
    }
}

Describe 'stage.ps1 Parameters' {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($StageScript, [ref]$null, [ref]$null)
        $paramBlock = $ast.ParamBlock
        $params = $paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }
    }
    
    It 'Should have Configuration parameter' {
        $params | Should -Contain 'Configuration'
    }
    
    It 'Should have Platform parameter' {
        $params | Should -Contain 'Platform'
    }
    
    It 'Should have HostOutputDir parameter' {
        $params | Should -Contain 'HostOutputDir'
    }
    
    It 'Should have CoreDir parameter' {
        $params | Should -Contain 'CoreDir'
    }
    
    It 'Should have StagingDir parameter' {
        $params | Should -Contain 'StagingDir'
    }
    
    It 'Should have SkipPwsh switch parameter' {
        $params | Should -Contain 'SkipPwsh'
    }
    
    It 'Should have ForceRegenAssets switch parameter' {
        $params | Should -Contain 'ForceRegenAssets'
    }
}

Describe 'stage.ps1 Required Functions' {
    BeforeAll {
        $content = Get-Content $StageScript -Raw
    }
    
    It 'Should define Get-PwshRuntime function' {
        $content | Should -Match 'function Get-PwshRuntime'
    }
    
    It 'Should define New-AssetFromIco function' {
        $content | Should -Match 'function New-AssetFromIco'
    }
}

Describe 'stage.ps1 Staging Logic' {
    BeforeAll {
        $content = Get-Content $StageScript -Raw
    }
    
    It 'Should create app\ subdirectory' {
        $content | Should -Match "Join-Path .+ 'app'"
    }
    
    It 'Should create pwsh\ subdirectory' {
        $content | Should -Match "Join-Path .+ 'pwsh'"
    }
    
    It 'Should create Assets\ subdirectory' {
        $content | Should -Match "Join-Path .+ 'Assets'"
    }
    
    It 'Should copy MarkdownViewerHost.exe' {
        $content | Should -Match 'MarkdownViewerHost\.exe'
    }
    
    It 'Should copy Open-Markdown.ps1' {
        $content | Should -Match 'Open-Markdown\.ps1'
    }
    
    It 'Should copy script.js' {
        $content | Should -Match 'script\.js'
    }
    
    It 'Should copy style.css' {
        $content | Should -Match 'style\.css'
    }
    
    It 'Should copy highlight.min.js' {
        $content | Should -Match 'highlight\.min\.js'
    }
    
    It 'Should copy highlight-theme.css' {
        $content | Should -Match 'highlight-theme\.css'
    }
}

Describe 'stage.ps1 Asset Generation' {
    BeforeAll {
        $content = Get-Content $StageScript -Raw
    }
    
    It 'Should generate StoreLogo.png (50x50)' {
        $content | Should -Match "Name = 'StoreLogo\.png'"
        $content | Should -Match 'Width = 50'
    }
    
    It 'Should generate Square44x44Logo.png' {
        $content | Should -Match "Name = 'Square44x44Logo\.png'"
    }
    
    It 'Should generate Square150x150Logo.png' {
        $content | Should -Match "Name = 'Square150x150Logo\.png'"
    }
    
    It 'Should generate Wide310x150Logo.png' {
        $content | Should -Match "Name = 'Wide310x150Logo\.png'"
    }
    
    It 'Should use ImageMagick for asset generation' {
        $content | Should -Match 'Get-Command magick'
    }
    
    It 'Should have placeholder fallback when ImageMagick unavailable' {
        $content | Should -Match 'Creating.*placeholder.*assets'
    }
}

Describe 'stage.ps1 Validation' {
    BeforeAll {
        $content = Get-Content $StageScript -Raw
    }
    
    It 'Should validate MarkdownViewerHost.exe exists' {
        $content | Should -Match "MarkdownViewerHost\.exe.*not found"
    }
    
    It 'Should validate app\Open-Markdown.ps1 exists' {
        $content | Should -Match "Open-Markdown\.ps1.*not found"
    }
    
    It 'Should validate pwsh\pwsh.exe exists (unless SkipPwsh)' {
        $content | Should -Match "pwsh\.exe.*not found"
    }
    
    It 'Should fail build if validation errors exist' {
        $content | Should -Match 'exit 1'
    }
}

Describe 'stage.ps1 PowerShell Download' {
    BeforeAll {
        $content = Get-Content $StageScript -Raw
    }
    
    It 'Should read pwsh-versions.json' {
        $content | Should -Match 'pwsh-versions\.json'
    }
    
    It 'Should verify SHA256 hash' {
        $content | Should -Match 'SHA256'
        $content | Should -Match 'Get-FileHash'
    }
    
    It 'Should use cache directory' {
        $content | Should -Match 'MarkdownViewer-BuildCache'
    }
    
    It 'Should handle download failures gracefully' {
        $content | Should -Match 'Download failed'
    }
}

Describe 'Source Files Exist' {
    # These tests verify the engine files exist that stage.ps1 will copy
    
    It 'src/core/Open-Markdown.ps1 should exist' {
        Test-Path (Join-Path $CoreDir 'Open-Markdown.ps1') | Should -BeTrue
    }
    
    It 'src/core/script.js should exist' {
        Test-Path (Join-Path $CoreDir 'script.js') | Should -BeTrue
    }
    
    It 'src/core/style.css should exist' {
        Test-Path (Join-Path $CoreDir 'style.css') | Should -BeTrue
    }
    
    It 'src/core/highlight.min.js should exist' {
        Test-Path (Join-Path $CoreDir 'highlight.min.js') | Should -BeTrue
    }
    
    It 'src/core/highlight-theme.css should exist' {
        Test-Path (Join-Path $CoreDir 'highlight-theme.css') | Should -BeTrue
    }
    
    It 'src/core/icons/markdown.ico should exist' {
        Test-Path (Join-Path $CoreDir 'icons\markdown.ico') | Should -BeTrue
    }
    
    It 'src/win/MarkdownViewer.psm1 should exist' {
        Test-Path (Join-Path $WinDir 'MarkdownViewer.psm1') | Should -BeTrue
    }
    
    It 'Host project should exist' {
        Test-Path (Join-Path $HostProjectDir 'MarkdownViewerHost.csproj') | Should -BeTrue
    }
}

Describe 'Directory.Build.targets' {
    BeforeAll {
        $targetsPath = Join-Path $BuildDir 'Directory.Build.targets'
    }
    
    It 'File should exist' {
        Test-Path $targetsPath | Should -BeTrue
    }
    
    It 'Should be valid XML' {
        { [xml](Get-Content $targetsPath -Raw) } | Should -Not -Throw
    }
    
    Context 'Target Definitions' {
        BeforeAll {
            $content = Get-Content $targetsPath -Raw
        }
        
        It 'Should define BuildHostProject target' {
            $content | Should -Match 'Name="BuildHostProject"'
        }
        
        It 'Should define StagePayload target' {
            $content | Should -Match 'Name="StagePayload"'
        }
        
        It 'Should define SignMsixPackage target' {
            $content | Should -Match 'Name="SignMsixPackage"'
        }
    }
    
    Context 'Property Definitions' {
        BeforeAll {
            $content = Get-Content $targetsPath -Raw
        }
        
        It 'Should define StagingOutputDir' {
            $content | Should -Match 'StagingOutputDir'
        }
        
        It 'Should define RepoRoot' {
            $content | Should -Match 'RepoRoot'
        }
        
        It 'Should define HostProjectDir' {
            $content | Should -Match 'HostProjectDir'
        }
        
        It 'Should define CoreDir' {
            $content | Should -Match 'CoreDir'
        }
    }
}
