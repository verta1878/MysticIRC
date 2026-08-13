[CmdletBinding()]
param(
    [switch]$SpectrumOnly,
    [switch]$ClientOnly
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Remove-GeneratedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }

    $resolved = (Resolve-Path -LiteralPath $path).Path
    $rootPrefix = $Root.TrimEnd('\') + '\'

    if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove outside project tree: $resolved"
    }

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
            return
        } catch {
            if ($attempt -eq 10) {
                throw
            }
            Start-Sleep -Milliseconds 300
        }
    }
}

function Remove-EmptyGeneratedDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return
    }

    $resolved = (Resolve-Path -LiteralPath $path).Path
    $rootPrefix = $Root.TrimEnd('\') + '\'

    if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove outside project tree: $resolved"
    }

    if ((Get-ChildItem -LiteralPath $resolved -Force | Select-Object -First 1) -eq $null) {
        Remove-Item -LiteralPath $resolved -Force -ErrorAction Stop
    }
}

function Remove-GeneratedGlob {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePattern
    )

    $matches = Get-ChildItem -Path (Join-Path $Root $RelativePattern) -Force -ErrorAction SilentlyContinue
    foreach ($item in $matches) {
        $resolved = (Resolve-Path -LiteralPath $item.FullName).Path
        $rootPrefix = $Root.TrimEnd('\') + '\'

        if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove outside project tree: $resolved"
        }

        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
}

Remove-GeneratedPath ".aider.chat.history.md"
Remove-GeneratedPath ".aider.input.history"
Remove-GeneratedPath ".aider.tags.cache.v4"
Remove-GeneratedPath ".ruff_cache"
Remove-GeneratedPath "aider-pro"

if (-not $ClientOnly) {
    Remove-GeneratedPath "build"
    Remove-GeneratedPath "build-next"
    Remove-GeneratedPath "build-nex"
    Remove-GeneratedPath "dist"
    Get-ChildItem -Path (Join-Path $Root "src") -Recurse -Filter "*.c.asm" -Force -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-GeneratedPath "release\NCHESSZX.tap"
    Remove-GeneratedPath "release\NCHESSZX.OVL"
    Remove-GeneratedPath "release\NCHESSZX.DAT"
    Remove-GeneratedPath "release\SHATRANJ.tap"
    Remove-GeneratedPath "release\SHATRANJ.OVL"
    Remove-GeneratedPath "release\SHATRANJ.DAT"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_W.tap"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_W.OVL"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_W.DAT"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_B.tap"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_B.OVL"
    Remove-GeneratedPath "release\NCHESSZX_MQTT_B.DAT"
    Remove-GeneratedPath "release\MQTTW"
    Remove-GeneratedPath "release\MQTTB"
    Remove-GeneratedPath "release\MQTTWKEY"
    Remove-GeneratedPath "release\MQTTBKEY"
    Remove-GeneratedPath "release\ZXCHNET.tap"
    Remove-GeneratedPath "release\next"
    Remove-GeneratedPath "release\nex"
    Remove-GeneratedPath "release\Next"
    Remove-GeneratedPath "asm\overlay\rules\entry_rules.o"
    Remove-GeneratedPath "asm\overlay\rules\rules_stub.o"
    Remove-GeneratedPath "experimentos\banner-tall-demo\banner_demo.bin"
    Remove-GeneratedPath "experimentos\banner-tall-demo\banner_demo.lst"
    Remove-GeneratedPath "experimentos\banner-tall-demo\banner_demo.tap"
    Remove-GeneratedPath "experimentos\ikkle-pawn-glyphs"
    Remove-GeneratedPath "experimentos\ikkle-text-scale-demo\build"
    Remove-GeneratedPath "experimentos\pawn-glyphs-3x8"
    Remove-GeneratedPath "experimentos\pawn-glyphs-4x6"
    Remove-GeneratedPath "experimentos\pawn-glyphs-4x8"
    Remove-GeneratedPath "experimentos\screen-rebuild-ikkle2-demo\build"
    Remove-EmptyGeneratedDir "release"
}

if (-not $SpectrumOnly) {
    Remove-GeneratedPath "client\build"
    Remove-GeneratedPath "client\build_manual"
    Remove-GeneratedPath "client\build_verify"
    Remove-GeneratedPath "client\dist"
    Remove-GeneratedPath "release\shatranj-client"
    Remove-GeneratedPath "release\shatranj"
    Remove-GeneratedPath "release\netchesszx-client"
    Remove-EmptyGeneratedDir "release"
    Remove-GeneratedPath "main.obj"
}
