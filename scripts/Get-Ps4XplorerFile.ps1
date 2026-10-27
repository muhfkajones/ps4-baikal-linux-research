# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Address,

    [ValidateRange(1, 65535)]
    [int]$Port = 2121,

    [Parameter(Mandatory)]
    [string]$RemotePath,

    [Parameter(Mandatory)]
    [ValidateRange(1, 1073741824)]
    [long]$ExpectedBytes,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$parent = Split-Path -Parent $OutputPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
if (Test-Path -LiteralPath $OutputPath) {
    throw "Output path already exists: $OutputPath"
}

function Read-FtpReply {
    param([Parameter(Mandatory)][IO.StreamReader]$Reader)

    $first = $Reader.ReadLine()
    if ($null -eq $first) { throw 'FTP control connection closed unexpectedly.' }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add($first)
    if ($first -match '^(\d{3})-') {
        $code = $Matches[1]
        do {
            $line = $Reader.ReadLine()
            if ($null -eq $line) { throw 'FTP multiline reply ended unexpectedly.' }
            $lines.Add($line)
        } while ($line -notmatch "^$code ")
    }
    [pscustomobject]@{
        Code = [int]$lines[0].Substring(0, 3)
        Text = $lines -join ' | '
    }
}

function Send-FtpCommand {
    param(
        [Parameter(Mandatory)][IO.StreamWriter]$Writer,
        [Parameter(Mandatory)][IO.StreamReader]$Reader,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][int[]]$ExpectedCodes
    )

    $Writer.WriteLine($Command)
    $reply = Read-FtpReply -Reader $Reader
    if ($reply.Code -notin $ExpectedCodes) {
        throw "FTP command '$($Command.Split(' ')[0])' failed: $($reply.Text)"
    }
    $reply
}

$control = [Net.Sockets.TcpClient]::new()
$controlStream = $null
$reader = $null
$writer = $null
$output = $null
try {
    $control.Connect($Address, $Port)
    $controlStream = $control.GetStream()
    $controlStream.ReadTimeout = 10000
    $reader = [IO.StreamReader]::new($controlStream, [Text.Encoding]::ASCII, $false, 1024, $true)
    $writer = [IO.StreamWriter]::new($controlStream, [Text.Encoding]::ASCII, 1024, $true)
    $writer.NewLine = "`r`n"
    $writer.AutoFlush = $true

    $banner = Read-FtpReply -Reader $reader
    if ($banner.Code -ne 220) { throw "Unexpected FTP banner: $($banner.Text)" }
    [void](Send-FtpCommand -Writer $writer -Reader $reader -Command 'USER anonymous' -ExpectedCodes 230)
    [void](Send-FtpCommand -Writer $writer -Reader $reader -Command 'TYPE I' -ExpectedCodes 200)

    $output = [IO.File]::Open($OutputPath, [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write, [IO.FileShare]::Read)
    $offset = 0L
    while ($offset -lt $ExpectedBytes) {
        $pasv = Send-FtpCommand -Writer $writer -Reader $reader -Command 'PASV' -ExpectedCodes 227
        if ($pasv.Text -notmatch '\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)') {
            throw "Could not parse PASV reply: $($pasv.Text)"
        }
        $dataAddress = "$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
        $dataPort = ([int]$Matches[5] * 256) + [int]$Matches[6]
        [void](Send-FtpCommand -Writer $writer -Reader $reader -Command "REST $offset" -ExpectedCodes 350)

        $dataClient = [Net.Sockets.TcpClient]::new()
        try {
            $dataClient.Connect($dataAddress, $dataPort)
            $writer.WriteLine("RETR $RemotePath")
            $startReply = Read-FtpReply -Reader $reader
            if ($startReply.Code -notin 125, 150) {
                throw "FTP RETR failed: $($startReply.Text)"
            }
            $dataStream = $dataClient.GetStream()
            try {
                $buffer = [byte[]]::new(65536)
                $received = 0L
                while (($count = $dataStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $remaining = $ExpectedBytes - $offset - $received
                    if ($count -gt $remaining) {
                        throw 'FTP server returned more bytes than the declared file length.'
                    }
                    $output.Write($buffer, 0, $count)
                    $received += $count
                }
            }
            finally {
                $dataStream.Dispose()
            }
        }
        finally {
            $dataClient.Dispose()
        }

        $finishReply = Read-FtpReply -Reader $reader
        if ($finishReply.Code -ne 226) { throw "FTP transfer did not complete: $($finishReply.Text)" }
        if ($received -le 0) { throw "FTP transfer made no progress at offset $offset." }
        $offset += $received
    }

    $output.Flush()
    $output.Dispose()
    $output = $null
    [void](Send-FtpCommand -Writer $writer -Reader $reader -Command 'QUIT' -ExpectedCodes 221)

    $item = Get-Item -LiteralPath $OutputPath
    if ($item.Length -ne $ExpectedBytes) {
        throw "Retrieved length mismatch: expected $ExpectedBytes, got $($item.Length)"
    }
    [pscustomobject]@{
        RemotePath = $RemotePath
        OutputPath = $item.FullName
        Bytes = $item.Length
        SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash
    }
}
finally {
    if ($output) { $output.Dispose() }
    if ($reader) { $reader.Dispose() }
    if ($writer) { $writer.Dispose() }
    if ($controlStream) { $controlStream.Dispose() }
    $control.Dispose()
}
