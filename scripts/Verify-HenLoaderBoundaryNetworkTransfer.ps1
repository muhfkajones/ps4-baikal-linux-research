# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Local,
    [Parameter(Mandatory)][string]$Retrieved
)

$ErrorActionPreference = 'Stop'
$expectedBytes = 7044
$expectedHash = '8270D9C6470E27A51AF2FC37C5B84F7775C14D5D3988A4051BB9AB64B01CCA70'
$results = foreach ($path in @($Local, $Retrieved)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "File not found: $path" }
    $item = Get-Item -LiteralPath $path
    [pscustomobject]@{
        Path = $item.FullName
        Bytes = $item.Length
        SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    }
}
foreach ($result in $results) {
    if ($result.Bytes -ne $expectedBytes -or $result.SHA256 -ne $expectedHash) {
        throw "Transfer verification failed for $($result.Path)."
    }
}
[pscustomobject]@{
    Verified = $true
    Bytes = $expectedBytes
    SHA256 = $expectedHash
    LocalPath = $results[0].Path
    RetrievedPath = $results[1].Path
}
