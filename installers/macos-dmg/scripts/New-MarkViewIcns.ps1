# New-MarkViewIcns.ps1
# Generates a macOS .icns file from a source PNG.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourcePng,

    [Parameter(Mandatory)]
    [string]$OutputIcns
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourcePng)) {
    throw "Source PNG not found: $SourcePng"
}

foreach ($cmd in @('/usr/bin/sips', '/usr/bin/iconutil')) {
    if (-not (Test-Path $cmd)) {
        throw "Required macOS tool not found: $cmd"
    }
}

$outputFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputIcns)
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("markview-iconset-" + [guid]::NewGuid().ToString('N'))
$iconset = Join-Path $workRoot 'markview.iconset'

try {
    New-Item -ItemType Directory -Path $iconset -Force | Out-Null

    $sizes = @(
        @{ Size = 16;  Name = 'icon_16x16.png' },
        @{ Size = 32;  Name = 'icon_16x16@2x.png' },
        @{ Size = 32;  Name = 'icon_32x32.png' },
        @{ Size = 64;  Name = 'icon_32x32@2x.png' },
        @{ Size = 128; Name = 'icon_128x128.png' },
        @{ Size = 256; Name = 'icon_128x128@2x.png' },
        @{ Size = 256; Name = 'icon_256x256.png' },
        @{ Size = 512; Name = 'icon_256x256@2x.png' },
        @{ Size = 512; Name = 'icon_512x512.png' }
    )

    foreach ($entry in $sizes) {
        $dest = Join-Path $iconset $entry.Name
        & /usr/bin/sips -z $entry.Size $entry.Size $SourcePng --out $dest >$null
        if ($LASTEXITCODE -ne 0) {
            throw "sips failed while creating $($entry.Name)"
        }
    }

    $outputDir = Split-Path -Parent $outputFull
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    & /usr/bin/iconutil -c icns $iconset -o $outputFull
    if ($LASTEXITCODE -ne 0) {
        throw 'iconutil failed.'
    }

    Write-Host "Created: $outputFull"
}
finally {
    if (Test-Path $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
