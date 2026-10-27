# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Address,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [ValidateRange(1, 65535)]
    [int]$Port = 3232,

    [ValidateRange(1, 60)]
    [int]$ConnectTimeoutSeconds = 5,

    [ValidateRange(5, 600)]
    [int]$CaptureTimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
$completionMarker = '[EXP013-V6] 08 complete; no kernel reads attempted'
$stopMarker = '[EXP013-V6] STOP enumeration failed/truncated'
$parent = Split-Path -Parent $OutputPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

$client = [System.Net.Sockets.TcpClient]::new()
$stream = $null
$file = $null
try {
    $connectTask = $client.ConnectAsync($Address, $Port)
    if (-not $connectTask.Wait([TimeSpan]::FromSeconds($ConnectTimeoutSeconds))) {
        throw "Timed out connecting to the PS4 klog service at ${Address}:$Port. Do not launch EXP-013 without a working capture channel."
    }
    if ($connectTask.IsFaulted) {
        throw $connectTask.Exception.GetBaseException()
    }

    $stream = $client.GetStream()
    $stream.ReadTimeout = 1000
    $file = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $buffer = [byte[]]::new(8192)
    $text = [System.Text.StringBuilder]::new()
    $deadline = [DateTime]::UtcNow.AddSeconds($CaptureTimeoutSeconds)
    $terminalMarker = $null

    while ([DateTime]::UtcNow -lt $deadline) {
        try {
            $count = $stream.Read($buffer, 0, $buffer.Length)
        }
        catch [System.IO.IOException] {
            continue
        }
        if ($count -eq 0) {
            break
        }

        $file.Write($buffer, 0, $count)
        $file.Flush()
        [void]$text.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $count))
        if ($text.ToString().Contains($completionMarker)) {
            $terminalMarker = 'complete'
            break
        }
        if ($text.ToString().Contains($stopMarker)) {
            $terminalMarker = 'stopped'
            break
        }
        if ($text.Length -gt 1048576) {
            [void]$text.Remove(0, $text.Length - 65536)
        }
    }

    if (-not $terminalMarker) {
        throw "Capture ended without an EXP013-V6 terminal marker. Raw evidence was preserved at $OutputPath."
    }

    $file.Flush()
    $file.Dispose()
    $file = $null
    $item = Get-Item -LiteralPath $OutputPath
    [pscustomobject]@{
        Address = $Address
        Port = $Port
        OutputPath = $item.FullName
        Bytes = $item.Length
        SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash
        TerminalMarker = $terminalMarker
    }
}
finally {
    if ($file) { $file.Dispose() }
    if ($stream) { $stream.Dispose() }
    $client.Dispose()
}
