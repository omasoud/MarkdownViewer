# MacBundle.Tests.ps1 - Pester tests for the macOS app bundle packaging path

#Requires -Version 7.0

BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $macDir = Join-Path $repoRoot 'installers/macos-dmg'
    $appPath = Join-Path $macDir 'staged/MarkView.app'
    $resourcesPath = Join-Path $appPath 'Contents/Resources'
    $hostSourcePath = Join-Path $repoRoot 'src/host/MarkdownViewerMacHost/MarkViewHost.swift'
    $hostProjectPath = Join-Path $repoRoot 'src/host/MarkdownViewerHost/MarkdownViewerHost.csproj'
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

        It 'Release-MarkViewDmg.sh exists and is executable' {
            $releaseScript = Join-Path $macDir 'scripts/Release-MarkViewDmg.sh'
            $releaseScript | Should -Exist
            (Get-Item $releaseScript).UnixMode | Should -Match 'x'
        }
    }

    Describe 'Release signing and notarization scripts' {
        BeforeAll {
            $buildScript = Join-Path $macDir 'build.sh'
            $buildSource = Get-Content -LiteralPath $buildScript -Raw
            $releaseScript = Join-Path $macDir 'scripts/Release-MarkViewDmg.sh'
            $releaseSource = Get-Content -LiteralPath $releaseScript -Raw
        }

        It 'release script has valid bash syntax' {
            & bash -n $releaseScript
            $LASTEXITCODE | Should -Be 0
        }

        It 'release script requires a Developer ID identity for builds' {
            $releaseSource | Should -Match 'Developer ID signing identity is required'
            $releaseSource | Should -Match 'MARKVIEW_CODESIGN_IDENTITY'
        }

        It 'release script submits, staples, and validates notarized DMGs' {
            $releaseSource | Should -Match 'xcrun notarytool submit'
            $releaseSource | Should -Match '--keychain-profile'
            $releaseSource | Should -Match 'xcrun stapler staple'
            $releaseSource | Should -Match 'xcrun stapler validate'
            $releaseSource | Should -Match 'spctl --assess --type open'
        }

        It 'build script timestamps Developer ID DMG signatures' {
            $buildSource | Should -Match 'codesign --force --timestamp --sign "\$MARKVIEW_CODESIGN_IDENTITY" "\$DMG_PATH"'
        }
    }

    Describe 'Swift host protocol activation lifecycle' {
        BeforeAll {
            $hostSource = Get-Content -LiteralPath $hostSourcePath -Raw
        }

        It 'registers mdview Apple Event handling before applicationDidFinishLaunching' {
            $willIndex = $hostSource.IndexOf('func applicationWillFinishLaunching')
            $didIndex = $hostSource.IndexOf('func applicationDidFinishLaunching')
            $handlerIndex = $hostSource.IndexOf('setEventHandler')

            $willIndex | Should -BeGreaterOrEqual 0
            $didIndex | Should -BeGreaterThan $willIndex
            $handlerIndex | Should -BeGreaterThan $willIndex
            $handlerIndex | Should -BeLessThan $didIndex
        }

        It 'handles kAEGetURL events for mdview links' {
            $hostSource | Should -Match 'kInternetEventClass'
            $hostSource | Should -Match 'kAEGetURL'
            $hostSource | Should -Match 'handleGetURLEvent'
        }

        It 'shows the bundle version when launched without a file' {
            $hostSource | Should -Match 'CFBundleDisplayName'
            $hostSource | Should -Match 'CFBundleShortVersionString'
            $hostSource | Should -Match 'appTitle'
        }

        It 'offers a Project Page button that opens the GitHub project' {
            $hostSource | Should -Match 'Project Page'
            $hostSource | Should -Match 'https://github\.com/omasoud/MarkdownViewer'
            $hostSource | Should -Match 'alertSecondButtonReturn'
            $hostSource | Should -Match 'NSWorkspace\.shared\.open'
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

        It 'sets the bundle version from the canonical app version' {
            $plistContent = Get-Content (Join-Path $appPath 'Contents/Info.plist') -Raw
            $canonicalVersion = ([xml](Get-Content -Raw -LiteralPath $hostProjectPath)).Project.PropertyGroup.Version

            $plistContent | Should -Match '<key>CFBundleShortVersionString</key>'
            $plistContent | Should -Match "<string>$([regex]::Escape($canonicalVersion))</string>"
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
            Join-Path $resourcesPath 'app/vendor/katex/katex.min.js' | Should -Exist
            Join-Path $resourcesPath 'app/vendor/katex/katex.min.css' | Should -Exist
            Join-Path $resourcesPath 'app/vendor/katex/fonts/KaTeX_Main-Regular.woff2' | Should -Exist
            Join-Path $resourcesPath 'app/vendor/katex/README.md' | Should -Exist
            Join-Path $resourcesPath 'app/vendor/katex/LICENSE' | Should -Exist
            Join-Path $resourcesPath 'app/THIRD-PARTY-LICENSES.md' | Should -Exist
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
