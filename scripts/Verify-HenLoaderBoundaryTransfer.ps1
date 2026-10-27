# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Local,

    [Parameter(Mandatory)]
    [string]$Retrieved
)

$ErrorActionPreference = 'Stop'
$expectedBytes = 5760
$expectedSha256 = 'ADA2FB9F75DAD721BDD4979D9F30BBCD234B4F752A65FD71D4D33F044BEDB2E8'

function Get-VerifiedArtifact {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file not found: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    if ($item.Length -ne $expectedBytes) {
        throw "$Label length mismatch: expected $expectedBytes, got $($item.Length)"
    }
    if ($hash -ne $expectedSha256) {
        throw "$Label SHA-256 mismatch: expected $expectedSha256, got $hash"
    }

    [pscustomobject]@{
        Label = $Label
        Bytes = $item.Length
        SHA256 = $hash
        Path = $item.FullName
    }
}

$localResult = Get-VerifiedArtifact -Label 'Local build' -Path $Local
$retrievedResult = Get-VerifiedArtifact -Label 'Retrieved copy' -Path $Retrieved

if ((Get-FileHash -Algorithm SHA256 -LiteralPath $localResult.Path).Hash -ne
    (Get-FileHash -Algorithm SHA256 -LiteralPath $retrievedResult.Path).Hash) {
    throw 'Local and retrieved payload hashes differ.'
}

$localResult
$retrievedResult
[pscustomobject]@{
    TransferVerified = $true
    ExpectedBytes = $expectedBytes
    ExpectedSHA256 = $expectedSha256
}
