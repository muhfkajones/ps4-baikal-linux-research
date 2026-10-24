# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LogPath,

    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$expectedHeader = 'PS4 13.50 read-only SFLASH provider inventory v1'
$expectedDevices = @(
    '/dev/sflash0s1',
    '/dev/sflash0s1.crypt',
    '/dev/sflash0s1.cryptx1',
    '/dev/sflash0s1.cryptx2',
    '/dev/sflash0s1.cryptx3',
    '/dev/sflash0s1.cryptx2b',
    '/dev/sflash0s1.cryptx3b',
    '/dev/sflash0s1.cryptx39',
    '/dev/sflash0s1.cryptx40'
)
$knownFields = @(
    'open_fd', 'media_ioctl', 'media_size', 'sector_ioctl', 'sector_size',
    'sample_read', 'sample_fnv1a64', 'marker_sony', 'marker_slb2',
    'marker_elf', 'marker_mbr55aa'
)

$resolvedLog = (Resolve-Path -LiteralPath $LogPath).Path
$lines = @(Get-Content -LiteralPath $resolvedLog)
if ($lines.Count -eq 0) {
    throw 'Inventory log is empty.'
}

$records = [System.Collections.Generic.List[object]]::new()
$seenDevices = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$unexpectedLines = [System.Collections.Generic.List[string]]::new()
$current = $null
$firmwareHex = $null
$passSeen = $false

foreach ($line in $lines) {
    if ($line -eq $expectedHeader -or
        $line -in @('01 initKernel ok', '02 initLibc ok', '03 initPthread ok',
                    '05 jailbreak skipped') -or
        $line -match '^04 is_jailbroken=0x[0-9a-f]{16}$' -or
        $line -match '^05 jailbreak_result=0x[0-9a-f]{16}$') {
        continue
    }
    if ($line -match '^06 firmware=(0x[0-9a-f]{16})$') {
        $firmwareHex = $Matches[1]
        continue
    }
    if ($line -match '^DEVICE (/.+)$') {
        if ($null -ne $current) {
            $records.Add([pscustomobject]$current)
        }
        $device = $Matches[1]
        if (-not $seenDevices.Add($device)) {
            throw "Duplicate provider record: $device"
        }
        $current = [ordered]@{ device = $device }
        continue
    }
    if ($line -match '^ ([a-z0-9_]+)=(0x[0-9a-f]{16})$') {
        if ($null -eq $current) {
            throw "Provider field appeared before a DEVICE line: $line"
        }
        $field = $Matches[1]
        if ($field -notin $knownFields) {
            throw "Unknown provider field: $field"
        }
        if ($current.Contains($field)) {
            throw "Duplicate field '$field' for $($current.device)"
        }
        $current[$field] = $Matches[2]
        continue
    }
    if ($line -match '^ result=([a-z0-9-]+)$') {
        if ($null -eq $current) {
            throw "Provider result appeared before a DEVICE line: $line"
        }
        if ($current.Contains('result')) {
            throw "Duplicate result for $($current.device)"
        }
        $current.result = $Matches[1]
        continue
    }
    if ($line -eq 'PASS provider inventory complete') {
        $passSeen = $true
        continue
    }
    if ($line.Length -gt 0) {
        $unexpectedLines.Add($line)
    }
}

if ($null -ne $current) {
    $records.Add([pscustomobject]$current)
}

$actualDevices = @($records | ForEach-Object { $_.device })
$missingDevices = @($expectedDevices | Where-Object { $_ -notin $actualDevices })
$extraDevices = @($actualDevices | Where-Object { $_ -notin $expectedDevices })
$validationErrors = [System.Collections.Generic.List[string]]::new()
foreach ($record in $records) {
    if ($record.PSObject.Properties.Name -notcontains 'open_fd') {
        $validationErrors.Add("$($record.device): missing open_fd")
    }
    if ($record.PSObject.Properties.Name -notcontains 'result') {
        $validationErrors.Add("$($record.device): missing result")
        continue
    }
    $requiredForResult = switch ($record.result) {
        'unavailable' { @('open_fd') }
        'invalid-geometry-no-read' {
            @('open_fd', 'media_ioctl', 'media_size', 'sector_ioctl', 'sector_size')
        }
        'sample-read-failed' {
            @('open_fd', 'media_ioctl', 'media_size', 'sector_ioctl', 'sector_size', 'sample_read')
        }
        'read-only-probe-complete' { $knownFields }
        default {
            $validationErrors.Add("$($record.device): unknown result '$($record.result)'")
            @()
        }
    }
    foreach ($requiredField in $requiredForResult) {
        if ($record.PSObject.Properties.Name -notcontains $requiredField) {
            $validationErrors.Add("$($record.device): result '$($record.result)' is missing $requiredField")
        }
    }
}
$firmwareSupported = $firmwareHex -eq '0x0000000000000546'
$headerValid = $lines[0] -eq $expectedHeader
$complete = $headerValid -and $passSeen -and $firmwareSupported -and
    $missingDevices.Count -eq 0 -and $extraDevices.Count -eq 0 -and
    $unexpectedLines.Count -eq 0 -and $validationErrors.Count -eq 0

$result = [ordered]@{
    schemaVersion = 1
    headerValid = $headerValid
    firmwareHex = $firmwareHex
    firmwareSupported = $firmwareSupported
    completionMarkerSeen = $passSeen
    complete = $complete
    providerCount = $records.Count
    missingDevices = $missingDevices
    extraDevices = $extraDevices
    unexpectedLines = @($unexpectedLines)
    validationErrors = @($validationErrors)
    providers = @($records)
}

$json = $result | ConvertTo-Json -Depth 6
if ($OutputJson) {
    $parent = Split-Path -Parent $OutputJson
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $OutputJson -Value $json -Encoding utf8
}
$json
