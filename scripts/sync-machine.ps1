#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SkillRoot,
    [switch]$SkipPull,
    [ValidateSet('auto', 'codex', 'antigravity', 'workbuddy', 'codebuddy', 'claude', 'dsh')]
    [string[]]$Hosts = @('auto'),
    [switch]$LinkDsh,
    [string]$AntigravityManifest,
    [string]$HomeDir = $HOME,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$BasePath
    )

    $candidate = $Path.Trim()
    if ($candidate.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $candidate = '\\' + $candidate.Substring(8)
    } elseif ($candidate.StartsWith('\\?\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $candidate = $candidate.Substring(4)
    }

    if (-not [string]::IsNullOrWhiteSpace($BasePath) -and -not [System.IO.Path]::IsPathRooted($candidate)) {
        $full = [System.IO.Path]::GetFullPath($candidate, $BasePath)
    } else {
        $full = [System.IO.Path]::GetFullPath($candidate)
    }

    return $full.TrimEnd('\', '/')
}

function Test-SamePath {
    param(
        [string]$PathA,
        [string]$PathB
    )
    if ([string]::IsNullOrWhiteSpace($PathA) -or [string]::IsNullOrWhiteSpace($PathB)) {
        return $false
    }
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    return (Get-NormalizedPath -Path $PathA).Equals((Get-NormalizedPath -Path $PathB), $comparison)
}

function Test-PathInsideRoot {
    param(
        [string]$CandidatePath,
        [string]$RootPath
    )
    if ([string]::IsNullOrWhiteSpace($CandidatePath) -or [string]::IsNullOrWhiteSpace($RootPath)) {
        return $false
    }
    $normCandidate = Get-NormalizedPath -Path $CandidatePath
    $normRoot = Get-NormalizedPath -Path $RootPath
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    if ($normCandidate.Equals($normRoot, $comparison)) {
        return $true
    }
    $prefix = $normRoot + [System.IO.Path]::DirectorySeparatorChar
    return $normCandidate.StartsWith($prefix, $comparison)
}

function Get-ReparseTargetPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )

    $rawTarget = $null
    if ($Item.PSObject.Properties['LinkTarget'] -and -not [string]::IsNullOrWhiteSpace($Item.LinkTarget)) {
        $rawTarget = $Item.LinkTarget
    } elseif ($Item.PSObject.Properties['Target'] -and $Item.Target) {
        if ($Item.Target -is [System.Array]) {
            $rawTarget = [string]$Item.Target[0]
        } else {
            $rawTarget = [string]$Item.Target
        }
    }

    if ([string]::IsNullOrWhiteSpace($rawTarget)) {
        return $null
    }

    $parentDir = Split-Path -Path $Item.FullName -Parent
    return Get-NormalizedPath -Path $rawTarget -BasePath $parentDir
}

function Remove-LinkOnly {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )
    if ($Item.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
        [System.IO.Directory]::Delete($Item.FullName, $false)
    } else {
        [System.IO.File]::Delete($Item.FullName)
    }
}

function New-SkillLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LinkPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    [void](New-Item -ItemType $linkType -Path $LinkPath -Target $TargetPath)
}

function Get-UserOrProcessEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $val = [System.Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($val) -and $IsWindows) {
        $val = [System.Environment]::GetEnvironmentVariable($Name, 'User')
    }
    return $val
}

