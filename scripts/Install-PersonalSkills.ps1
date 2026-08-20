<#
.SYNOPSIS
Safely installs or updates the personal Codex skills from a Git repository.

.DESCRIPTION
The script keeps one normal Git checkout outside the global skills directory
and exposes each managed skill through a Windows directory junction. It never
overwrites an existing normal directory or a link pointing to another source.
Before an update reaches the live junctions, it validates the fetched revision
inside an isolated temporary Git worktree.

.EXAMPLE
pwsh ./scripts/Install-PersonalSkills.ps1
#>
[CmdletBinding()]
param(
    [string]$RepositoryUrl = "git@github.com:weiweimhy/agent-skills.git",
    [string]$Branch = "main",
    [string]$RepositoryPath = (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\skill-source\agent-skills"),
    [string]$GlobalSkillsRoot = (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\skills"),
    [string[]]$SkillNames = @(
        "tibishu-notes",
        "tibishu-note-search",
        "project-standards-init"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & git @Arguments
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }

    if ($exitCode -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

function Get-GitOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = & git -C $Repository @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git -C $Repository $($Arguments -join ' ')"
    }

    return @($output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Assert-RepositoryRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Repository directory does not exist: $Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $gitRootOutput = @(Get-GitOutput -Repository $resolved -Arguments @("rev-parse", "--show-toplevel"))
    $gitRoot = $gitRootOutput[0]
    $gitRoot = (Resolve-Path -LiteralPath $gitRoot).Path

    if (-not [string]::Equals($resolved.TrimEnd("\\"), $gitRoot.TrimEnd("\\"), [StringComparison]::OrdinalIgnoreCase)) {
        throw "RepositoryPath must be the Git repository root, not a subdirectory: $resolved"
    }

    return $resolved
}

function Assert-SkillsAreValid {
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [Parameter(Mandatory)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        $skillDirectory = Join-Path $Repository $name
        if (-not (Test-Path -LiteralPath $skillDirectory -PathType Container)) {
            throw "Skill directory is missing from the repository: $skillDirectory"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $skillDirectory "SKILL.md") -PathType Leaf)) {
            throw "Skill directory is missing SKILL.md: $skillDirectory"
        }
    }

    $validator = Join-Path $Repository "scripts\validate-skills.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        throw "Repository validator is missing: $validator"
    }

    $validationOutput = & $validator -Root $Repository
    $validationSucceeded = $?
    $validationOutput | ForEach-Object { Write-Host $_ }
    if (-not $validationSucceeded) {
        throw "Skill validation failed: $Repository"
    }
}

function Test-RepositoryIsClean {
    param(
        [Parameter(Mandatory)]
        [string]$Repository
    )

    $changes = @(Get-GitOutput -Repository $Repository -Arguments @("status", "--porcelain"))
    if ($changes.Count -gt 0) {
        throw "The local skill checkout has uncommitted changes. Do not edit linked skills on this computer; discard or commit the changes before updating.`n$($changes -join "`n")"
    }
}

function Update-RepositoryAfterValidation {
    param(
        [Parameter(Mandatory)]
        [string]$Repository,
        [Parameter(Mandatory)]
        [string[]]$Names
    )

    Test-RepositoryIsClean -Repository $Repository
    Invoke-Git -Arguments @("-C", $Repository, "fetch", "--prune", "origin")

    $upstreamOutput = @(Get-GitOutput -Repository $Repository -Arguments @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"))
    $upstream = $upstreamOutput[0]
    $countOutput = @(Get-GitOutput -Repository $Repository -Arguments @("rev-list", "--left-right", "--count", "HEAD...$upstream"))
    $counts = $countOutput[0] -split "\s+"
    $ahead = [int]$counts[0]
    $behind = [int]$counts[1]

    if ($ahead -gt 0) {
        throw "The local skill checkout is ahead of $upstream. Publish or reconcile it before installing updates."
    }
    if ($behind -eq 0) {
        Assert-SkillsAreValid -Repository $Repository -Names $Names
        return $false
    }

    $temporaryWorktree = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-update-" + [guid]::NewGuid().ToString("N"))
    try {
        Invoke-Git -Arguments @("-C", $Repository, "worktree", "add", "--detach", $temporaryWorktree, $upstream)
        Assert-SkillsAreValid -Repository $temporaryWorktree -Names $Names
        Invoke-Git -Arguments @("-C", $Repository, "merge", "--ff-only", $upstream)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryWorktree) {
            & git -C $Repository worktree remove --force $temporaryWorktree
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Could not remove temporary validation worktree: $temporaryWorktree"
            }
        }
    }

    return $true
}

function Ensure-SkillJunction {
    param(
        [Parameter(Mandatory)]
        [string]$LinkPath,
        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $resolvedTarget = (Resolve-Path -LiteralPath $TargetPath).Path.TrimEnd("\\")

    $item = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        if (-not (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "Refusing to replace existing non-link directory: $LinkPath"
        }

        $existingTargets = @($item.Target)
        if ($existingTargets.Count -ne 1 -or [string]::IsNullOrWhiteSpace($existingTargets[0])) {
            throw "Refusing to reuse a link with an unreadable target: $LinkPath"
        }

        if (-not (Test-Path -LiteralPath $existingTargets[0] -PathType Container)) {
            throw "Refusing to replace a broken existing link: $LinkPath -> $($existingTargets[0])"
        }

        $resolvedExistingTarget = (Resolve-Path -LiteralPath $existingTargets[0]).Path.TrimEnd("\\")
        if (-not [string]::Equals($resolvedExistingTarget, $resolvedTarget, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to replace an existing link that points elsewhere: $LinkPath -> $resolvedExistingTarget"
        }

        Write-Output "Already linked: $LinkPath"
        return
    }

    New-Item -ItemType Junction -Path $LinkPath -Target $resolvedTarget | Out-Null
    Write-Output "Linked: $LinkPath -> $resolvedTarget"
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required but was not found on PATH."
    }

    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        $parentDirectory = Split-Path -Path $RepositoryPath -Parent
        New-Item -ItemType Directory -Force -Path $parentDirectory | Out-Null
        Invoke-Git -Arguments @("clone", "--branch", $Branch, $RepositoryUrl, $RepositoryPath)
    }

    $repository = Assert-RepositoryRoot -Path $RepositoryPath
    $updated = Update-RepositoryAfterValidation -Repository $repository -Names $SkillNames

    New-Item -ItemType Directory -Force -Path $GlobalSkillsRoot | Out-Null
    $globalRoot = (Resolve-Path -LiteralPath $GlobalSkillsRoot).Path

    foreach ($name in $SkillNames) {
        Ensure-SkillJunction -LinkPath (Join-Path $globalRoot $name) -TargetPath (Join-Path $repository $name)
    }

    if ($updated) {
        Write-Output "Installed validated update. Restart Codex or open a new task to reload skill discovery."
    }
    else {
        Write-Output "Skills are already up to date. Restart Codex or open a new task after the first installation."
    }
}
catch {
    Write-Error $_
    exit 1
}
