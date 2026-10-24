# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Image,

    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$resolvedImage = (Resolve-Path -LiteralPath $Image).Path
$imageBytes = [IO.File]::ReadAllBytes($resolvedImage)
$magic = [byte[]](0x53, 0x4c, 0x42, 0x32)

function Get-Sha256Hex {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [Convert]::ToHexString($sha.ComputeHash($Bytes)) }
    finally { $sha.Dispose() }
}

function Find-MagicOffsets {
    param([byte[]]$Bytes, [byte[]]$Pattern)
    $found = [System.Collections.Generic.List[long]]::new()
    for ($index = 0; $index -le $Bytes.Length - $Pattern.Length; $index++) {
        if ($Bytes[$index] -ne $Pattern[0]) { continue }
        $match = $true
        for ($part = 1; $part -lt $Pattern.Length; $part++) {
            if ($Bytes[$index + $part] -ne $Pattern[$part]) {
                $match = $false
                break
            }
        }
        if ($match) { $found.Add($index) }
    }
    $found
}

$containers = [System.Collections.Generic.List[object]]::new()
foreach ($containerOffset in (Find-MagicOffsets $imageBytes $magic)) {
    if ($containerOffset + 0x20 -gt $imageBytes.LongLength) {
        continue
    }
    $entryCount = [BitConverter]::ToUInt32($imageBytes, [int]($containerOffset + 12))
    if ($entryCount -gt 64 -or $containerOffset + 0x20 + ($entryCount * 0x30) -gt $imageBytes.LongLength) {
        continue
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $valid = $true
    for ($entryIndex = 0; $entryIndex -lt $entryCount; $entryIndex++) {
        $entryOffset = [int]($containerOffset + 0x20 + ($entryIndex * 0x30))
        $startSector = [BitConverter]::ToUInt32($imageBytes, $entryOffset)
        $byteCount = [BitConverter]::ToUInt32($imageBytes, $entryOffset + 4)
        $name = [Text.Encoding]::ASCII.GetString($imageBytes, $entryOffset + 16, 32).Trim([char]0)
        $relativeOffset = [long]$startSector * 0x200
        $absoluteOffset = $containerOffset + $relativeOffset
        if ($name -notmatch '^[A-Za-z0-9._-]+$' -or
            $relativeOffset -lt 0x200 -or $byteCount -eq 0 -or
            $absoluteOffset + $byteCount -gt $imageBytes.LongLength) {
            $valid = $false
            break
        }
        $entryBytes = [byte[]]::new($byteCount)
        [Array]::Copy($imageBytes, $absoluteOffset, $entryBytes, 0, $byteCount)
        $entries.Add([ordered]@{
            name = $name
            startSectorHex = ('0x{0:x}' -f $startSector)
            relativeOffsetHex = ('0x{0:x8}' -f $relativeOffset)
            absoluteOffsetHex = ('0x{0:x8}' -f $absoluteOffset)
            bytes = $byteCount
            sha256 = (Get-Sha256Hex $entryBytes)
        })
    }
    if ($valid) {
        $containers.Add([ordered]@{
            offsetHex = ('0x{0:x8}' -f $containerOffset)
            entryCount = $entryCount
            entries = @($entries)
        })
    }
}

$result = [ordered]@{
    schema = 'ps4-baikal-slb2-inventory-v1'
    image = [ordered]@{
        name = [IO.Path]::GetFileName($resolvedImage)
        bytes = $imageBytes.LongLength
        sha256 = (Get-Sha256Hex $imageBytes)
    }
    containerCount = $containers.Count
    containers = @($containers)
}

$json = $result | ConvertTo-Json -Depth 8
if ($OutputJson) {
    $parent = Split-Path -Parent $OutputJson
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $OutputJson -Value $json -Encoding utf8
}
$json
