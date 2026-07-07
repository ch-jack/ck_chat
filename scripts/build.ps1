# ck_chat 构建脚本
# 作者: JACK
# 联系方式: QQ 2518926462

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Dist = Join-Path $Root "dist"
$PackageDir = Join-Path $Dist "ck_chat"
$ZipPath = Join-Path $Dist "ck_chat.zip"

if (Test-Path $Dist) {
    Remove-Item -LiteralPath $Dist -Recurse -Force
}

New-Item -ItemType Directory -Path $PackageDir | Out-Null

$include = @(
    "fxmanifest.lua",
    "config.lua",
    "client.lua",
    "server.lua",
    "framework",
    "html",
    "docs",
    "README.md",
    "LICENSE"
)

foreach ($item in $include) {
    $source = Join-Path $Root $item
    if (-not (Test-Path $source)) {
        continue
    }

    $target = Join-Path $PackageDir $item
    if ((Get-Item $source).PSIsContainer) {
        Copy-Item -LiteralPath $source -Destination $target -Recurse
    } else {
        Copy-Item -LiteralPath $source -Destination $target
    }
}

if (Test-Path $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $ZipPath -Force
Write-Host "Built $ZipPath"
