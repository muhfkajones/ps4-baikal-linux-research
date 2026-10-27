# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Zig,

    [Parameter(Mandatory)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$source = Join-Path $projectRoot 'payloads\hen-loader-boundary\source\main.c'
$libPs4 = Join-Path $SdkRoot 'libPS4'
$buildRoot = Join-Path $projectRoot 'build\HenLoaderBoundary'
$cacheRoot = Join-Path $workspaceRoot '.zig-local-cache\hen-loader-boundary'
$globalCacheRoot = Join-Path $workspaceRoot '.zig-global-cache\hen-loader-boundary'

foreach ($required in @(
    $Zig,
    $source,
    (Join-Path $libPs4 'include\ps4.h'),
    (Join-Path $libPs4 'crt0.s'),
    (Join-Path $libPs4 'linker.x'),
    (Join-Path $libPs4 'libPS4-zig.a')
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required input not found: $required"
    }
}

New-Item -ItemType Directory -Force -Path $buildRoot, $cacheRoot, $globalCacheRoot | Out-Null
$env:ZIG_LOCAL_CACHE_DIR = $cacheRoot
$env:ZIG_GLOBAL_CACHE_DIR = $globalCacheRoot

$mainObject = Join-Path $buildRoot 'main.o'
$compileArguments = @(
    'cc', '-target', 'x86_64-freebsd',
    '-I', (Join-Path $libPs4 'include'),
    '-Os', '-std=c11', '-ffunction-sections', '-fdata-sections',
    '-fno-builtin', '-nostdlib', '-Wall', '-Wextra',
    '-masm=intel', '-march=btver2', '-mtune=btver2', '-m64',
    '-mabi=sysv', '-mcmodel=small', '-fpie', '-fPIC',
    '-c', $source, '-o', $mainObject
)
& $Zig @compileArguments
if ($LASTEXITCODE -ne 0) { throw "main.c compilation failed: $LASTEXITCODE" }

$crtObject = Join-Path $buildRoot 'crt0.o'
& $Zig cc -target x86_64-freebsd -c (Join-Path $libPs4 'crt0.s') -o $crtObject
if ($LASTEXITCODE -ne 0) { throw "crt0 compilation failed: $LASTEXITCODE" }

$elf = Join-Path $buildRoot 'hen-loader-boundary-1350.elf'
$linkArguments = @(
    'cc', '-target', 'x86_64-freestanding', '-nostartfiles', '-nostdlib',
    "-Wl,-T,$(Join-Path $libPs4 'linker.x')",
    '-Wl,--build-id=none', '-Wl,--gc-sections',
    $crtObject, $mainObject, (Join-Path $libPs4 'libPS4-zig.a'),
    '-o', $elf
)
& $Zig @linkArguments
if ($LASTEXITCODE -ne 0) { throw "ELF link failed: $LASTEXITCODE" }

$binary = Join-Path $buildRoot 'hen-loader-boundary-1350.bin'
& $Zig objcopy -O binary $elf $binary
if ($LASTEXITCODE -ne 0) { throw "Binary extraction failed: $LASTEXITCODE" }

$elfItem = Get-Item -LiteralPath $elf
$binaryItem = Get-Item -LiteralPath $binary
[pscustomobject]@{
    ELF = $elfItem.FullName
    ELFBytes = $elfItem.Length
    ELFSHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $elf).Hash
    Binary = $binaryItem.FullName
    BinaryBytes = $binaryItem.Length
    BinarySHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $binary).Hash
}
