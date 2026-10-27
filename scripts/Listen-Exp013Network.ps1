# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputPath,
    [ValidateRange(1, 65535)][int]$Port = 9023,
    [ValidateRange(1, 300)][int]$AcceptTimeoutSeconds = 120,
    [ValidateRange(1, 120)][int]$ReadTimeoutSeconds = 15,
    [ValidateRange(1024, 1048576)][int]$MaximumBytes = 262144
)

$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) {
    throw "Refusing to overwrite existing capture: $OutputPath"
}

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $Port)
$client = $null
$stream = $null
$file = $null
$completeMarker = [Text.Encoding]::ASCII.GetBytes('[EXP013-V7] 06 complete; no kernel reads or file writes attempted')
$stopMarker = [Text.Encoding]::ASCII.GetBytes('[EXP013-V7] STOP')
$tail = [byte[]]::new(256)
$tailLength = 0
$received = 0
$terminal = $false

try {
    $listener.Start(1)
    $accept = $listener.AcceptTcpClientAsync()
    if (-not $accept.Wait([TimeSpan]::FromSeconds($AcceptTimeoutSeconds))) {
        throw "No EXP-013 connection arrived on TCP $Port within $AcceptTimeoutSeconds seconds."
    }
    $client = $accept.Result
    $client.ReceiveTimeout = $ReadTimeoutSeconds * 1000
    $stream = $client.GetStream()
    $file = [IO.File]::Open($OutputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $buffer = [byte[]]::new(4096)

    while (-not $terminal) {
        try { $count = $stream.Read($buffer, 0, $buffer.Length) }
        catch [IO.IOException] { throw "EXP-013 capture stalled for $ReadTimeoutSeconds seconds before a terminal marker." }
        if ($count -eq 0) { break }
        $received += $count
        if ($received -gt $MaximumBytes) { throw "EXP-013 capture exceeded the $MaximumBytes-byte safety bound." }
        $file.Write($buffer, 0, $count)
        $file.Flush()

        $combined = [byte[]]::new($tailLength + $count)
        if ($tailLength) { [Array]::Copy($tail, 0, $combined, 0, $tailLength) }
        [Array]::Copy($buffer, 0, $combined, $tailLength, $count)
        $text = [Text.Encoding]::ASCII.GetString($combined)
        $terminal = $text.Contains([Text.Encoding]::ASCII.GetString($completeMarker)) -or
            $text.Contains([Text.Encoding]::ASCII.GetString($stopMarker))
        $tailLength = [Math]::Min($tail.Length, $combined.Length)
        [Array]::Copy($combined, $combined.Length - $tailLength, $tail, 0, $tailLength)
    }
}
finally {
    if ($file) { $file.Dispose() }
    if ($stream) { $stream.Dispose() }
    if ($client) { $client.Dispose() }
    $listener.Stop()
}

if (-not $terminal) { throw 'EXP-013 connection closed before a terminal marker.' }
$item = Get-Item -LiteralPath $OutputPath
[pscustomobject]@{
    Path = $item.FullName
    Bytes = $item.Length
    SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $OutputPath).Hash
    TerminalMarkerObserved = $true
}