function Sync-SkillDirectoryLinks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        [Parameter(Mandatory = $true)]
        [string]$TargetSkillsDir,
        [Parameter(Mandatory = $true)]
        [string]$NormalizedSkillRoot,
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo[]]$ActiveSkills,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $added = 0
    $updated = 0
    $removed = 0
    $unchanged = 0
    $conflicts = New-Object System.Collections.Generic.List[string]
    $notes = New-Object System.Collections.Generic.List[string]

    $targetItem = Get-Item -LiteralPath $TargetSkillsDir -Force -ErrorAction SilentlyContinue
    if ($null -ne $targetItem) {
        if ($targetItem.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $wholeTarget = Get-ReparseTargetPath -Item $targetItem
            if ($wholeTarget -and (Test-SamePath -PathA $wholeTarget -PathB $NormalizedSkillRoot)) {
                return [PSCustomObject]@{
                    Host       = $HostName
                    Mode       = 'whole-dir-link'
                    Status     = 'synced'
                    TargetPath = $TargetSkillsDir
                    Added      = 0
                    Updated    = 0
                    Removed    = 0
                    Unchanged  = $ActiveSkills.Count
                    Conflicts  = @()
                    Notes      = @('Target skills directory is already linked directly to SkillRoot.')
                }
            }
            $conflicts.Add("Target skills directory '$TargetSkillsDir' is an external link ($wholeTarget); preserved untouched.")
            return [PSCustomObject]@{
                Host       = $HostName
                Mode       = 'per-skill-junction'
                Status     = 'skipped_external_link'
                TargetPath = $TargetSkillsDir
                Added      = 0
                Updated    = 0
                Removed    = 0
                Unchanged  = 0
                Conflicts  = @($conflicts)
                Notes      = @()
            }
        }

        if (-not $targetItem.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
            $conflicts.Add("Target path '$TargetSkillsDir' exists as a file; skipped.")
            return [PSCustomObject]@{
                Host       = $HostName
                Mode       = 'per-skill-junction'
                Status     = 'skipped_file_conflict'
                TargetPath = $TargetSkillsDir
                Added      = 0
                Updated    = 0
                Removed    = 0
                Unchanged  = 0
                Conflicts  = @($conflicts)
                Notes      = @()
            }
        }
    } else {
        if ($Cmdlet.ShouldProcess($TargetSkillsDir, "Create $HostName skills directory")) {
            [void](New-Item -ItemType Directory -Path $TargetSkillsDir -Force)
        }
    }

    $activeMap = @{}
    foreach ($skill in $ActiveSkills) {
        $activeMap[$skill.Name] = Get-NormalizedPath -Path $skill.FullName
    }

    # 1. Ensure a Junction/symlink exists for each active skill
    foreach ($skill in $ActiveSkills) {
        $linkPath = Join-Path $TargetSkillsDir $skill.Name
        $expectedTarget = $activeMap[$skill.Name]
        $existing = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue

        if ($null -eq $existing) {
            if ($Cmdlet.ShouldProcess($linkPath, "Create skill link -> $expectedTarget")) {
                New-SkillLink -LinkPath $linkPath -TargetPath $expectedTarget
            }
            $added++
            continue
        }

        if ($existing.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
            $actualTarget = Get-ReparseTargetPath -Item $existing
            if ($actualTarget -and (Test-SamePath -PathA $actualTarget -PathB $expectedTarget)) {
                $unchanged++
            } elseif ($actualTarget -and (Test-PathInsideRoot -CandidatePath $actualTarget -RootPath $NormalizedSkillRoot)) {
                if ($Cmdlet.ShouldProcess($linkPath, "Relink stale target ($actualTarget) -> $expectedTarget")) {
                    Remove-LinkOnly -Item $existing
                    New-SkillLink -LinkPath $linkPath -TargetPath $expectedTarget
                }
                $updated++
            } else {
                $conflicts.Add("Preserved existing external link '$linkPath' -> '$actualTarget'.")
            }
        } else {
            $conflicts.Add("Preserved existing non-link item '$linkPath' (host built-in or local skill).")
        }
    }

    # 2. Prune stale links pointing into SkillRoot whose skills were removed or renamed
    if (Test-Path -LiteralPath $TargetSkillsDir -PathType Container) {
        $entries = @(Get-ChildItem -LiteralPath $TargetSkillsDir -Force -ErrorAction SilentlyContinue)
        foreach ($entry in $entries) {
            if (-not $entry.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
                continue
            }
            $actualTarget = Get-ReparseTargetPath -Item $entry
            if (-not $actualTarget -or -not (Test-PathInsideRoot -CandidatePath $actualTarget -RootPath $NormalizedSkillRoot)) {
                continue
            }

            $isStillActive = $activeMap.ContainsKey($entry.Name) -and
                (Test-SamePath -PathA $actualTarget -PathB $activeMap[$entry.Name]) -and
                (Test-Path -LiteralPath (Join-Path $actualTarget 'SKILL.md') -PathType Leaf)

            if (-not $isStillActive) {
                if ($Cmdlet.ShouldProcess($entry.FullName, "Remove stale skill link -> $actualTarget")) {
                    Remove-LinkOnly -Item $entry
                }
                $removed++
            }
        }
    }

    $status = if ($conflicts.Count -gt 0) {
        'synced_with_conflicts'
    } elseif ($added -gt 0 -or $updated -gt 0 -or $removed -gt 0) {
        'updated'
    } else {
        'up_to_date'
    }

    return [PSCustomObject]@{
        Host       = $HostName
        Mode       = if ($IsWindows) { 'per-skill-junction' } else { 'per-skill-symlink' }
        Status     = $status
        TargetPath = $TargetSkillsDir
        Added      = $added
        Updated    = $updated
        Removed    = $removed
        Unchanged  = $unchanged
        Conflicts  = @($conflicts)
        Notes      = @($notes)
    }
}

