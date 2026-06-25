BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $snapDir = Join-Path $repoRoot 'installers/linux-snap'
}

Describe 'Snap Package Structure' -Skip:(-not $IsLinux) {

    Describe 'Required files exist' {
        It 'snapcraft.yaml exists' {
            Join-Path $snapDir 'snap/snapcraft.yaml' | Should -Exist
        }

        It 'build.sh exists and is executable' {
            $buildSh = Join-Path $snapDir 'build.sh'
            $buildSh | Should -Exist
            # Check executable bit
            $mode = (Get-Item $buildSh).UnixMode
            $mode | Should -Match 'x'
        }

        It 'Trim-PwshBundle-Linux.ps1 exists' {
            Join-Path $snapDir 'scripts/Trim-PwshBundle-Linux.ps1' | Should -Exist
        }

        It 'Verify-MarkViewPwsh-Linux.ps1 exists' {
            Join-Path $snapDir 'scripts/Verify-MarkViewPwsh-Linux.ps1' | Should -Exist
        }

        It 'pwsh-versions.json exists' {
            Join-Path $snapDir 'build/pwsh-versions.json' | Should -Exist
        }
    }

    Describe 'snapcraft.yaml content' {
        BeforeAll {
            $yamlPath = Join-Path $snapDir 'snap/snapcraft.yaml'
            $yamlContent = Get-Content $yamlPath -Raw
        }

        It 'has correct snap name' {
            $yamlContent | Should -Match 'name:\s+markdownviewer'
        }

        It 'uses core24 base' {
            $yamlContent | Should -Match 'base:\s+core24'
        }

        It 'uses strict confinement' {
            $yamlContent | Should -Match 'confinement:\s+strict'
        }

        It 'defines markdownviewer app' {
            $yamlContent | Should -Match 'apps:\s*\n\s+markdownviewer:'
        }

        It 'has home plug for file access' {
            $yamlContent | Should -Match 'home'
        }

        It 'has desktop plug' {
            $yamlContent | Should -Match 'desktop'
        }

        It 'has browser-support plug' {
            $yamlContent | Should -Match 'browser-support'
        }

        It 'includes zenity as stage package' {
            $yamlContent | Should -Match 'zenity'
        }

        It 'does not include xdg-utils (uses snapctl user-open instead)' {
            $yamlContent | Should -Not -Match 'xdg-utils'
        }
    }

    Describe 'pwsh-versions.json content' {
        BeforeAll {
            $configPath = Join-Path $snapDir 'build/pwsh-versions.json'
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
        }

        It 'has a version specified' {
            $config.version | Should -Not -BeNullOrEmpty
        }

        It 'has amd64 archive URL' {
            $config.archives.amd64.url | Should -Match 'linux-x64\.tar\.gz$'
        }

        It 'has arm64 archive URL' {
            $config.archives.arm64.url | Should -Match 'linux-arm64\.tar\.gz$'
        }
    }

    Describe 'Desktop entry' {
        BeforeAll {
            $desktopPath = Join-Path $repoRoot 'src/linux/markview.desktop'
            $desktopContent = Get-Content $desktopPath -Raw
        }

        It 'has Desktop Entry header' {
            $desktopContent | Should -Match '\[Desktop Entry\]'
        }

        It 'has correct name' {
            $desktopContent | Should -Match 'Name=MarkView'
        }

        It 'has markdown MIME types' {
            $desktopContent | Should -Match 'text/markdown'
            $desktopContent | Should -Match 'text/x-markdown'
        }

        It 'has mdview protocol handler' {
            $desktopContent | Should -Match 'x-scheme-handler/mdview'
        }

        It 'has Terminal=false' {
            $desktopContent | Should -Match 'Terminal=false'
        }

        It 'uses the snap command name' {
            $desktopContent | Should -Match 'Exec=markdownviewer %u'
        }
    }

    Describe 'Launcher script' {
        BeforeAll {
            $launcherPath = Join-Path $repoRoot 'src/linux/markview'
            $launcherContent = Get-Content $launcherPath -Raw
        }

        It 'launcher exists and is executable' {
            $launcherPath | Should -Exist
            $mode = (Get-Item $launcherPath).UnixMode
            $mode | Should -Match 'x'
        }

        It 'starts with bash shebang' {
            $launcherContent | Should -Match '^#!/bin/bash'
        }

        It 'handles snap layout' {
            $launcherContent | Should -Match '\$SNAP'
        }

        It 'falls back to system pwsh' {
            $launcherContent | Should -Match 'PWSH="pwsh"'
        }

        It 'calls Open-Markdown.ps1' {
            $launcherContent | Should -Match 'Open-Markdown\.ps1'
        }

        It 'prints friendly usage when no markdown file is supplied' {
            $result = & bash $launcherPath 2>&1
            $LASTEXITCODE | Should -Be 2

            $output = $result -join "`n"
            $output | Should -Match 'MarkView\s+\d+\.\d+\.\d+'
            $output | Should -Match 'View Markdown files rendered in your browser\.'
            $output | Should -Match 'Usage:'
            $output | Should -Match 'markview <markdown-file>'
        }

        It 'prints snap command usage in snap layout' {
            $env:SNAP = '/snap/markdownviewer/current'
            $env:SNAP_NAME = 'markdownviewer'
            $env:SNAP_VERSION = '1.3.0'
            try {
                $result = & bash $launcherPath --help 2>&1
                $LASTEXITCODE | Should -Be 0
            }
            finally {
                Remove-Item Env:\SNAP -ErrorAction SilentlyContinue
                Remove-Item Env:\SNAP_NAME -ErrorAction SilentlyContinue
                Remove-Item Env:\SNAP_VERSION -ErrorAction SilentlyContinue
            }

            $output = $result -join "`n"
            $output | Should -Match 'MarkView 1\.3\.0'
            $output | Should -Match 'markdownviewer <markdown-file>'
        }
    }

    Describe 'App icon' {
        It 'markview.png exists' {
            Join-Path $repoRoot 'src/linux/markview.png' | Should -Exist
        }

        It 'markview.png is a valid PNG' {
            $pngPath = Join-Path $repoRoot 'src/linux/markview.png'
            $header = [byte[]](Get-Content $pngPath -AsByteStream -ReadCount 4 -TotalCount 4)
            # PNG magic bytes: 137 80 78 71
            $header[0] | Should -Be 137
            $header[1] | Should -Be 80
            $header[2] | Should -Be 78
            $header[3] | Should -Be 71
        }
    }

    Describe 'Build script staging' {
        BeforeAll {
            # Run build.sh --stage-only and check results
            $stageDir = Join-Path $snapDir 'staged'
            $pwshDir = Join-Path $snapDir 'pwsh'

            # Only run staging if not already staged (clean run)
            if (-not (Test-Path $stageDir)) {
                $buildResult = & bash (Join-Path $snapDir 'build.sh') --stage-only 2>&1
                $script:buildExitCode = $LASTEXITCODE
            } else {
                $script:buildExitCode = 0
            }
        }

        It 'build.sh --stage-only succeeds' {
            $script:buildExitCode | Should -Be 0
        }

        It 'staged app directory exists' {
            Join-Path $snapDir 'staged/app' | Should -Exist
        }

        It 'staged Open-Markdown.ps1 exists' {
            Join-Path $snapDir 'staged/app/Open-Markdown.ps1' | Should -Exist
        }

        It 'staged MarkdownViewer.psm1 exists' {
            Join-Path $snapDir 'staged/app/MarkdownViewer.psm1' | Should -Exist
        }

        It 'staged MarkdownViewer.Shared.psm1 exists' {
            Join-Path $snapDir 'staged/app/MarkdownViewer.Shared.psm1' | Should -Exist
        }

        It 'staged launcher exists and is executable' {
            $launcher = Join-Path $snapDir 'staged/bin/markview'
            $launcher | Should -Exist
            $mode = (Get-Item $launcher).UnixMode
            $mode | Should -Match 'x'
        }

        It 'staged desktop file exists' {
            Join-Path $snapDir 'staged/meta/gui/markview.desktop' | Should -Exist
        }

        It 'staged icon exists' {
            Join-Path $snapDir 'staged/meta/gui/markview.png' | Should -Exist
        }

        It 'staged core assets exist' {
            Join-Path $snapDir 'staged/app/script.js' | Should -Exist
            Join-Path $snapDir 'staged/app/style.css' | Should -Exist
            Join-Path $snapDir 'staged/app/highlight.min.js' | Should -Exist
            Join-Path $snapDir 'staged/app/highlight-theme.css' | Should -Exist
            Join-Path $snapDir 'staged/app/markdown.ico' | Should -Exist
        }

        It 'staged snap payload has packable permissions' {
            $directories = @(
                'staged',
                'staged/app',
                'staged/bin',
                'staged/meta',
                'staged/meta/gui',
                'staged/pwsh'
            )
            foreach ($relativePath in $directories) {
                $path = Join-Path $snapDir $relativePath
                (Get-Item $path).UnixMode | Should -Match '^d......r.x$' -Because "$relativePath must be world-readable and searchable for snap pack"
            }

            $readableFiles = @(
                'staged/app/Open-Markdown.ps1',
                'staged/meta/gui/markview.desktop',
                'staged/meta/gui/markview.png'
            )
            foreach ($relativePath in $readableFiles) {
                $path = Join-Path $snapDir $relativePath
                (Get-Item $path).UnixMode | Should -Match '^-......r..$' -Because "$relativePath must be world-readable for snap pack"
            }

            $executableFiles = @(
                'staged/bin/markview',
                'staged/pwsh/pwsh'
            )
            foreach ($relativePath in $executableFiles) {
                $path = Join-Path $snapDir $relativePath
                (Get-Item $path).UnixMode | Should -Match '^-......r.x$' -Because "$relativePath must be world-readable and executable for snap pack"
            }
        }

        It 'trimmed pwsh directory exists in staged' {
            Join-Path $snapDir 'staged/pwsh' | Should -Exist
        }

        It 'trimmed pwsh binary exists and is executable' {
            $pwshBin = Join-Path $snapDir 'staged/pwsh/pwsh'
            $pwshBin | Should -Exist
            $mode = (Get-Item $pwshBin).UnixMode
            $mode | Should -Match 'x'
        }

        It 'verification passes on staged payload' {
            $result = & pwsh -NoProfile -File (Join-Path $snapDir 'scripts/Verify-MarkViewPwsh-Linux.ps1') `
                -ScriptPath (Join-Path $snapDir 'staged/app/Open-Markdown.ps1') `
                -ModulePath (Join-Path $snapDir 'staged/app/MarkdownViewer.psm1') `
                -SharedModulePath (Join-Path $snapDir 'staged/app/MarkdownViewer.Shared.psm1') `
                -PwshDir (Join-Path $snapDir 'staged/pwsh') 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        AfterAll {
            # Clean up staging artifacts
            $stageDir = Join-Path $snapDir 'staged'
            $cacheDir = Join-Path $snapDir '.cache'
            if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
            # Keep .cache to avoid re-downloading
        }
    }
}
