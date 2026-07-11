# MsixFileAssociation.Tests.ps1 - MSIX file association contract tests

#Requires -Version 7.0

BeforeAll {
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ManifestPath = Join-Path $ScriptRoot 'installers/win-msix/Package.appxmanifest'

    [xml]$Manifest = Get-Content -LiteralPath $ManifestPath -Raw
    $NamespaceManager = [System.Xml.XmlNamespaceManager]::new($Manifest.NameTable)
    $NamespaceManager.AddNamespace('foundation', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
    $NamespaceManager.AddNamespace('uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
    $NamespaceManager.AddNamespace('uap3', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3')
}

Describe 'MSIX Markdown file association' {
    BeforeAll {
        $FileAssociation = $Manifest.SelectSingleNode(
            '/foundation:Package/foundation:Applications/foundation:Application/foundation:Extensions/uap:Extension[@Category="windows.fileTypeAssociation"]/uap3:FileTypeAssociation',
            $NamespaceManager
        )
    }

    It 'uses the uap3 file association schema' {
        $FileAssociation | Should -Not -BeNullOrEmpty
    }

    It 'uses Player mode so one activation receives the full Explorer selection' {
        $FileAssociation.MultiSelectModel | Should -Be 'Player'
    }

    It 'registers both Markdown extensions' {
        $fileTypes = $FileAssociation.SelectNodes('uap:SupportedFileTypes/uap:FileType', $NamespaceManager).InnerText
        $fileTypes | Should -Contain '.md'
        $fileTypes | Should -Contain '.markdown'
    }
}

Describe 'Built MSIX Markdown file association' -Skip:(-not $IsWindows) {
    It 'preserves Player mode in the packaged manifest' {
        $msixPath = Get-ChildItem (Join-Path $ScriptRoot 'installers/win-msix/output/MarkdownViewer_*.msix') -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        $packageWasBuiltForCurrentSources = $msixPath -and $msixPath.LastWriteTimeUtc -ge (Get-Item $ManifestPath).LastWriteTimeUtc
        if (-not $packageWasBuiltForCurrentSources) {
            if ($env:INVOKE_ALL_TESTS_MSIX_BUILT -eq '1') {
                $packageWasBuiltForCurrentSources | Should -BeTrue -Because 'the full test runner built an MSIX from the current manifest'
            }
            else {
                Set-ItResult -Skipped -Because 'No MSIX built from the current manifest is available'
            }
            return
        }

        $extractPath = Join-Path $TestDrive 'msix'
        Expand-Archive -LiteralPath $msixPath.FullName -DestinationPath $extractPath -Force

        [xml]$packagedManifest = Get-Content (Join-Path $extractPath 'AppxManifest.xml') -Raw
        $packagedNamespaces = [System.Xml.XmlNamespaceManager]::new($packagedManifest.NameTable)
        $packagedNamespaces.AddNamespace('foundation', 'http://schemas.microsoft.com/appx/manifest/foundation/windows10')
        $packagedNamespaces.AddNamespace('uap', 'http://schemas.microsoft.com/appx/manifest/uap/windows10')
        $packagedNamespaces.AddNamespace('uap3', 'http://schemas.microsoft.com/appx/manifest/uap/windows10/3')

        $packagedAssociation = $packagedManifest.SelectSingleNode(
            '/foundation:Package/foundation:Applications/foundation:Application/foundation:Extensions/uap:Extension[@Category="windows.fileTypeAssociation"]/uap3:FileTypeAssociation',
            $packagedNamespaces
        )

        $packagedAssociation | Should -Not -BeNullOrEmpty
        $packagedAssociation.MultiSelectModel | Should -Be 'Player'
    }
}
