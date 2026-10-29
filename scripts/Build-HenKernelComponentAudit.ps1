# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Zig,
    [Parameter(Mandatory)][string]$Objcopy,
    [Parameter(Mandatory)][string]$HenSourceRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$LinkerScript,
    [string]$CacheDirectory,
    [string]$ExpectedELFSHA256,
    [string]$ExpectedBinarySHA256
)

$ErrorActionPreference = 'Stop'
$henRoot = [IO.Path]::GetFullPath($HenSourceRoot)
$kpayload = Join-Path $henRoot 'kpayload'
$sourceRoot = Join-Path $kpayload 'source'
$includeRoot = Join-Path $kpayload 'include'
$linker = if ($LinkerScript) { [IO.Path]::GetFullPath($LinkerScript) } else { Join-Path $kpayload 'linker.x' }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
$objectRoot = Join-Path $outputRoot 'obj'
$cacheBase = if ($CacheDirectory) { [IO.Path]::GetFullPath($CacheDirectory) } else { $outputRoot }
$cacheRoot = Join-Path $cacheBase 'zig-local-cache'
$globalCacheRoot = Join-Path $cacheBase 'zig-global-cache'

foreach ($required in @($Zig, $Objcopy, $sourceRoot, $includeRoot, $linker)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required input not found: $required" }
}

New-Item -ItemType Directory -Force -Path $outputRoot, $objectRoot, $cacheRoot, $globalCacheRoot | Out-Null
$env:ZIG_LOCAL_CACHE_DIR = $cacheRoot
$env:ZIG_GLOBAL_CACHE_DIR = $globalCacheRoot

$objects = @()
$sourceByRelativePath = @{}
# Normalize separators and use ordinal ordering so directory entries such as
# offsets/1000.c sort before offsets_file.c on every host. The preserved link
# map proves that this order is part of the rejected component's byte identity.
$sourceKeys = @(
    Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.c' | ForEach-Object {
        $key = [IO.Path]::GetRelativePath($sourceRoot, $_.FullName).Replace('\', '/')
        $sourceByRelativePath[$key] = $_
        $key
    }
)
[Array]::Sort($sourceKeys, [StringComparer]::Ordinal)
$sources = @($sourceKeys | ForEach-Object { $sourceByRelativePath[$_] })
foreach ($source in $sources) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $source.FullName)
    $object = Join-Path $objectRoot ([IO.Path]::ChangeExtension($relative, '.o'))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $object) | Out-Null
    $compileArguments = @(
        'cc', '-target', 'x86_64-freebsd', '-I', $includeRoot,
        '-Os', '-std=gnu11', '-fno-builtin', '-nostartfiles', '-nostdlib',
        # Upstream declares -masm=intel, but these sources contain AT&T inline
        # assembly. The preserved Zig-built objects are reproduced without it.
        '-Wall', '-march=btver2', '-mtune=btver2', '-m64',
        '-mabi=sysv', '-mcmodel=small', '-fpie', '-c', $source.FullName, '-o', $object
    )
    & $Zig @compileArguments
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed for ${relative}: $LASTEXITCODE" }
    $objects += $object
}

$elf = Join-Path $outputRoot 'hen-kernel-component.elf'
$linkArguments = @(
    'cc', '-target', 'x86_64-freestanding', '-nostartfiles', '-nostdlib',
    "-Wl,-T,$linker", '-Wl,--build-id=none'
) + $objects + @('-o', $elf)
& $Zig @linkArguments
if ($LASTEXITCODE -ne 0) { throw "ELF link failed: $LASTEXITCODE" }

$withoutBss = Join-Path $outputRoot 'hen-kernel-component.no-bss.elf'
& $Objcopy -R .payload_bss $elf $withoutBss
if ($LASTEXITCODE -ne 0) { throw "payload_bss removal failed: $LASTEXITCODE" }

$binary = Join-Path $outputRoot 'hen-kernel-component.bin'
& $Objcopy -O binary $withoutBss $binary
if ($LASTEXITCODE -ne 0) { throw "Flat extraction failed: $LASTEXITCODE" }

$elfHash = (Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash
$binaryHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
if ($ExpectedELFSHA256 -and $elfHash -ne $ExpectedELFSHA256.ToUpperInvariant()) {
    throw "ELF SHA-256 mismatch: expected $ExpectedELFSHA256, got $elfHash"
}
if ($ExpectedBinarySHA256 -and $binaryHash -ne $ExpectedBinarySHA256.ToUpperInvariant()) {
    throw "Binary SHA-256 mismatch: expected $ExpectedBinarySHA256, got $binaryHash"
}

[pscustomobject]@{
    SourceRevision = (& git -C $henRoot rev-parse HEAD).Trim()
    SourceDirty = [bool](& git -C $henRoot status --short)
    SourceFiles = $sources.Count
    ZigVersion = (& $Zig version).Trim()
    ZigSHA256 = (Get-FileHash -LiteralPath $Zig -Algorithm SHA256).Hash
    ObjcopyVersion = ((& $Objcopy --version | Select-Object -First 1) -join '').Trim()
    ObjcopySHA256 = (Get-FileHash -LiteralPath $Objcopy -Algorithm SHA256).Hash
    LinkerScriptSHA256 = (Get-FileHash -LiteralPath $linker -Algorithm SHA256).Hash
    ELF = $elf
    ELFBytes = (Get-Item -LiteralPath $elf).Length
    ELFSHA256 = $elfHash
    Binary = $binary
    BinaryBytes = (Get-Item -LiteralPath $binary).Length
    BinarySHA256 = $binaryHash
}