function Sync-AntigravityManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$NormalizedSkillRoot,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $file = $Cmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ManifestPath)
    $entry = @{ path = $NormalizedSkillRoot.Replace('\', '/') }

    if ([System.IO.File]::Exists($file)) {
        $current = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json -AsHashtable
        if ($current -and $current.ContainsKey('entries') -and $current.entries) {
            foreach ($item in $current.entries) {
                if ($item.path) {
                    $resolvedItem = Get-NormalizedPath -Path ([string]$item.path) -BasePath ([System.IO.Path]::GetDirectoryName($file))
                    if (Test-SamePath -PathA $resolvedItem -PathB $NormalizedSkillRoot) {
                        return [PSCustomObject]@{
                            Host       = 'antigravity'
                            Mode       = 'manifest'
                            Status     = 'already_registered'
                            TargetPath = $file
                            Added      = 0
                            Updated    = 0
                            Removed    = 0
                            Unchanged  = 1
                            Conflicts  = @()
                            Notes      = @('Existing manifest entry preserved.')
                        }
                    }
                }
            }
        }

        $snippet = $entry | ConvertTo-Json -Compress
        return [PSCustomObject]@{
            Host       = 'antigravity'
            Mode       = 'manifest'
            Status     = 'manual_append_required'
            TargetPath = $file
            Added      = 0
            Updated    = 0
            Removed    = 0
            Unchanged  = 0
            Conflicts  = @("Existing manifest preserved. Append this object to its entries array: $snippet")
            Notes      = @()
        }
    }

    $json = @{ entries = @($entry) } | ConvertTo-Json -Depth 4
    if ($Cmdlet.ShouldProcess($file, "Register $NormalizedSkillRoot in Antigravity manifest")) {
        $directory = [System.IO.Path]::GetDirectoryName($file)
        [void][System.IO.Directory]::CreateDirectory($directory)
        $temporary = Join-Path $directory ([System.IO.Path]::GetRandomFileName())
        try {
            [System.IO.File]::WriteAllText($temporary, $json + [System.Environment]::NewLine)
            [System.IO.File]::Move($temporary, $file)
        } finally {
            if ([System.IO.File]::Exists($temporary)) {
                [System.IO.File]::Delete($temporary)
            }
        }
    }

    return [PSCustomObject]@{
        Host       = 'antigravity'
        Mode       = 'manifest'
        Status     = 'registered'
        TargetPath = $file
        Added      = 1
        Updated    = 0
        Removed    = 0
        Unchanged  = 0
        Conflicts  = @()
        Notes      = @('Registered SkillRoot in Antigravity manifest.')
    }
}

function Inspect-NativeHost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        [Parameter(Mandatory = $true)]
        [string]$ShadowSkillsDir,
        [Parameter(Mandatory = $true)]
        [string[]]$ActiveSkillNames,
        [string[]]$ExtraNotes = @()
    )

    $notes = New-Object System.Collections.Generic.List[string]
    foreach ($n in $ExtraNotes) {
        if (-not [string]::IsNullOrWhiteSpace($n)) { $notes.Add($n) }
    }

    $conflicts = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($ShadowSkillsDir) -and (Test-Path -LiteralPath $ShadowSkillsDir -PathType Container)) {
        $shadowDirs = @(Get-ChildItem -LiteralPath $ShadowSkillsDir -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne '.system' -and ($ActiveSkillNames -contains $_.Name) })
        foreach ($sd in $shadowDirs) {
            $conflicts.Add("Host-specific skill '$($sd.FullName)' shares name with global skill '$($sd.Name)' and may shadow it.")
        }
    }

    return [PSCustomObject]@{
        Host       = $HostName
        Mode       = 'native-agents-skills'
        Status     = if ($conflicts.Count -gt 0) { 'native_with_shadows' } else { 'native_ready' }
        TargetPath = $ShadowSkillsDir
        Added      = 0
        Updated    = 0
        Removed    = 0
        Unchanged  = $ActiveSkillNames.Count
        Conflicts  = @($conflicts)
        Notes      = @($notes)
    }
}

