#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$SourceRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$DeploymentClone = (Join-Path $HOME ".agents/skills"),
    [switch]$RestoreIdentical,
    [switch]$CheckAntigravity
)

$ErrorActionPreference = "Stop"

$sourceRoot = (Resolve-Path -LiteralPath $SourceRepo).Path
$deployRoot = [System.IO.Path]::GetFullPath($DeploymentClone)

if (-not (Test-Path -LiteralPath $deployRoot -PathType Container)) {
    throw "Deployment clone not found at: $deployRoot"
}

if ($sourceRoot.TrimEnd('\', '/').Equals($deployRoot.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRepo and DeploymentClone resolve to the same path: $sourceRoot"
}

# 1. Check source repo is clean and pushed
$sourceStatus = @(& git -C $sourceRoot status --porcelain=v1)
if ($sourceStatus.Count -gt 0) {
    throw "Source repository has uncommitted changes. Commit and push source first."
}

$sourceUpstream = (& git -C $sourceRoot rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null) -join ""
if ([string]::IsNullOrWhiteSpace($sourceUpstream)) {
    throw "Source repository branch has no configured upstream."
}

$aheadBehind = (& git -C $sourceRoot rev-list --left-right --count "$sourceUpstream...HEAD") -join ""
if ($aheadBehind -match '^(\d+)\s+(\d+)$') {
    $ahead = [int]$Matches[2]
    if ($ahead -gt 0) {
        throw "Source repository is ahead of $sourceUpstream by $ahead commit(s). Push source first."
    }
}

$sourceHead = (& git -C $sourceRoot rev-parse HEAD) -join ""

# 2. Inspect deployment clone cleanliness
$deployStatus = @(& git -C $deployRoot status --porcelain=v1 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($deployStatus.Count -gt 0) {
    $identicalPaths = New-Object System.Collections.Generic.List[string]
    $differingPaths = New-Object System.Collections.Generic.List[string]

    foreach ($line in $deployStatus) {
        $rel = $line.Substring(3).Trim('"')
        $srcFile = Join-Path $sourceRoot $rel
        $depFile = Join-Path $deployRoot $rel

        $isIdentical = $false
        if ((Test-Path -LiteralPath $srcFile -PathType Leaf) -and (Test-Path -LiteralPath $depFile -PathType Leaf)) {
            $srcHash = (Get-FileHash -LiteralPath $srcFile -Algorithm SHA256).Hash
            $depHash = (Get-FileHash -LiteralPath $depFile -Algorithm SHA256).Hash
            if ($srcHash -eq $depHash) {
                $isIdentical = $true
            }
        } elseif (-not (Test-Path -LiteralPath $srcFile) -and -not (Test-Path -LiteralPath $depFile)) {
            $isIdentical = $true
        }

        if ($isIdentical) {
            $identicalPaths.Add($rel)
        } else {
            $differingPaths.Add("$line")
        }
    }

    if ($differingPaths.Count -gt 0) {
        Write-Output "Deployment clone has local changes that differ from pushed source:"
        $differingPaths | ForEach-Object { Write-Output "  $_" }
        throw "Aborted without modifying deployment clone. Preserve and resolve user changes manually."
    }

    if (-not $RestoreIdentical) {
        Write-Output "Deployment clone has dirty paths that are byte-identical to pushed source:"
        $identicalPaths | ForEach-Object { Write-Output "  $_" }
        throw "Re-run with -RestoreIdentical to restore only these verified identical paths and fast-forward."
    }

    foreach ($rel in $identicalPaths) {
        $tracked = & git -C $deployRoot ls-files --error-unmatch -- $rel 2>$null
        if ($LASTEXITCODE -eq 0) {
            & git -C $deployRoot checkout HEAD -- $rel
            if ($LASTEXITCODE -ne 0) { throw "Failed to restore tracked path: $rel" }
        } else {
            Remove-Item -LiteralPath (Join-Path $deployRoot $rel) -Force
        }
    }
}

# 3. Fast-forward deployment clone
& git -C $deployRoot pull --ff-only
if ($LASTEXITCODE -ne 0) {
    throw "git pull --ff-only failed on deployment clone."
}

$deployHead = (& git -C $deployRoot rev-parse HEAD) -join ""
$postStatus = @(& git -C $deployRoot status --porcelain=v1)

if ($postStatus.Count -gt 0) {
    throw "Deployment clone is not clean after fast-forward."
}

$manifestStatus = "not_checked"
if ($CheckAntigravity) {
    $manifestPath = Join-Path $HOME ".gemini/config/skills.json"
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -AsHashtable
        $registered = $false
        foreach ($item in $manifest.entries) {
            if ($item.path -and [IO.Path]::GetFullPath($item.path, [IO.Path]::GetDirectoryName($manifestPath)).Equals($deployRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $registered = $true
                break
            }
        }
        $manifestStatus = if ($registered) { "registered" } else { "not_registered" }
    } else {
        $manifestStatus = "manifest_missing"
    }
}

[PSCustomObject]@{
    SourceHead         = $sourceHead
    DeploymentHead     = $deployHead
    Matched            = ($sourceHead -eq $deployHead)
    DeploymentClean    = ($postStatus.Count -eq 0)
    AntigravityStatus  = $manifestStatus
    NextStep           = "Start a new Codex task (or run /skills reload in Antigravity) to refresh skill discovery."
}
