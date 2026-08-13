# MathSupport.Tests.ps1 - Offline KaTeX math support contracts

#Requires -Version 7.0

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $SharedModulePath = Join-Path $RepoRoot 'src/core/MarkdownViewer.Shared.psm1'
    Import-Module $SharedModulePath -Force -Global
}

AfterAll {
    Remove-Module MarkdownViewer.Shared -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-Markdown math contract' {
    It 'emits an inline math span with Markdig delimiters' {
        $html = (ConvertFrom-Markdown -InputObject 'Before $x^2$ after').Html

        $html | Should -Match '<span class="math">\\\(x\^2\\\)</span>'
    }

    It 'emits a display math div with Markdig delimiters' {
        $markdown = "Before`n`n`$`$`nx^2`n`$`$`n`nAfter"
        $html = (ConvertFrom-Markdown -InputObject $markdown).Html

        $html | Should -Match '(?s)<div class="math">\s*\\\[\s*x\^2\s*\\\]</div>'
    }

    It 'survives the existing HTML sanitization stage' {
        $markdown = "Inline `$x^2`$.`n`n`$`$`ny = mx + b`n`$`$"
        $html = (ConvertFrom-Markdown -InputObject $markdown).Html

        $sanitized = Invoke-HtmlSanitization -Html $html

        $sanitized | Should -Match '<span class="math">\\\(x\^2\\\)</span>'
        $sanitized | Should -Match '(?s)<div class="math">\s*\\\[\s*y = mx \+ b\s*\\\]</div>'
    }

    It 'does not weaken sanitization for Markdown-authored application tags' {
        $html = '<script src="evil.js"></script><link rel="stylesheet" href="evil.css"><style>.math{display:none}</style><span class="math">\(x\)</span>'

        $sanitized = Invoke-HtmlSanitization -Html $html

        $sanitized | Should -Not -Match '<(?:script|link|style)\b'
        $sanitized | Should -Match '<span class="math">\\\(x\\\)</span>'
    }
}

Describe 'Test-MarkViewMathHtml' {
    It 'detects converter inline math output' {
        Test-MarkViewMathHtml -Html '<p><span class="math">\(x\)</span></p>' | Should -BeTrue
    }

    It 'detects converter display math output with another class' {
        Test-MarkViewMathHtml -Html '<div class="rendered math pending">\[x\]</div>' | Should -BeTrue
    }

    It 'does not treat ordinary text or code as math' {
        Test-MarkViewMathHtml -Html '<pre><code>$x$</code></pre><p class="mathematics">text</p>' | Should -BeFalse
    }

    It 'does not accept the math class on unrelated elements' {
        Test-MarkViewMathHtml -Html '<code class="math">$x$</code>' | Should -BeFalse
    }

    It 'returns false for empty HTML' {
        Test-MarkViewMathHtml -Html '' | Should -BeFalse
    }
}