# --- Resolve paths ---
$resolvedHome = Get-NormalizedPath -Path $HomeDir
if ([string]::IsNullOrWhiteSpace($SkillRoot)) {
    $SkillRoot = Join-Path $resolvedHome '.agents/skills'
}
if ([string]::IsNullOrWhiteSpace($AntigravityManifest)) {
    $AntigravityManifest = Join-Path $resolvedHome '.gemini/config/skills.json'
}

if (-not (Test-Path -LiteralPath $SkillRoot -PathType Container)) {
    throw "SkillRoot not found at '$SkillRoot'. Clone the repository to ~/.agents/skills first."
}
$root = Get-NormalizedPath -Path $SkillRoot

# --- 1. Optional git pull --ff-only ---
$pullStatus = 'skipped'
$commitShort = 'unknown'
$isGitRepo = Test-Path -LiteralPath (Join-Path $root '.git')

if ($isGitRepo) {
    if (-not $SkipPull) {
        $dirty = @(& git -C $root status --porcelain=v1 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($dirty.Count -gt 0) {
            Write-Warning "SkillRoot '$root' has uncommitted local changes:"
            $dirty | ForEach-Object { Write-Warning "  $_" }
            throw "Aborted before pulling. Keep '$root' clean or re-run with -SkipPull if intentionally testing."
        }
        if ($PSCmdlet.ShouldProcess($root, 'git pull --ff-only')) {
            $pullOutput = & git -C $root pull --ff-only 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "git pull --ff-only failed in '$root': $($pullOutput -join [Environment]::NewLine)"
            }
            $pullStatus = 'pulled'
        } else {
            $pullStatus = 'whatif_pull'
        }
    }
    $revOut = (& git -C $root rev-parse --short HEAD 2>$null) -join ''
    if (-not [string]::IsNullOrWhiteSpace($revOut)) {
        $commitShort = $revOut.Trim()
    }
} elseif (-not $SkipPull) {
    $pullStatus = 'not_a_git_repo'
}

# --- 2. Discover active top-level skills ---
$reservedDirs = @('.git', '.github', '.agents', '.codex', 'scripts')
$activeSkills = @(Get-ChildItem -LiteralPath $root -Directory |
        Where-Object { $reservedDirs -notcontains $_.Name } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
        Sort-Object Name)

if ($activeSkills.Count -eq 0) {
    throw "No top-level skills containing SKILL.md found under '$root'."
}
$activeSkillNames = @($activeSkills | ForEach-Object { $_.Name })

# --- 3. Resolve target hosts ---
$explicitMode = -not ($Hosts -contains 'auto')
$selectedHosts = New-Object System.Collections.Generic.List[string]

