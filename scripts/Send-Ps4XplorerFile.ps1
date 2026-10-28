# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PS4 Baikal Linux Research contributors

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Address,
    [ValidateRange(1, 65535)][int]$Port = 2121,
    [Parameter(Mandatory)][string]$LocalPath,
    [Parameter(Mandatory)][string]$RemotePath
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LocalPath -PathType Leaf)) { throw "Local file not found: $LocalPath" }
if (-not $RemotePath.StartsWith('/data/payloads/') -or $RemotePath.EndsWith('/')) {
    throw 'RemotePath must name a file directly below /data/payloads/.'
}

$escapedPath = ($RemotePath -split '/' | Where-Object { $_ } | ForEach-Object {
    [Uri]::EscapeDataString($_)
}) -join '/'
$uri = "ftp://${Address}:$Port/$escapedPath"
$credentials = [Net.NetworkCredential]::new('anonymous', '')

$sizeRequest = [Net.FtpWebRequest]::Create($uri)
$sizeRequest.Method = [Net.WebRequestMethods+Ftp]::GetFileSize
$sizeRequest.Credentials = $credentials
$sizeRequest.UseBinary = $true
$sizeRequest.UsePassive = $true
$sizeRequest.KeepAlive = $false
try {
    $sizeResponse = $sizeRequest.GetResponse()
    try { throw "Refusing to overwrite existing console file: $RemotePath" }
    finally { $sizeResponse.Dispose() }
}
catch [Net.WebException] {
    if (-not $_.Exception.Response -or
        ([Net.FtpWebResponse]$_.Exception.Response).StatusCode -ne [Net.FtpStatusCode]::ActionNotTakenFileUnavailable) {
        throw
    }
    $_.Exception.Response.Dispose()
}

$item = Get-Item -LiteralPath $LocalPath
$request = [Net.FtpWebRequest]::Create($uri)
$request.Method = [Net.WebRequestMethods+Ftp]::UploadFile
$request.Credentials = $credentials
$request.UseBinary = $true
$request.UsePassive = $true
$request.KeepAlive = $false
$request.ContentLength = $item.Length
$input = [IO.File]::OpenRead($item.FullName)
try {
    $upload = $request.GetRequestStream()
    try {
        $buffer = [byte[]]::new(256)
        while (($count = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $upload.Write($buffer, 0, $count)
        }
        $upload.Flush()
    }
    finally { $upload.Dispose() }
}
finally { $input.Dispose() }

$response = $request.GetResponse()
try {
    if ($response.StatusCode -notin [Net.FtpStatusCode]::ClosingData, [Net.FtpStatusCode]::FileActionOK) {
        throw "FTP upload did not complete: $($response.StatusDescription)"
    }
}
finally { $response.Dispose() }

[pscustomobject]@{
    RemotePath = $RemotePath
    Bytes = $item.Length
    SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.FullName).Hash
    OverwritePrevented = $true
}
