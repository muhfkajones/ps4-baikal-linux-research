[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HostRoot,

    [Parameter(Mandatory)]
    [string]$CandidatePayload,

    [string]$CandidateName = 'exp015-initial-load-1350.bin',

    [string]$BaseUrl
)

$ErrorActionPreference = 'Stop'

$normalExpected = 'C05F6097DBC0707E8EC2FB5443EE507DA6AC6E79C6FA8E9F78544658710EFEFF'
$candidateExpected = 'FA3ED59E61653613E415022D8DDBC5DF1DD5901761466FA30C4EE9D2492301C6'
$normalPath = Join-Path $HostRoot 'hen.bin'
$hostScript = Join-Path $HostRoot 'jb.js'

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ($Actual -ne $Expected) {
        throw "$Label mismatch: expected $Expected, got $Actual"
    }
}

Assert-Equal (Get-Sha256 $normalPath) $normalExpected 'normal HEN SHA-256'
Assert-Equal (Get-Sha256 $CandidatePayload) $candidateExpected 'EXP-015 candidate SHA-256'
Assert-Equal (Get-Item -LiteralPath $normalPath).Length 500448 'normal HEN length'
Assert-Equal (Get-Item -LiteralPath $CandidatePayload).Length 55044 'EXP-015 candidate length'

$overrideLine = 'const PAYLOAD_FILE = PAYLOAD_OVERRIDE || "hen.bin";'
if (-not (Select-String -LiteralPath $hostScript -SimpleMatch $overrideLine -Quiet)) {
    throw 'jb.js does not apply its validated payloadfile override'
}

$result = [ordered]@{
    localNormalSha256 = $normalExpected
    localCandidateSha256 = $candidateExpected
    payloadOverrideApplied = $true
    httpChecked = $false
}

if ($BaseUrl) {
    $base = $BaseUrl.TrimEnd('/')
    $normalBytes = (Invoke-WebRequest -UseBasicParsing "$base/hen.bin").Content
    $candidateBytes = (Invoke-WebRequest -UseBasicParsing "$base/$CandidateName").Content
    $normalHttpHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$normalBytes))
    $candidateHttpHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]$candidateBytes))
    Assert-Equal $normalBytes.Length 500448 'served normal HEN length'
    Assert-Equal $candidateBytes.Length 55044 'served EXP-015 candidate length'
    Assert-Equal $normalHttpHash $normalExpected 'served normal HEN SHA-256'
    Assert-Equal $candidateHttpHash $candidateExpected 'served EXP-015 candidate SHA-256'
    $result.httpChecked = $true
    $result.httpNormalSha256 = $normalHttpHash
    $result.httpCandidateSha256 = $candidateHttpHash
}

[pscustomobject]$result