Describe 'Copy-MarkViewOutputAssetBundle' {
    BeforeEach {
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $source = Join-Path $caseRoot 'source-katex'
        $output = Join-Path $caseRoot 'output'
        $fonts = Join-Path $source 'fonts'
        New-Item -ItemType Directory -Path $fonts, $output -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $source 'katex.min.js'), 'window.katex = {};')
        [IO.File]::WriteAllText((Join-Path $source 'katex.min.css'), '@font-face{src:url(fonts/KaTeX_Main.woff2)}')
        [IO.File]::WriteAllBytes((Join-Path $fonts 'KaTeX_Main.woff2'), [byte[]](1, 2, 3, 4))
    }

    It 'copies a complete nested bundle into a content-addressed directory' {
        $result = Copy-MarkViewOutputAssetBundle `
            -SourcePath $source `
            -OutputDirectory $output `
            -BundleName 'katex' `
            -RequiredFiles @('katex.min.js', 'katex.min.css', 'fonts/KaTeX_Main.woff2')

        Split-Path -Leaf $result | Should -Match '^katex\.[0-9a-f]{12}$'
        Join-Path $result 'katex.min.js' | Should -Exist
        Join-Path $result 'katex.min.css' | Should -Exist
        Join-Path $result 'fonts/KaTeX_Main.woff2' | Should -Exist
    }

    It 'reuses the immutable directory for identical content' {
        $first = Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')

        $second = Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')

        $second | Should -Be $first
        @(Get-ChildItem -LiteralPath $output -Directory -Filter 'katex.*').Count | Should -Be 1
    }

    It 'publishes one complete directory when multiple renders copy concurrently' {
        $jobs = 1..4 | ForEach-Object {
            Start-Job -ScriptBlock {
                param($ModulePath, $SourcePath, $OutputPath)

                Import-Module $ModulePath -Force
                Copy-MarkViewOutputAssetBundle `
                    -SourcePath $SourcePath `
                    -OutputDirectory $OutputPath `
                    -BundleName 'katex' `
                    -RequiredFiles @('katex.min.js', 'katex.min.css', 'fonts/KaTeX_Main.woff2')
            } -ArgumentList $SharedModulePath, $source, $output
        }

        try {
            $jobs | Wait-Job | Out-Null
            $results = @($jobs | Receive-Job -ErrorAction Stop)

            @($results | Select-Object -Unique).Count | Should -Be 1
            Join-Path $results[0] 'katex.min.js' | Should -Exist
            Join-Path $results[0] 'katex.min.css' | Should -Exist
            Join-Path $results[0] 'fonts/KaTeX_Main.woff2' | Should -Exist
            @(Get-ChildItem -LiteralPath $output -Directory -Filter '.katex.*.tmp').Count | Should -Be 0
        }
        finally {
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }

    It 'changes the destination identity when a nested asset changes' {
        $first = Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')
        [IO.File]::WriteAllBytes((Join-Path $source 'fonts/KaTeX_Main.woff2'), [byte[]](9, 8, 7))

        $second = Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')

        $second | Should -Not -Be $first
    }

    It 'rejects an existing content-addressed directory whose bytes were changed' {
        $published = Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')
        [IO.File]::WriteAllText((Join-Path $published 'katex.min.js'), 'window.katex = { tampered: true };')

        {
            Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')
        } | Should -Throw '*content-integrity*'
    }

    It 'rejects an incomplete source bundle' {
        Remove-Item -LiteralPath (Join-Path $source 'katex.min.css')

        {
            Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('katex.min.js', 'katex.min.css')
        } | Should -Throw '*required file*'
    }

    It 'rejects required paths that escape the source bundle' {
        {
            Copy-MarkViewOutputAssetBundle -SourcePath $source -OutputDirectory $output -BundleName 'katex' -RequiredFiles @('../outside.js')
        } | Should -Throw '*outside*'
    }
}

