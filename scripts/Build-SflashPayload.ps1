# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors
# Third-party build dependency provenance is documented in CREDITS.md.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Raw', 'WholeCrypt', 'S1Crypt')]
    [string]$Variant,

    [Parameter(Mandatory)]
    [string]$Zig,

    [Parameter(Mandatory)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$payloadRoot = Join-Path $projectRoot 'payloads\sflash-readonly'
$source = Join-Path $payloadRoot 'source\main.c'
$libPs4 = Join-Path $SdkRoot 'libPS4'
$outputName = switch ($Variant) {
    'Raw'        { 'sflash-dumper-readonly' }
    'WholeCrypt' { 'sflash-crypt-dumper-readonly' }
    'S1Crypt'    { 'sflash-s1-crypt-dumper-readonly' }
}
$variantHeader = switch ($Variant) {
    'Raw'        { $null }
    'WholeCrypt' { Join-Path $payloadRoot 'variants\whole-crypt.h' }
    'S1Crypt'    { Join-Path $payloadRoot 'variants\s1-crypt.h' }
}
$buildRoot = Join-Path $projectRoot "build\$Variant"
$cacheRoot = Join-Path $projectRoot '.zig-cache'
$globalCacheRoot = Join-Path $projectRoot '.zig-global'

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

$commonCompile = @(
    'cc', '-target', 'x86_64-freebsd',
    '-I', (Join-Path $libPs4 'include'),
    '-Os', '-std=c11', '-ffunction-sections', '-fdata-sections',
    '-fno-builtin', '-nostartfiles', '-nostdlib', '-Wall', '-Wextra',
    '-masm=intel', '-march=btver2', '-mtune=btver2', '-m64',
    '-mabi=sysv', '-mcmodel=small', '-fpie', '-fPIC'
)
$mainArgs = [System.Collections.Generic.List[string]]::new()
$mainArgs.AddRange([string[]]$commonCompile)
if ($variantHeader) {
    $mainArgs.Add('-include')
    $mainArgs.Add($variantHeader)
}
$mainArgs.Add('-c')
$mainArgs.Add($source)
$mainArgs.Add('-o')
$mainArgs.Add((Join-Path $buildRoot 'main.o'))
& $Zig @mainArgs
if ($LASTEXITCODE -ne 0) { throw "main.c compilation failed: $LASTEXITCODE" }

$crtArgs = @(
    'cc', '-target', 'x86_64-freebsd', '-c',
    (Join-Path $libPs4 'crt0.s'),
    '-o', (Join-Path $buildRoot 'crt0.o')
)
& $Zig @crtArgs
if ($LASTEXITCODE -ne 0) { throw "crt0 compilation failed: $LASTEXITCODE" }

$elf = Join-Path $buildRoot "$outputName.elf"
$linkArgs = @(
    'cc', '-target', 'x86_64-freestanding', '-nostartfiles', '-nostdlib',
    "-Wl,-T,$(Join-Path $libPs4 'linker.x')",
    '-Wl,--build-id=none', '-Wl,--gc-sections',
    (Join-Path $buildRoot 'crt0.o'),
    (Join-Path $buildRoot 'main.o'),
    (Join-Path $libPs4 'libPS4-zig.a'),
    '-o', $elf
)
& $Zig @linkArgs
if ($LASTEXITCODE -ne 0) { throw "ELF link failed: $LASTEXITCODE" }

$binary = Join-Path $buildRoot "$outputName.bin"
& $Zig objcopy -O binary $elf $binary
if ($LASTEXITCODE -ne 0) { throw "Binary extraction failed: $LASTEXITCODE" }

$item = Get-Item -LiteralPath $binary
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $binary
[pscustomobject]@{
    Variant = $Variant
    Binary = $item.FullName
    Bytes = $item.Length
    SHA256 = $hash.Hash
}
