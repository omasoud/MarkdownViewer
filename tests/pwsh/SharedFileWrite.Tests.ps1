# SharedFileWrite.Tests.ps1 - Stable temporary HTML write tests

#Requires -Version 7.0

BeforeAll {
    $ScriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $platform = if ($IsWindows) { 'win' } elseif ($IsMacOS) { 'mac' } else { 'linux' }
    $ModulePath = Join-Path $ScriptRoot "src/$platform/MarkdownViewer.psm1"
    Import-Module $ModulePath -Force -Global
}

AfterAll {
    Remove-Module MarkdownViewer -Force -ErrorAction SilentlyContinue
}

Describe 'Write-MarkViewTextFile' {
    It 'writes UTF-8 content without a byte-order mark' {
        $path = Join-Path $TestDrive 'output.html'

        Write-MarkViewTextFile -Path $path -Content '<p>héllo</p>'

        [IO.File]::ReadAllText($path) | Should -Be '<p>héllo</p>'
        $bytes = [IO.File]::ReadAllBytes($path)
        ($bytes[0..2] -join ',') | Should -Not -Be '239,187,191'
    }

    It 'retries a transient sharing violation and preserves the stable path' {
        $path = Join-Path $TestDrive 'contended.html'
        $signalPath = Join-Path $TestDrive 'lock-ready'
        [IO.File]::WriteAllText($path, 'old')

        $holder = Start-Job -ScriptBlock {
            param($LockedPath, $ReadyPath)

            $stream = [IO.File]::Open($LockedPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                [IO.File]::WriteAllText($ReadyPath, 'ready')
                Start-Sleep -Milliseconds 350
            }
            finally {
                $stream.Dispose()
            }
        } -ArgumentList $path, $signalPath

        try {
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path -LiteralPath $signalPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 25
            }
            Test-Path -LiteralPath $signalPath | Should -BeTrue

            Write-MarkViewTextFile -Path $path -Content 'new' -MaxAttempts 8 -RetryDelayMilliseconds 25

            [IO.File]::ReadAllText($path) | Should -Be 'new'
            $path | Should -Exist
        }
        finally {
            Wait-Job $holder -Timeout 5 | Out-Null
            Remove-Job $holder -Force -ErrorAction SilentlyContinue
        }
    }

    It 'surfaces a sharing violation after the retry budget is exhausted' {
        $path = Join-Path $TestDrive 'locked.html'
        [IO.File]::WriteAllText($path, 'old')
        $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)

        try {
            { Write-MarkViewTextFile -Path $path -Content 'new' -MaxAttempts 2 -RetryDelayMilliseconds 1 } |
                Should -Throw
        }
        finally {
            $stream.Dispose()
        }
    }
}
