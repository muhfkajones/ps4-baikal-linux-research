[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$HostRoot,
    [ValidateRange(1024, 65534)][int]$Port = 18001
)

$ErrorActionPreference = 'Stop'
$hostPath = [IO.Path]::GetFullPath($HostRoot)
$serverScript = Join-Path $hostPath 'serve.py'
$jbPath = Join-Path $hostPath 'jb.html'
$indexPath = Join-Path $hostPath 'index.html'
foreach ($path in @($serverScript, $jbPath, $indexPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required host file is missing: $path"
    }
}

$jbLength = (Get-Item -LiteralPath $jbPath).Length
$indexLength = (Get-Item -LiteralPath $indexPath).Length

function Start-TestServer([int]$ListenPort, [string]$Token) {
    $env:PS4_HOST_BIND = '127.0.0.1'
    $env:PS4_HOST_PORT = [string]$ListenPort
    $env:PS4_RUN_TOKEN = $Token
    $process = Start-Process -FilePath 'python' -ArgumentList @($serverScript) `
        -WorkingDirectory $hostPath -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 700
    $process
}

function Stop-TestServer($Process) {
    if ($Process) {
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }
}

function Get-BodyLength([string]$Url) {
    (Invoke-WebRequest -UseBasicParsing $Url).Content.Length
}

$first = $null
$second = $null
try {
    $token = 'sequential-offline-test-token'
    $first = Start-TestServer $Port $token
    $base = "http://127.0.0.1:$Port"
    if ((Get-BodyLength "$base/jb.html") -ne $indexLength) { throw 'no-token request was not inert' }
    if ((Get-BodyLength "$base/jb.html?run=wrong") -ne $indexLength) { throw 'wrong-token request was not inert' }
    if ((Get-BodyLength "$base/jb.html?run=$token") -ne $jbLength) { throw 'first valid token did not serve jb.html' }
    if ((Get-BodyLength "$base/jb.html?run=$token") -ne $indexLength) { throw 'reused token was not inert' }
    Stop-TestServer $first
    $first = $null

    $duplicateToken = 'concurrent-offline-test-token'
    $second = Start-TestServer ($Port + 1) $duplicateToken
    $duplicateUrl = "http://127.0.0.1:$($Port + 1)/jb.html?run=$duplicateToken"
    $client = [Net.Http.HttpClient]::new()
    try {
        $requests = @($client.GetByteArrayAsync($duplicateUrl), $client.GetByteArrayAsync($duplicateUrl))
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]$requests)
        $lengths = @($requests[0].Result.Length, $requests[1].Result.Length) | Sort-Object
        $expected = @($indexLength, $jbLength) | Sort-Object
        if ($lengths[0] -ne $expected[0] -or $lengths[1] -ne $expected[1]) {
            throw "concurrent duplicate gate failed: lengths=$($lengths -join ',')"
        }
    }
    finally {
        $client.Dispose()
    }

    [pscustomobject]@{
        NoTokenInert = $true
        WrongTokenInert = $true
        FirstTokenServedExploit = $true
        ReusedTokenInert = $true
        ConcurrentDuplicateServedExploitExactlyOnce = $true
    }
}
finally {
    Stop-TestServer $first
    Stop-TestServer $second
    Remove-Item Env:PS4_HOST_BIND, Env:PS4_HOST_PORT, Env:PS4_RUN_TOKEN -ErrorAction SilentlyContinue
}
