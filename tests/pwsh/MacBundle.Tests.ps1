# MacBundle.Tests.ps1 - Pester tests for the macOS app bundle packaging path

#Requires -Version 7.0

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $macDir = Join-Path $repoRoot 'installers/macos-dmg'
    $appPath = Join-Path $macDir 'staged/MarkView.app'
    $resourcesPath = Join-Path $appPath 'Contents/Resources'
}

Describe 'macOS App Bundle Structure' -Skip:(-not $IsMacOS) {

    Describe 'Required packaging files exist' {
        It 'build.sh exists and is executable' {
            $buildSh = Join-Path $macDir 'build.sh'
            $buildSh | Should -Exist
            (Get-Item $buildSh).UnixMode | Should -Match 'x'
        }

        It 'pwsh-versions.json exists' {
            Join-Path $macDir 'build/pwsh-versions.json' | Should -Exist
        }

        It 'Trim-PwshBundle-macOS.ps1 exists' {
            Join-Path $macDir 'scripts/Trim-PwshBundle-macOS.ps1' | Should -Exist
        }

        It 'Verify-MarkViewPwsh-macOS.ps1 exists' {
            Join-Path $macDir 'scripts/Verify-MarkViewPwsh-macOS.ps1' | Should -Exist
        }

        It 'Sign-MarkViewApp.sh exists and is executable' {
            $signScript = Join-Path $macDir 'scripts/Sign-MarkViewApp.sh'
            $signScript | Should -Exist
            (Get-Item $signScript).UnixMode | Should -Match 'x'
        }
    }

    Describe 'pwsh-versions.json content' {
        BeforeAll {
            $configPath = Join-Path $macDir 'build/pwsh-versions.json'
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
        }

        It 'has a version specified' {
            $config.version | Should -Not -BeNullOrEmpty
        }

        It 'has arm64 archive URL' {
            $config.archives.arm64.url | Should -Match 'osx-arm64\.tar\.gz$'
        }

        It 'does not define an x64 archive for the first release' {
            $config.archives.PSObject.Properties.Name | Should -Not -Contain 'x64'
        }
    }

    Describe 'Build script staging' {
        BeforeAll {
            $result = & bash (Join-Path $macDir 'build.sh') --stage-only 2>&1
            $script:buildOutput = $result -join "`n"
            $script:buildExitCode = $LASTEXITCODE
        }

        It 'build.sh --stage-only succeeds' {
            if ($script:buildExitCode -ne 0) {
                Write-Host $script:buildOutput
            }
            $script:buildExitCode | Should -Be 0
        }

        It 'creates MarkView.app' {
            $appPath | Should -Exist
        }

        It 'creates a valid Info.plist' {
            $plist = Join-Path $appPath 'Contents/Info.plist'
            $plist | Should -Exist
            & plutil -lint $plist
            $LASTEXITCODE | Should -Be 0
        }

        It 'sets the expected bundle identifier and display name' {
            $plistContent = Get-Content (Join-Path $appPath 'Contents/Info.plist') -Raw
            $plistContent | Should -Match '<string>com\.omasoud\.MarkView</string>'
            $plistContent | Should -Match '<string>MarkView</string>'
        }

        It 'declares Markdown document extensions' {
            $plistContent = Get-Content (Join-Path $appPath 'Contents/Info.plist') -Raw
            $plistContent | Should -Match '<string>md</string>'
            $plistContent | Should -Match '<string>markdown</string>'
        }

        It 'declares mdview URL scheme' {
            $plistContent = Get-Content (Join-Path $appPath 'Contents/Info.plist') -Raw
            $plistContent | Should -Match '<string>mdview</string>'
        }

        It 'creates host executable' {
            $hostExe = Join-Path $appPath 'Contents/MacOS/MarkViewHost'
            $hostExe | Should -Exist
            (Get-Item $hostExe).UnixMode | Should -Match 'x'
        }

        It 'stages core app files' {
            Join-Path $resourcesPath 'app/Open-Markdown.ps1' | Should -Exist
            Join-Path $resourcesPath 'app/MarkdownViewer.psm1' | Should -Exist
            Join-Path $resourcesPath 'app/MarkdownViewer.Shared.psm1' | Should -Exist
            Join-Path $resourcesPath 'app/script.js' | Should -Exist
            Join-Path $resourcesPath 'app/style.css' | Should -Exist
            Join-Path $resourcesPath 'app/highlight.min.js' | Should -Exist
            Join-Path $resourcesPath 'app/highlight-theme.css' | Should -Exist
            Join-Path $resourcesPath 'app/markdown.ico' | Should -Exist
        }

        It 'creates app icon' {
            Join-Path $resourcesPath 'markview.icns' | Should -Exist
        }

        It 'bundles executable PowerShell' {
            $pwsh = Join-Path $resourcesPath 'pwsh/pwsh'
            $pwsh | Should -Exist
            (Get-Item $pwsh).UnixMode | Should -Match 'x'
        }

        It 'verification passes on staged payload' {
            $verifyResult = & pwsh -NoProfile -File (Join-Path $macDir 'scripts/Verify-MarkViewPwsh-macOS.ps1') `
                -ScriptPath (Join-Path $resourcesPath 'app/Open-Markdown.ps1') `
                -ModulePath (Join-Path $resourcesPath 'app/MarkdownViewer.psm1') `
                -SharedModulePath (Join-Path $resourcesPath 'app/MarkdownViewer.Shared.psm1') `
                -PwshDir (Join-Path $resourcesPath 'pwsh') 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host ($verifyResult -join "`n")
            }
            $LASTEXITCODE | Should -Be 0
        }

        It 'ad-hoc signature verifies' {
            & codesign --verify --deep --strict --verbose=2 $appPath
            $LASTEXITCODE | Should -Be 0
        }
    }
}