if ($explicitMode) {
    foreach ($h in ($Hosts | Select-Object -Unique)) {
        $selectedHosts.Add($h)
    }
} else {
    # Auto-detect installed hosts under $resolvedHome
    if (Test-Path -LiteralPath (Join-Path $resolvedHome '.codex') -PathType Container) {
        $selectedHosts.Add('codex')
    }
    if ((Test-Path -LiteralPath (Join-Path $resolvedHome '.gemini') -PathType Container) -or
        (Test-Path -LiteralPath (Join-Path $resolvedHome '.antigravity') -PathType Container) -or
        (Test-Path -LiteralPath (Join-Path $resolvedHome '.antigravity-ide') -PathType Container) -or
        [System.IO.File]::Exists($AntigravityManifest) -or
        ($null -ne (Get-Command 'agy' -ErrorAction SilentlyContinue))) {
        $selectedHosts.Add('antigravity')
    }
    if (Test-Path -LiteralPath (Join-Path $resolvedHome '.workbuddy') -PathType Container) {
        $selectedHosts.Add('workbuddy')
    }
    if (Test-Path -LiteralPath (Join-Path $resolvedHome '.codebuddy') -PathType Container) {
        $selectedHosts.Add('codebuddy')
    }
    if (Test-Path -LiteralPath (Join-Path $resolvedHome '.claude') -PathType Container) {
        $selectedHosts.Add('claude')
    }
    $dshHomeEnv = Get-UserOrProcessEnv -Name 'DSH_HOME'
    $dshAgentsEnv = Get-UserOrProcessEnv -Name 'DSH_AGENTS_HOME'
    if ((Test-Path -LiteralPath (Join-Path $resolvedHome '.dsh') -PathType Container) -or
        -not [string]::IsNullOrWhiteSpace($dshHomeEnv) -or
        -not [string]::IsNullOrWhiteSpace($dshAgentsEnv) -or
        ($null -ne (Get-Command 'dsh' -ErrorAction SilentlyContinue))) {
        $selectedHosts.Add('dsh')
    }
}

# --- 4. Execute per-host sync / inspection ---
$results = New-Object System.Collections.Generic.List[PSCustomObject]

