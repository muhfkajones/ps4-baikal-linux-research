# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LogPath,

    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$resolvedLog = (Resolve-Path -LiteralPath $LogPath).Path
$allLines = @(Get-Content -LiteralPath $resolvedLog)
$lines = @($allLines | Where-Object { $_ -match '^\[EXP013-V6\]' })
if ($lines.Count -eq 0) {
    throw 'No EXP013-V6 records were found.'
}

$requiredMarkers = @(
    '[EXP013-V6] 00 entered',
    '[EXP013-V6] 01 initKernel returned',
    '[EXP013-V6] 02 initLibc returned'
)
$validationErrors = [System.Collections.Generic.List[string]]::new()
foreach ($marker in $requiredMarkers) {
    if (@($lines | Where-Object { $_ -eq $marker }).Count -ne 1) {
        $validationErrors.Add("Expected exactly one marker: $marker")
    }
}

$values = @{}
$valuePatterns = [ordered]@{
    uid = '^\[EXP013-V6\] 03 uid=(0x[0-9a-f]{16})$'
    sandbox = '^\[EXP013-V6\] 04 sandbox=(0x[0-9a-f]{16})$'
    enumerationResult = '^\[EXP013-V6\] 05 enumeration_result=(0x[0-9a-f]{16})$'
    moduleCount = '^\[EXP013-V6\] 06 module_count=(0x[0-9a-f]{16})$'
    moduleInfoFailures = '^\[EXP013-V6\] 07 module_info_failures=(0x[0-9a-f]{16})$'
}
foreach ($field in $valuePatterns.Keys) {
    $matches = @($lines | Where-Object { $_ -match $valuePatterns[$field] })
    if ($matches.Count -ne 1) {
        $validationErrors.Add("Expected exactly one $field record.")
        continue
    }
    [void]($matches[0] -match $valuePatterns[$field])
    $values[$field] = $Matches[1]
}

$modules = [System.Collections.Generic.List[object]]::new()
$seenIndexes = [System.Collections.Generic.HashSet[int]]::new()
$failureIds = [System.Collections.Generic.List[string]]::new()
$unexpectedRecords = [System.Collections.Generic.List[string]]::new()
foreach ($line in $lines) {
    if ($line -match '^\[EXP013-V6\] module\[([0-9a-f]{2})\] id=(0x[0-9a-f]{8}) name=(.{1,32})$') {
        $index = [Convert]::ToInt32($Matches[1], 16)
        if (-not $seenIndexes.Add($index)) {
            $validationErrors.Add("Duplicate module index: $index")
        }
        $modules.Add([pscustomobject]@{
            index = $index
            id = $Matches[2]
            name = $Matches[3]
        })
        continue
    }
    if ($line -match '^\[EXP013-V6\] module_info_failed_id=(0x[0-9a-f]{16})$') {
        $failureIds.Add($Matches[1])
        continue
    }
    if ($line -in $requiredMarkers -or
        $line -eq '[EXP013-V6] STOP enumeration failed/truncated' -or
        $line -eq '[EXP013-V6] 08 complete; no kernel reads attempted' -or
        ($valuePatterns.Values | Where-Object { $line -match $_ })) {
        continue
    }
    $unexpectedRecords.Add($line)
}

function Convert-HexToUInt64 {
    param([string]$Value)
    if (-not $Value) { return $null }
    [Convert]::ToUInt64($Value.Substring(2), 16)
}

$enumerationResult = Convert-HexToUInt64 $values.enumerationResult
$moduleCount = Convert-HexToUInt64 $values.moduleCount
$moduleInfoFailures = Convert-HexToUInt64 $values.moduleInfoFailures
$stopSeen = $lines -contains '[EXP013-V6] STOP enumeration failed/truncated'
$completionSeen = $lines -contains '[EXP013-V6] 08 complete; no kernel reads attempted'

if ($null -ne $moduleCount -and $moduleCount -gt 256) {
    $validationErrors.Add("Module count exceeds the 256-entry bound: $moduleCount")
}
if ($null -ne $moduleInfoFailures -and $moduleInfoFailures -ne $failureIds.Count) {
    $validationErrors.Add("Declared module-info failures ($moduleInfoFailures) do not match failure records ($($failureIds.Count)).")
}
if ($null -ne $moduleCount -and ($modules.Count + $failureIds.Count) -ne $moduleCount) {
    $validationErrors.Add("Successful and failed module records do not equal declared module count $moduleCount.")
}

$complete = $enumerationResult -eq 0 -and -not $stopSeen -and $completionSeen -and
    $unexpectedRecords.Count -eq 0 -and $validationErrors.Count -eq 0
$names = @($modules | ForEach-Object { $_.name })
$result = [ordered]@{
    schemaVersion = 1
    sourceLineCount = $allLines.Count
    exp013RecordCount = $lines.Count
    uid = $values.uid
    sandbox = $values.sandbox
    enumerationResult = $values.enumerationResult
    moduleCount = $moduleCount
    moduleInfoFailures = $moduleInfoFailures
    completionMarkerSeen = $completionSeen
    stopMarkerSeen = $stopSeen
    complete = $complete
    pluginBootloaderVisible = @($names | Where-Object { $_ -match 'plugin_bootloader' }).Count -gt 0
    pluginLoaderVisible = @($names | Where-Object { $_ -match 'plugin_loader' }).Count -gt 0
    unexpectedRecords = @($unexpectedRecords)
    validationErrors = @($validationErrors)
    failedModuleIds = @($failureIds)
    modules = @($modules)
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
