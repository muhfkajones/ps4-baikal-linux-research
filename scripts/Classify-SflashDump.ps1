# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Candidate,

    [string]$RawReference,

    [string]$WholeCryptReference,

    [string]$OutputJson
)

$ErrorActionPreference = 'Stop'
$systemSliceOffset = 0x00200000L
$sampleSize = 0x00010000
$compareBlockSize = 0x00010000

function Resolve-InputFile {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label not found: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-FileRecord {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    [ordered]@{
        name = $item.Name
        bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Read-Window {
    param(
        [System.IO.FileStream]$Stream,
        [long]$Offset,
        [int]$Length
    )
    if ($Offset -lt 0 -or $Offset -ge $Stream.Length) {
        return [byte[]]::new(0)
    }
    $available = [Math]::Min([long]$Length, $Stream.Length - $Offset)
    $buffer = [byte[]]::new([int]$available)
    $Stream.Position = $Offset
    $done = 0
    while ($done -lt $buffer.Length) {
        $read = $Stream.Read($buffer, $done, $buffer.Length - $done)
        if ($read -le 0) { throw "Short read at offset 0x$($Offset.ToString('X'))" }
        $done += $read
    }
    return $buffer
}

function Get-WindowStatistics {
    param([byte[]]$Bytes, [long]$Offset)
    $counts = [long[]]::new(256)
    $printable = 0L
    foreach ($value in $Bytes) {
        $counts[$value]++
        if ($value -ge 0x20 -and $value -le 0x7e) { $printable++ }
    }
    $entropy = 0.0
    if ($Bytes.Length -gt 0) {
        foreach ($count in $counts) {
            if ($count -eq 0) { continue }
            $probability = $count / [double]$Bytes.Length
            $entropy -= $probability * [Math]::Log($probability, 2)
        }
    }
    [ordered]@{
        offset = ('0x{0:X8}' -f $Offset)
        bytes = $Bytes.Length
        entropy_bits_per_byte = [Math]::Round($entropy, 6)
        zero_fraction = if ($Bytes.Length) {
            [Math]::Round($counts[0] / [double]$Bytes.Length, 6)
        } else { 0.0 }
        printable_fraction = if ($Bytes.Length) {
            [Math]::Round($printable / [double]$Bytes.Length, 6)
        } else { 0.0 }
    }
}

function Test-BytesAtOffset {
    param(
        [System.IO.FileStream]$Stream,
        [long]$Offset,
        [byte[]]$Expected
    )
    $actual = Read-Window -Stream $Stream -Offset $Offset -Length $Expected.Length
    if ($actual.Length -ne $Expected.Length) { return $false }
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        if ($actual[$index] -ne $Expected[$index]) { return $false }
    }
    return $true
}

function Get-Probes {
    param([string]$Path)
    $ascii = [Text.Encoding]::ASCII
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $probes = [ordered]@{
            sony_header_at_0 = Test-BytesAtOffset $stream 0L ($ascii.GetBytes('SONY COMPUTER ENTERTAINMENT INC.'))
            slb2_at_0 = Test-BytesAtOffset $stream 0L ($ascii.GetBytes('SLB2'))
            slb2_at_0x4000 = Test-BytesAtOffset $stream 0x00004000L ($ascii.GetBytes('SLB2'))
            elf_at_0 = Test-BytesAtOffset $stream 0L ([byte[]](0x7f, 0x45, 0x4c, 0x46))
        }

        $offsets = [System.Collections.Generic.SortedSet[long]]::new()
        foreach ($offset in @(0L,
                [long]($stream.Length / 4),
                [long]($stream.Length / 2),
                [long](($stream.Length * 3) / 4),
                [Math]::Max(0L, $stream.Length - $sampleSize))) {
            [void]$offsets.Add($offset)
        }
        $samples = foreach ($offset in $offsets) {
            Get-WindowStatistics (Read-Window $stream $offset $sampleSize) $offset
        }
        return [ordered]@{ markers = $probes; samples = @($samples) }
    }
    finally {
        $stream.Dispose()
    }
}

function Compare-ByBlock {
    param(
        [string]$CandidatePath,
        [string]$ReferencePath,
        [long]$ReferenceOffset,
        [string]$Label
    )
    $candidateStream = [IO.File]::Open($CandidatePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $referenceStream = [IO.File]::Open($ReferencePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $available = [Math]::Max(0L, $referenceStream.Length - $ReferenceOffset)
        $compareLength = [Math]::Min($candidateStream.Length, $available)
        $candidateBuffer = [byte[]]::new($compareBlockSize)
        $referenceBuffer = [byte[]]::new($compareBlockSize)
        $referenceStream.Position = $ReferenceOffset
        $position = 0L
        $matchingBlocks = 0L
        $differentBlocks = 0L
        $firstDifference = $null

        while ($position -lt $compareLength) {
            $amount = [int][Math]::Min([long]$compareBlockSize, $compareLength - $position)
            $candidateRead = $candidateStream.Read($candidateBuffer, 0, $amount)
            $referenceRead = $referenceStream.Read($referenceBuffer, 0, $amount)
            if ($candidateRead -ne $amount -or $referenceRead -ne $amount) {
                throw "Short read during $Label comparison at 0x$($position.ToString('X'))"
            }

            $candidateHash = $sha.ComputeHash($candidateBuffer, 0, $amount)
            $referenceHash = $sha.ComputeHash($referenceBuffer, 0, $amount)
            $equal = [Security.Cryptography.CryptographicOperations]::FixedTimeEquals(
                $candidateHash, $referenceHash)
            if ($equal) {
                $matchingBlocks++
            } else {
                $differentBlocks++
                if ($null -eq $firstDifference) {
                    for ($index = 0; $index -lt $amount; $index++) {
                        if ($candidateBuffer[$index] -ne $referenceBuffer[$index]) {
                            $firstDifference = $position + $index
                            break
                        }
                    }
                }
            }
            $position += $amount
        }

        $sameLength = $candidateStream.Length -eq $available
        [ordered]@{
            label = $Label
            reference_name = (Split-Path -Leaf $ReferencePath)
            reference_sha256 = (Get-FileHash -LiteralPath $ReferencePath -Algorithm SHA256).Hash
            reference_offset = ('0x{0:X8}' -f $ReferenceOffset)
            compared_bytes = $compareLength
            block_bytes = $compareBlockSize
            matching_blocks = $matchingBlocks
            different_blocks = $differentBlocks
            first_difference = if ($null -eq $firstDifference) { $null } else {
                '0x{0:X8}' -f $firstDifference
            }
            candidate_matches_entire_reference_view = (
                $sameLength -and $differentBlocks -eq 0 -and $compareLength -eq $candidateStream.Length)
        }
    }
    finally {
        $sha.Dispose()
        $referenceStream.Dispose()
        $candidateStream.Dispose()
    }
}

function Get-ReferenceOffset {
    param([long]$CandidateLength, [long]$ReferenceLength)
    if ($CandidateLength -eq ($ReferenceLength - $systemSliceOffset)) {
        return $systemSliceOffset
    }
    return 0L
}

$candidatePath = Resolve-InputFile $Candidate 'Candidate'
$rawPath = Resolve-InputFile $RawReference 'Raw reference'
$wholeCryptPath = Resolve-InputFile $WholeCryptReference 'Whole-crypt reference'
$candidateRecord = Get-FileRecord $candidatePath
$probeResult = Get-Probes $candidatePath
$comparisons = [System.Collections.Generic.List[object]]::new()

if ($rawPath) {
    $rawLength = (Get-Item -LiteralPath $rawPath).Length
    $offset = Get-ReferenceOffset $candidateRecord.bytes $rawLength
    $comparisons.Add((Compare-ByBlock $candidatePath $rawPath $offset 'raw-sflash-view'))
}
if ($wholeCryptPath) {
    $cryptLength = (Get-Item -LiteralPath $wholeCryptPath).Length
    $offset = Get-ReferenceOffset $candidateRecord.bytes $cryptLength
    $comparisons.Add((Compare-ByBlock $candidatePath $wholeCryptPath $offset 'whole-crypt-view'))
}

$meanEntropy = 0.0
if ($probeResult.samples.Count) {
    $entropyTotal = 0.0
    foreach ($sample in $probeResult.samples) {
        $entropyTotal += [double]$sample['entropy_bits_per_byte']
    }
    $meanEntropy = $entropyTotal / $probeResult.samples.Count
}
$rawMatch = $comparisons | Where-Object {
    $_.label -eq 'raw-sflash-view' -and $_.candidate_matches_entire_reference_view
} | Select-Object -First 1
$cryptMatch = $comparisons | Where-Object {
    $_.label -eq 'whole-crypt-view' -and $_.candidate_matches_entire_reference_view
} | Select-Object -First 1

$classification = if ($rawMatch) {
    'identical-to-raw-reference-view'
} elseif ($cryptMatch) {
    'identical-to-whole-crypt-reference-view'
} elseif ($probeResult.markers.sony_header_at_0 -or $probeResult.markers.slb2_at_0) {
    'structured-plaintext-candidate'
} elseif ($meanEntropy -ge 7.90) {
    'high-entropy-or-encrypted-candidate'
} else {
    'unclassified-candidate'
}

$completeMarker = Join-Path (Split-Path -Parent $candidatePath) 'sflash0s1.crypt.complete'
$report = [ordered]@{
    schema = 'ps4-baikal-sflash-classification-v1'
    candidate = $candidateRecord
    acquisition = [ordered]@{
        complete_marker_present = (Test-Path -LiteralPath $completeMarker -PathType Leaf)
        chunk_aligned_16k = (($candidateRecord.bytes % 0x4000) -eq 0)
    }
    probes = $probeResult
    comparisons = @($comparisons)
    mean_sample_entropy_bits_per_byte = [Math]::Round($meanEntropy, 6)
    classification = $classification
}

$json = $report | ConvertTo-Json -Depth 8
if ($OutputJson) {
    $outputPath = [IO.Path]::GetFullPath($OutputJson)
    $parent = Split-Path -Parent $outputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($outputPath, $json + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))
    Write-Output "REPORT=$outputPath"
}
$json
