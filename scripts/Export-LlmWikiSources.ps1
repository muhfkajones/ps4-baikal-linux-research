[CmdletBinding()]
param(
    [Parameter()]
    [string]$Destination = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'llm-wiki-data\ps4-baikal-linux-research\raw\sources\repository')
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$destinationFull = [System.IO.Path]::GetFullPath($Destination)
$privateRoot = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $repositoryRoot) 'ps4-flash-acquisition'))

if ($destinationFull.StartsWith($repositoryRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must remain outside the public Git repository.'
}

if ($destinationFull.StartsWith($privateRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must not be inside the private acquisition workspace.'
}

$tracked = & git -C $repositoryRoot ls-files
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate tracked repository files.'
}

$selected = foreach ($relativePath in $tracked) {
    $normalized = $relativePath.Replace('\', '/')
    $include =
        $normalized -in @('README.md', 'AGENTS.md', 'CLAUDE.md', 'CREDITS.md', 'CONTRIBUTING.md', 'SECURITY.md') -or
        $normalized -match '^LICENSE(?:\..+)?$' -or
        $normalized -match '^docs/.+\.md$' -or
        $normalized -match '^manifests/.+\.json$' -or
        $normalized -match '^payloads/.+/(?:README|AUDIT)\.md$'

    if ($include) {
        $source = Join-Path $repositoryRoot $relativePath
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            [pscustomobject]@{
                RelativePath = $normalized
                Source       = $source
            }
        }
    }
}

New-Item -ItemType Directory -Path $destinationFull -Force | Out-Null

$manifestFiles = foreach ($item in $selected) {
    $target = Join-Path $destinationFull $item.RelativePath
    $targetDirectory = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Copy-Item -LiteralPath $item.Source -Destination $target -Force

    [ordered]@{
        path   = $item.RelativePath
        sha256 = (Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes  = (Get-Item -LiteralPath $item.Source).Length
    }
}

$manifest = [ordered]@{
    format          = 1
    source          = 'ps4-baikal-linux-research tracked safe-text export'
    repository_root = '<local repository path intentionally omitted>'
    git_head        = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    exported_utc    = [DateTime]::UtcNow.ToString('o')
    file_count      = @($manifestFiles).Count
    files           = @($manifestFiles)
}

$manifestPath = Join-Path $destinationFull 'SOURCE-MANIFEST.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host "Exported $(@($manifestFiles).Count) tracked safe-text files."
Write-Host "Destination: $destinationFull"
Write-Host "Manifest: $manifestPath"