Describe 'Vendored KaTeX runtime' {
    BeforeAll {
        $KaTeXRoot = Join-Path $RepoRoot 'src/core/vendor/katex'
        $KaTeXJs = Join-Path $KaTeXRoot 'katex.min.js'
        $KaTeXCss = Join-Path $KaTeXRoot 'katex.min.css'
    }

    It 'contains the pinned browser runtime, provenance, and license' {
        $KaTeXJs | Should -Exist
        $KaTeXCss | Should -Exist
        Join-Path $KaTeXRoot 'README.md' | Should -Exist
        Join-Path $KaTeXRoot 'LICENSE' | Should -Exist
        (Get-Content -Raw -LiteralPath $KaTeXJs) | Should -Match 'version:"0\.18\.3"'
    }

    It 'matches the recorded core asset hashes' {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $KaTeXJs).Hash.ToLowerInvariant() |
            Should -Be '131beffe9e8d48e06ee969e298190127b230f17c656e6b6c471a705406b7d655'
        (Get-FileHash -Algorithm SHA256 -LiteralPath $KaTeXCss).Hash.ToLowerInvariant() |
            Should -Be '7993c99e764314d0d6ee0a926c3ac0a75a89182ff58493f9d40310c5e932003f'
    }

    It 'contains every font referenced by the official stylesheet' {
        $css = Get-Content -Raw -LiteralPath $KaTeXCss
        $fontReferences = [regex]::Matches($css, 'url\(([^)]+)\)') |
            ForEach-Object { $_.Groups[1].Value.Trim('"', '''') } |
            Sort-Object -Unique

        $fontReferences.Count | Should -Be 60
        foreach ($fontReference in $fontReferences) {
            Join-Path $KaTeXRoot $fontReference | Should -Exist
        }
    }

    It 'has no runtime fetch URL or auto-render extension' {
        $runtimeContent = (Get-Content -Raw -LiteralPath $KaTeXJs) + (Get-Content -Raw -LiteralPath $KaTeXCss)
        $urls = [regex]::Matches($runtimeContent, 'https?://[^"''\s]+') |
            ForEach-Object Value |
            Sort-Object -Unique

        $urls | Should -HaveCount 2
        $urls | Should -Contain 'http://www.w3.org/1998/Math/MathML'
        $urls | Should -Contain 'http://www.w3.org/2000/svg'
        $runtimeContent | Should -Not -Match 'renderMathInElement'
        Join-Path $KaTeXRoot 'contrib' | Should -Not -Exist
    }
}

Describe 'Open-Markdown math integration contract' {
    BeforeAll {
        $OpenMarkdownPath = Join-Path $RepoRoot 'src/core/Open-Markdown.ps1'
        $OpenMarkdownContent = Get-Content -Raw -LiteralPath $OpenMarkdownPath
    }

    It 'accepts a configurable KaTeX root and uses converter-output detection' {
        $OpenMarkdownContent | Should -Match '\$KaTeXRootPath\s*='
        $OpenMarkdownContent | Should -Match 'Test-MarkViewMathHtml\s+-Html\s+\$html'
        $OpenMarkdownContent | Should -Match 'Copy-MarkViewOutputAssetBundle'
    }

    It 'adds the narrow local-font CSP permission without weakening script policy' {
        $OpenMarkdownContent | Should -Match 'font-src file:'
        $OpenMarkdownContent | Should -Match 'script-src ''nonce-\$nonce'' file:'
        $OpenMarkdownContent | Should -Not -Match 'unsafe-inline|unsafe-eval'
    }

    It 'assembles KaTeX CSS and deferred JavaScript before the viewer script' {
        $OpenMarkdownContent | Should -Match '\$katexStyleLink\s*=.*<link rel='
        $OpenMarkdownContent | Should -Match '\$katexScript\s*=.*<script src=.*defer'
        $OpenMarkdownContent | Should -Match '(?s)\$katexStyleLink.*</head>.*\$katexScript.*<script nonce="\$nonce">'
    }

    It 'does not reference a CDN or KaTeX auto-render' {
        $OpenMarkdownContent | Should -Not -Match 'cdn\.jsdelivr|unpkg\.com|auto-render|renderMathInElement'
    }
}

Describe 'Browser math renderer contract' {
    BeforeAll {
        $ScriptContent = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'src/core/script.js')
        $StyleContent = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'src/core/style.css')
    }

    It 'selects only converter math elements and reads source as text' {
        $ScriptContent | Should -Match 'span\.math,\s*div\.math'
        $ScriptContent | Should -Match '\.textContent'
        $ScriptContent | Should -Not -Match 'renderMathInElement'
    }

    It 'validates Markdig wrappers and calls the direct KaTeX API' {
        $ScriptContent | Should -Match '\\\(|\\\['
        $ScriptContent | Should -Match 'katex\.render\('
        $ScriptContent | Should -Match 'displayMode'
    }

    It 'uses explicit safe and accessible KaTeX options' {
        $ScriptContent | Should -Match 'output:\s*["'']htmlAndMathml["'']'
        $ScriptContent | Should -Match 'throwOnError:\s*false'
        $ScriptContent | Should -Match 'strict:\s*["'']warn["'']'
        $ScriptContent | Should -Match 'trust:\s*false'
        $ScriptContent | Should -Match 'maxSize:\s*10'
        $ScriptContent | Should -Match 'maxExpand:\s*1000'
        $ScriptContent | Should -Match 'globalGroup:\s*false'
    }

    It 'has count, source-size, idempotence, and missing-library guards' {
        $ScriptContent | Should -Match 'MAX_MATH_NODES\s*=\s*1000'
        $ScriptContent | Should -Match 'MAX_MATH_SOURCE_LENGTH\s*=\s*102400'
        $ScriptContent | Should -Match 'mathRendered'
        $ScriptContent | Should -Match 'typeof katex === ["'']undefined["'']'
    }

    It 'styles display overflow and readable fallback output' {
        $StyleContent | Should -Match '\.math-unrendered'
        $StyleContent | Should -Match '\.katex-display'
        $StyleContent | Should -Match 'overflow-x:\s*auto'
        $StyleContent | Should -Match '@media print'
    }
}

Describe 'Generated HTML math integration' {
    BeforeAll {
        $OpenMarkdownPath = Join-Path $RepoRoot 'src/core/Open-Markdown.ps1'
        $StylePath = Join-Path $RepoRoot 'src/core/style.css'
        $ScriptPath = Join-Path $RepoRoot 'src/core/script.js'
        $KaTeXRoot = Join-Path $RepoRoot 'src/core/vendor/katex'

        function New-TestPlatformModule {
            param(
                [Parameter(Mandatory)][string] $OutputDirectory,
                [Parameter(Mandatory)][string] $ModulePath
            )

            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
            $escapedShared = $SharedModulePath.Replace("'", "''")
            $escapedOutput = $OutputDirectory.Replace("'", "''")
            $moduleContent = @'
Import-Module '__SHARED__' -Force
function Initialize-PlatformUI {}
function Test-Motw { param([string] $FilePath) return 0 }
function Clear-FileTrustMarker { param([string] $FilePath) }
function Show-MotwWarning { param([string] $FilePath) return 'Open' }
function Show-FileNotFound { param([string] $FilePath, [string] $FromLink) throw "File not found: $FilePath" }
function Show-ErrorDialog { param([string] $Message) throw $Message }
function Get-MarkViewOutputDirectory { return '__OUTPUT__' }
function Get-FileBaseHref {
    param([string] $FilePath)
    $directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($FilePath)) + [IO.Path]::DirectorySeparatorChar
    return ([Uri]::new($directory)).AbsoluteUri
}
function Start-DefaultBrowser { param([string] $Url) }
Export-ModuleMember -Function @(
    'Invoke-HtmlSanitization', 'Test-RemoteImages', 'Test-MarkViewMathHtml',
    'Copy-MarkViewOutputAssetBundle', 'Write-MarkViewTextFile',
    'Repair-MarkdownLinks', 'Repair-HtmlLinks', 'Initialize-PlatformUI',
    'Test-Motw', 'Clear-FileTrustMarker', 'Show-MotwWarning',
    'Show-FileNotFound', 'Show-ErrorDialog', 'Get-MarkViewOutputDirectory',
    'Get-FileBaseHref', 'Start-DefaultBrowser'
)
'@
            $moduleContent = $moduleContent.Replace('__SHARED__', $escapedShared).Replace('__OUTPUT__', $escapedOutput)
            [IO.File]::WriteAllText($ModulePath, $moduleContent)
        }

        function Invoke-TestRender {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)][string] $Markdown,
                [Parameter(Mandatory)][string] $CaseName,
                [string] $MathRootPath = $KaTeXRoot
            )

            $caseDirectory = Join-Path $TestDrive $CaseName
            $outputDirectory = Join-Path $caseDirectory 'output'
            $modulePath = Join-Path $caseDirectory 'TestPlatform.psm1'
            $markdownPath = Join-Path $caseDirectory "$CaseName.md"
            New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
            [IO.File]::WriteAllText($markdownPath, $Markdown)
            New-TestPlatformModule -OutputDirectory $outputDirectory -ModulePath $modulePath

            $inputUri = ([Uri]::new($markdownPath)).AbsoluteUri + '?_fragment=unused'
            & $OpenMarkdownPath `
                -Path $inputUri `
                -StylePath $StylePath `
                -ScriptPath $ScriptPath `
                -IconPath (Join-Path $caseDirectory 'missing.ico') `
                -KaTeXRootPath $MathRootPath `
                -ModulePath $modulePath

            $htmlFile = Get-ChildItem -LiteralPath $outputDirectory -Filter 'viewmd_*.html' -File | Select-Object -First 1
            return [pscustomobject]@{
                Html = [IO.File]::ReadAllText($htmlFile.FullName)
                OutputDirectory = $outputDirectory
            }
        }
    }

    It 'adds local KaTeX assets and publishes the complete bundle for a math document' {
        $rendered = Invoke-TestRender -Markdown 'Inline $x^2$.' -CaseName 'with-math'

        $rendered.Html | Should -Match '<link rel="stylesheet" href="file:[^"]*/katex\.[0-9a-f]{12}/katex\.min\.css">'
        $rendered.Html | Should -Match '<script src="file:[^"]*/katex\.[0-9a-f]{12}/katex\.min\.js" defer></script>'
        $rendered.Html | Should -Match 'font-src file:'
        $bundle = Get-ChildItem -LiteralPath $rendered.OutputDirectory -Directory -Filter 'katex.*' | Select-Object -First 1
        Join-Path $bundle.FullName 'fonts/KaTeX_Main-Regular.woff2' | Should -Exist
    }

    It 'does not publish or link KaTeX for a document without math nodes' {
        $rendered = Invoke-TestRender -Markdown 'Plain **Markdown** without equations.' -CaseName 'without-math'

        $rendered.Html | Should -Not -Match '<link rel="stylesheet" href="[^"]*katex\.'
        $rendered.Html | Should -Not -Match '<script src="[^"]*katex\.'
        Get-ChildItem -LiteralPath $rendered.OutputDirectory -Directory -Filter 'katex.*' | Should -BeNullOrEmpty
    }

    It 'keeps converter TeX visible and continues when the installed bundle is missing' {
        $warnings = @()
        $rendered = Invoke-TestRender `
            -Markdown 'Inline $x^2$.' `
            -CaseName 'missing-math-runtime' `
            -MathRootPath (Join-Path $TestDrive 'missing-katex') `
            -WarningVariable warnings `
            -WarningAction SilentlyContinue

        $rendered.Html | Should -Match '<span class="math">\\\(x\^2\\\)</span>'
        $rendered.Html | Should -Not -Match '<(?:link|script)[^>]+katex\.'
        ($warnings | Out-String) | Should -Match 'Math typesetting is unavailable'
    }
}

Describe 'Math asset packaging definitions' {
    BeforeAll {
        $AdHocInstaller = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'installers/win-adhoc/install.ps1')
        $MsixStage = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'installers/win-msix/build/stage.ps1')
        $MsixBuild = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'installers/win-msix/build.ps1')
        $SnapBuild = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'installers/linux-snap/build.sh')
        $MacBuild = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'installers/macos-dmg/build.sh')
        $StagedPayloadTest = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'tests/Test-StagedPayload.ps1')
    }

    It 'copies the complete KaTeX tree and notice in the Windows ad-hoc installer' {
        $AdHocInstaller | Should -Match '(?s)Copy-Item.*vendor.*-Recurse'
        $AdHocInstaller | Should -Match 'THIRD-PARTY-LICENSES\.md'
        $AdHocInstaller | Should -Match '(?s)Get-ChildItem.*vendor.*-Recurse.*IsReadOnly'
    }

    It 'stages and validates the complete KaTeX tree and notice for MSIX' {
        $MsixStage | Should -Match '(?s)Copy-Item.*vendor.*-Recurse'
        $MsixStage | Should -Match 'THIRD-PARTY-LICENSES\.md'
        $MsixStage | Should -Match 'vendor[\\/]katex[\\/]fonts'
        ([regex]::Matches($MsixBuild, '(?is)Copy-Item[^\r\n]*vendor[^\r\n]*-Recurse')).Count | Should -BeGreaterOrEqual 2
        ([regex]::Matches($MsixBuild, 'THIRD-PARTY-LICENSES\.md')).Count | Should -BeGreaterOrEqual 2
    }

    It 'stages the complete KaTeX tree and notice for Snap and macOS' {
        $SnapBuild | Should -Match '(?m)^cp -R .*vendor/katex'
        $SnapBuild | Should -Match 'THIRD-PARTY-LICENSES\.md'
        $MacBuild | Should -Match '(?m)^cp -R .*vendor/katex'
        $MacBuild | Should -Match 'THIRD-PARTY-LICENSES\.md'
    }

    It 'requires KaTeX runtime files, a font, and the notice in staged payload validation' {
        $StagedPayloadTest | Should -Match 'vendor[\\/]katex[\\/]katex\.min\.js'
        $StagedPayloadTest | Should -Match 'vendor[\\/]katex[\\/]katex\.min\.css'
        $StagedPayloadTest | Should -Match 'KaTeX_Main-Regular\.woff2'
        $StagedPayloadTest | Should -Match 'vendor[\\/]katex[\\/]README\.md'
        $StagedPayloadTest | Should -Match 'THIRD-PARTY-LICENSES\.md'
    }
}
