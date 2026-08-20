<#
.SYNOPSIS
Mirrors the personal skills from the Codex global directory into this Git
repository, validates them, and publishes only those skill directories.

.DESCRIPTION
Run this on the computer where the three skills are authored. The global
directory is the source of truth on this computer; do not edit the linked
copies on other computers.

.EXAMPLE
pwsh ./scripts/Publish-PersonalSkills.ps1
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$GlobalSkillsRoot = (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\skills"),
    [string[]]$SkillNames = @(
        "tibishu-notes",
        "tibishu-note-search",
        "project-standards-init"
    ),
    [string]$CommitMessage = "",
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$automationFiles = @(
    "scripts/Publish-PersonalSkills.ps1",
    "scripts/Install-PersonalSkills.ps1"
)

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
        throw "RepositoryRoot must be the Git repository root, not a subdirectory: $resolved"
    }

    return $resolved
}

function Invoke-DirectoryMirror {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        [Parameter(Mandatory)]
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    & robocopy $Source $Destination /MIR /COPY:DAT /DCOPY:DAT /XJ /R:2 /W:1 /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed while mirroring '$Source' to '$Destination' (exit code $LASTEXITCODE)."
    }
}

function Invoke-PreflightValidation {
    param(
        [Parameter(Mandatory)]
        [string]$Validator,
        [Parameter(Mandatory)]
        [string]$GlobalRoot,
        [Parameter(Mandatory)]
        [string[]]$Names
    )

    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-preflight-" + [guid]::NewGuid().ToString("N"))

    try {
        New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
        foreach ($name in $Names) {
            $source = Join-Path $GlobalRoot $name
            if (-not (Test-Path -LiteralPath $source -PathType Container)) {
                throw "Global skill directory does not exist: $source"
            }
            if (-not (Test-Path -LiteralPath (Join-Path $source "SKILL.md") -PathType Leaf)) {
                throw "Global skill is missing SKILL.md: $source"
            }

            Copy-Item -LiteralPath $source -Destination $temporaryRoot -Recurse -Force
        }

        & $Validator -Root $temporaryRoot
        if (-not $?) {
            throw "Preflight skill validation failed. The repository was not changed."
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

try {
    $repository = Assert-RepositoryRoot -Path $RepositoryRoot
    if (-not (Test-Path -LiteralPath $GlobalSkillsRoot -PathType Container)) {
        throw "Global skills directory does not exist: $GlobalSkillsRoot"
    }
    $globalRoot = (Resolve-Path -LiteralPath $GlobalSkillsRoot).Path

    $validator = Join-Path $repository "scripts\validate-skills.ps1"
    if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
        throw "Repository validator is missing: $validator"
    }
    foreach ($file in $automationFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $repository $file) -PathType Leaf)) {
            throw "Personal-skill automation file is missing: $file"
        }
    }

    $pendingChanges = @(Get-GitOutput -Repository $repository -Arguments (@("status", "--porcelain", "--") + $SkillNames))
    if ($pendingChanges.Count -gt 0) {
        throw "The repository already has uncommitted changes in the managed skill directories. Commit, stash, or revert them before publishing.`n$($pendingChanges -join "`n")"
    }

    $ignoredChanges = @(Get-GitOutput -Repository $repository -Arguments (@("ls-files", "--others", "--ignored", "--exclude-standard", "--") + $SkillNames))
    if ($ignoredChanges.Count -gt 0) {
        throw "The repository contains ignored files in the managed skill directories. Refusing to let robocopy remove them.`n$($ignoredChanges -join "`n")"
    }

    $preStagedChanges = @(Get-GitOutput -Repository $repository -Arguments @("diff", "--cached", "--name-only"))
    if ($preStagedChanges.Count -gt 0) {
        throw "The Git index already contains staged changes. Refusing to include unrelated files in this skill commit.`n$($preStagedChanges -join "`n")"
    }

    Invoke-PreflightValidation -Validator $validator -GlobalRoot $globalRoot -Names $SkillNames

    foreach ($name in $SkillNames) {
        Invoke-DirectoryMirror -Source (Join-Path $globalRoot $name) -Destination (Join-Path $repository $name)
    }

    & $validator -Root $repository
    if (-not $?) {
        throw "Repository validation failed after mirroring. The changes were not committed."
    }

    $pathsToPublish = @($SkillNames) + $automationFiles
    Invoke-Git -Arguments (@("-C", $repository, "add", "--") + $pathsToPublish)
    $stagedChanges = @(Get-GitOutput -Repository $repository -Arguments (@("diff", "--cached", "--name-only", "--") + $pathsToPublish))

    if ($stagedChanges.Count -eq 0) {
        Write-Output "No personal-skill changes to publish."
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $CommitMessage = "chore: sync personal Codex skills"
    }

    Invoke-Git -Arguments @("-C", $repository, "commit", "-m", $CommitMessage)

    if ($NoPush) {
        Write-Output "Committed local skill changes. Push later with: git -C `"$repository`" push"
        exit 0
    }

    Invoke-Git -Arguments @("-C", $repository, "push")
    Write-Output "Published: $($SkillNames -join ', ')"
}
catch {
    Write-Error $_
    exit 1
}