foreach ($hostName in $selectedHosts) {
    switch ($hostName) {
        'codex' {
            $codexSkills = Join-Path $resolvedHome '.codex/skills'
            $results.Add((Inspect-NativeHost -HostName 'codex' `
                        -ShadowSkillsDir $codexSkills `
                        -ActiveSkillNames $activeSkillNames `
                        -ExtraNotes @('Codex natively scans ~/.agents/skills; ~/.codex/skills left untouched.')))
        }
        'antigravity' {
            $results.Add((Sync-AntigravityManifest -ManifestPath $AntigravityManifest `
                        -NormalizedSkillRoot $root `
                        -Cmdlet $PSCmdlet))
        }
        'workbuddy' {
            $wbSkills = Join-Path $resolvedHome '.workbuddy/skills'
            $results.Add((Sync-SkillDirectoryLinks -HostName 'workbuddy' `
                        -TargetSkillsDir $wbSkills `
                        -NormalizedSkillRoot $root `
                        -ActiveSkills $activeSkills `
                        -Cmdlet $PSCmdlet))
        }
        'codebuddy' {
            $cbSkills = Join-Path $resolvedHome '.codebuddy/skills'
            $results.Add((Sync-SkillDirectoryLinks -HostName 'codebuddy' `
                        -TargetSkillsDir $cbSkills `
                        -NormalizedSkillRoot $root `
                        -ActiveSkills $activeSkills `
                        -Cmdlet $PSCmdlet))
        }
        'claude' {
            $claudeSkills = Join-Path $resolvedHome '.claude/skills'
            $results.Add((Sync-SkillDirectoryLinks -HostName 'claude' `
                        -TargetSkillsDir $claudeSkills `
                        -NormalizedSkillRoot $root `
                        -ActiveSkills $activeSkills `
                        -Cmdlet $PSCmdlet))
        }
        'dsh' {
            $dshHome = Get-UserOrProcessEnv -Name 'DSH_HOME'
            if ([string]::IsNullOrWhiteSpace($dshHome)) {
                $dshHome = Join-Path $resolvedHome '.dsh'
            }
            $dshSkills = Join-Path $dshHome 'skills'

            if ($LinkDsh) {
                $results.Add((Sync-SkillDirectoryLinks -HostName 'dsh' `
                            -TargetSkillsDir $dshSkills `
                            -NormalizedSkillRoot $root `
                            -ActiveSkills $activeSkills `
                            -Cmdlet $PSCmdlet))
            } else {
                $extraNotes = New-Object System.Collections.Generic.List[string]
                $dshAgentsHome = Get-UserOrProcessEnv -Name 'DSH_AGENTS_HOME'
                if (-not [string]::IsNullOrWhiteSpace($dshAgentsHome)) {
                    $expectedDshSkills = Join-Path $dshAgentsHome 'skills'
                    if (-not (Test-SamePath -PathA $expectedDshSkills -PathB $root)) {
                        $extraNotes.Add("WARNING: DSH_AGENTS_HOME is set to '$dshAgentsHome' (skills at '$expectedDshSkills'), which differs from '$root'.")
                    } else {
                        $extraNotes.Add("DSH_AGENTS_HOME points to '$dshAgentsHome' (matches SkillRoot).")
                    }
                } else {
                    $extraNotes.Add('DSH natively discovers ~/.agents/skills via default DSH_AGENTS_HOME; use -LinkDsh only if your DSH build requires ~/.dsh/skills links.')
                }
                $results.Add((Inspect-NativeHost -HostName 'dsh' `
                            -ShadowSkillsDir $dshSkills `
                            -ActiveSkillNames $activeSkillNames `
                            -ExtraNotes @($extraNotes)))
            }
        }
    }
}

# --- 5. Environment health checks ---
$tibishuPath = Get-UserOrProcessEnv -Name 'TIBISHU_NOTES_PATH'
$tibishuStatus = if ([string]::IsNullOrWhiteSpace($tibishuPath)) {
    'not_set'
} elseif (Test-Path -LiteralPath $tibishuPath -PathType Container) {
    'ready'
} else {
    'path_missing'
}

$summary = [PSCustomObject]@{
    SkillRoot       = $root
    Commit          = $commitShort
    PullStatus      = $pullStatus
    SkillCount      = $activeSkills.Count
    DetectedHosts   = @($selectedHosts)
    HostResults     = @($results)
    TibishuNotesEnv = $tibishuStatus
    RefreshHints    = @(
        'Codex: start or reopen a Codex task to refresh skills.'
        'Antigravity: run /skills reload (or reopen CLI/IDE).'
        'WorkBuddy / CodeBuddy / Claude / DSH: restart client or start a new session.'
    )
}

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 6
    return
}

Write-Output "SkillRoot:  $($summary.SkillRoot)"
Write-Output "Commit:     $($summary.Commit) (Pull: $($summary.PullStatus))"
Write-Output "Skills:     $($summary.SkillCount) active top-level skills"
Write-Output "TIBISHU_NOTES_PATH: $($summary.TibishuNotesEnv)"
Write-Output ""

if ($results.Count -eq 0) {
    Write-Output "No supported host directories detected under $resolvedHome. Pass -Hosts explicitly to initialize."
} else {
    $results | Format-Table -Property Host, Mode, Status, Added, Updated, Removed, Unchanged -AutoSize | Out-String | Write-Output
    foreach ($r in $results) {
        foreach ($c in $r.Conflicts) {
            Write-Warning "[$($r.Host)] $c"
        }
        foreach ($n in $r.Notes) {
            if ($n -like 'WARNING:*') {
                Write-Warning "[$($r.Host)] $n"
            }
        }
    }
}

Write-Output "Next steps:"
foreach ($hint in $summary.RefreshHints) {
    Write-Output "- $hint"
}
