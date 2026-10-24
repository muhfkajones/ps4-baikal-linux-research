# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ExtractedDirectory,

    [Parameter(Mandatory)]
    [string]$UsbRoot
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath $ExtractedDirectory).Path
$usb = (Resolve-Path -LiteralPath $UsbRoot).Path
$destinationRoot = Join-Path $usb 'ps4-re-input'

$items = @(
    @{ Source = '001c0000--80010001.bin'; Destination = 'bank-a-80010001.self'; SHA256 = '9B8E7BC0E2561921D8A2D749461F3B4C31B4F9427B31A38943A487BDD94F4C45' },
    @{ Source = '00e80000--80010001.bin'; Destination = 'bank-b-80010001.self'; SHA256 = '4C5ABD62B6FECBBB58C7984C592A5E1D15058439A3240F4A35DCD883E2385D4F' },
    @{ Source = '001c0000--80010008.bin'; Destination = 'bank-a-80010008.self'; SHA256 = 'DF2DAC6E1E9A08F8C771FA9E585D8C8720D2299BB9DFEF0A763FB3DCEF32E5CB' },
    @{ Source = '00e80000--80010008.bin'; Destination = 'bank-b-80010008.self'; SHA256 = 'E40CC5F1BEA09D823B1AFB2E40CB59EDBB2B9EAA0639DEF10C80D6224A76285A' }
)

New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
$results = foreach ($item in $items) {
    $source = Join-Path $sourceRoot $item.Source
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required private input not found: $source"
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash
    if ($actual -ne $item.SHA256) {
        throw "Hash mismatch for $($item.Source): expected $($item.SHA256), got $actual"
    }

    $destination = Join-Path $destinationRoot $item.Destination
    if (Test-Path -LiteralPath $destination) {
        $existing = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash
        if ($existing -ne $item.SHA256) {
            throw "Refusing to overwrite different file: $destination"
        }
        $state = 'already-present'
    } else {
        Copy-Item -LiteralPath $source -Destination $destination
        $copied = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash
        if ($copied -ne $item.SHA256) {
            throw "Post-copy hash mismatch: $destination"
        }
        $state = 'copied-and-verified'
    }

    [pscustomobject]@{
        File = $item.Destination
        SHA256 = $item.SHA256
        State = $state
    }
}

$results
