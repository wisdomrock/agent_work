[CmdletBinding()]
param(
    [string]$OutputDirectory = "dist"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $root ".claude-plugin/plugin.json"
$skillPaths = @(
    (Join-Path $root "skills/explain-file/SKILL.md"),
    (Join-Path $root "skills/explain-selection/SKILL.md")
)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Missing plugin manifest: $manifestPath"
}

foreach ($skillPath in $skillPaths) {
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        throw "Missing skill file: $skillPath"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.name) -or [string]::IsNullOrWhiteSpace($manifest.version)) {
    throw "The plugin manifest must define non-empty name and version fields."
}

$outputPath = Join-Path $root $OutputDirectory
$zipPath = Join-Path $outputPath ("{0}-{1}.zip" -f $manifest.name, $manifest.version)
$stagingPath = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-plugin-{0}" -f [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root ".claude-plugin") -Destination $stagingPath -Recurse
    Copy-Item -LiteralPath (Join-Path $root "skills") -Destination $stagingPath -Recurse

    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $stagingPath "*") -DestinationPath $zipPath
    Write-Output "Built $zipPath"
}
finally {
    if (Test-Path -LiteralPath $stagingPath) {
        Remove-Item -LiteralPath $stagingPath -Recurse -Force
    }
}