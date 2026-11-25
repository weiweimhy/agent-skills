#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SkillRoot = (Join-Path $HOME '.agents/skills'),
    [string]$Manifest = (Join-Path $HOME '.gemini/config/skills.json')
)

$ErrorActionPreference = 'Stop'
$root = (Get-Item -LiteralPath $SkillRoot).FullName
if (-not (Get-ChildItem -LiteralPath $root -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        Select-Object -First 1)) {
    throw "No top-level skills under $root"
}
$file = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Manifest)
$entry = @{ path = $root.Replace('\', '/') }
$json = @{ entries = @($entry) } | ConvertTo-Json -Depth 4
if ([IO.File]::Exists($file)) {
    $current = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -AsHashtable
    foreach ($item in $current.entries) {
        if ($item.path -and [IO.Path]::GetFullPath($item.path, [IO.Path]::GetDirectoryName($file)) -eq $root) {
            Write-Output "Already registered in $file (existing filters preserved)"
            return
        }
    }
    throw "Existing manifest preserved. Append this object to its entries array: $($entry | ConvertTo-Json -Compress)"
}
$directory = [IO.Path]::GetDirectoryName($file)
[void][IO.Directory]::CreateDirectory($directory)
$temporary = Join-Path $directory ([IO.Path]::GetRandomFileName())
try {
    [IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine)
    [IO.File]::Move($temporary, $file)
} finally {
    [IO.File]::Delete($temporary)
}
Write-Output "Registered $root in $file"
