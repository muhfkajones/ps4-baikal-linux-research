# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LogPath,
    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { throw "Log not found: $LogPath" }
$lines = @(Get-Content -LiteralPath $LogPath | Where-Object { $_ -like '[[]EXP013-V7[]]*' })
if ($lines.Count -eq 0) { throw 'No EXP013-V7 records found.' }
if (@($lines | Where-Object { $_ -match '^\[EXP013-V7\] STOP' }).Count) { throw 'Payload reported a STOP condition.' }

$required = [ordered]@{
    Capture = '^\[EXP013-V7\] 00 capture connected$'
    UID = '^\[EXP013-V7\] 01 uid=0x[0-9a-f]{16}$'
    Sandbox = '^\[EXP013-V7\] 02 sandbox=0x[0-9a-f]{16}$'
    Enumeration = '^\[EXP013-V7\] 03 enumeration_result=0x0000000000000000$'
    Count = '^\[EXP013-V7\] 04 module_count=0x(?<count>[0-9a-f]{16})$'
    Failures = '^\[EXP013-V7\] 05 module_info_failures=0x(?<failures>[0-9a-f]{16})$'
    Complete = '^\[EXP013-V7\] 06 complete; no kernel reads or file writes attempted$'
}
$records = @{}
foreach ($entry in $required.GetEnumerator()) {
    $found = @($lines | Where-Object { $_ -match $entry.Value })
    if ($found.Count -ne 1) { throw "Expected exactly one $($entry.Key) record; found $($found.Count)." }
    $records[$entry.Key] = $found[0]
}

$countMatch = [regex]::Match($records['Count'], $required['Count'])
$failureMatch = [regex]::Match($records['Failures'], $required['Failures'])
$moduleCount = [Convert]::ToUInt64($countMatch.Groups['count'].Value, 16)
$failureCount = [Convert]::ToUInt64($failureMatch.Groups['failures'].Value, 16)
if ($moduleCount -gt 256) { throw "Module count exceeds the 256-entry bound: $moduleCount" }

$modulePattern = '^\[EXP013-V7\] module\[(?<index>[0-9a-f]{2})\] id=0x(?<id>[0-9a-f]{8}) name=(?<name>[ -~]+)$'
$failurePattern = '^\[EXP013-V7\] module_info_failed_id=0x[0-9a-f]{16}$'
$modules = @($lines | Where-Object { $_ -match $modulePattern })
$failed = @($lines | Where-Object { $_ -match $failurePattern })
if (($modules.Count + $failed.Count) -ne $moduleCount) { throw 'Module records do not equal the declared module count.' }
if ($failed.Count -ne $failureCount) { throw 'Failure records do not equal the declared failure count.' }

$allowed = @($required.Values) + @($modulePattern, $failurePattern)
$unknown = @($lines | Where-Object { $line = $_; -not @($allowed | Where-Object { $line -match $_ }).Count })
if ($unknown.Count) { throw "Unknown EXP013-V7 record: $($unknown[0])" }

$result = [ordered]@{
    complete = $true
    moduleCount = [int]$moduleCount
    moduleInfoFailures = [int]$failureCount
    modulesObserved = $modules.Count
    sourceSHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $LogPath).Hash
}
$json = $result | ConvertTo-Json
if ($OutputJson) {
    if (Test-Path -LiteralPath $OutputJson) { throw "Refusing to overwrite existing output: $OutputJson" }
    [IO.File]::WriteAllText($OutputJson, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
$json
