param(
    [string]$Root = ".",
    [int]$SoftLineLimit = 120,
    [int]$HardLineLimit = 220
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path $Root).Path
$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$reservedDirs = @(".git", ".github", ".agents", ".codex", "scripts")
$skillFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "SKILL.md" | Sort-Object FullName

if ($skillFiles.Count -eq 0) {
    $issues.Add("No SKILL.md files found.")
}

$personalPathPattern = '(?<![A-Za-z0-9_])(?:[A-Za-z]:\\{1,2}[^\s"''`]+|/(?:Users|home)/[^\s"''`]+)'
$discoveredSkills = New-Object System.Collections.Generic.List[string]

foreach ($file in $skillFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
    $parent = Split-Path $file.FullName -Parent
    $skillName = Split-Path $parent -Leaf

    if ((Split-Path $parent -Parent) -ne $repoRoot) {
        $issues.Add("${relative}: skill must live at <skill-name>/SKILL.md")
    } else {
        $discoveredSkills.Add($skillName)
    }

    if ($reservedDirs -contains $skillName) {
        $issues.Add("${relative}: skill directory uses reserved name '$skillName'")
    }

    $match = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---\r?\n?')
    if (-not $match.Success) {
        $issues.Add("${relative}: missing YAML frontmatter")
        continue
    }

    $frontmatterText = $match.Groups[1].Value
    $keys = New-Object System.Collections.Generic.List[string]
    $values = @{}

    foreach ($line in ($frontmatterText -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -notmatch '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            $issues.Add("${relative}: unsupported frontmatter line '$line'")
            continue
        }
        $key = $Matches[1]
        $value = $Matches[2].Trim()
        $keys.Add($key)
        if ($value -match '^"(.*)"(?:\s+#.*)?$' -or $value -match "^'(.*)'(?:\s+#.*)?$") {
            $value = $Matches[1]
        } elseif ($value -match '^(?:#.*|(?:~|null)(?:\s+#.*)?)$') {
            $value = ''
        }
        $values[$key] = $value
    }

    foreach ($required in @("name", "description")) {
        if (-not $values.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($values[$required])) {
            $issues.Add("${relative}: missing required frontmatter key '$required'")
        }
    }

    foreach ($key in $keys) {
        if ($key -notin @("name", "description")) {
            $issues.Add("${relative}: unsupported frontmatter key '$key'; official skills should only use name and description")
        }
    }

    if ($values.ContainsKey("name") -and $values["name"] -ne $skillName) {
        $issues.Add("${relative}: name '$($values["name"])' must match directory '$skillName'")
    }

    if ($values.ContainsKey("name") -and $values["name"] -notmatch '^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$') {
        $issues.Add("${relative}: name must be kebab-case and under 64 characters")
    }

    if ($content.Substring($match.Length) -notmatch '(?m)^#\s+') {
        $issues.Add("${relative}: missing top-level heading")
    }

    # Size budget check to prevent prompt bloat
    $lineCount = ($content -split '\r?\n').Count
    if ($lineCount -gt $HardLineLimit) {
        $issues.Add("${relative}: has $lineCount lines (hard limit: $HardLineLimit). Move detailed rules into references/.")
    } elseif ($lineCount -gt $SoftLineLimit) {
        $warnings.Add("${relative}: has $lineCount lines (soft budget: $SoftLineLimit). Consider moving details to references/.")
    }

    # Check SKILL.md and optional agents/*.yaml for hardcoded personal paths
    $filesToScan = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $filesToScan.Add($file)
    $agentsDir = Join-Path $parent "agents"
    if (Test-Path -LiteralPath $agentsDir -PathType Container) {
        Get-ChildItem -LiteralPath $agentsDir -File -Filter "*.yaml" | ForEach-Object { $filesToScan.Add($_) }
    }
    foreach ($scanFile in $filesToScan) {
        $scanRel = $scanFile.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
        $scanText = Get-Content -LiteralPath $scanFile.FullName -Raw
        $pathMatches = [regex]::Matches($scanText, $personalPathPattern)
        foreach ($pm in $pathMatches) {
            $issues.Add("${scanRel}: hardcoded personal/absolute path detected ('$($pm.Value)')")
        }
    }
}

$topLevelSkillDirs = Get-ChildItem -Path $repoRoot -Directory |
    Where-Object { $reservedDirs -notcontains $_.Name } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") }

foreach ($dir in $topLevelSkillDirs) {
    if ($dir.Name -notmatch '^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$') {
        $issues.Add("$($dir.Name): skill directory must be kebab-case and under 64 characters")
    }
}

# Verify SKILLS.md inventory stays in sync with top-level skill directories
$inventoryPath = Join-Path $repoRoot "SKILLS.md"
if (Test-Path -LiteralPath $inventoryPath -PathType Leaf) {
    $inventoryLines = Get-Content -LiteralPath $inventoryPath
    $listedSkills = New-Object System.Collections.Generic.List[string]
    foreach ($line in $inventoryLines) {
        if ($line -match '^##\s+Not Included By Default') {
            break
        }
        if ($line -match '^\-\s+`([a-z0-9-]+)`\s+-') {
            $listedSkills.Add($Matches[1])
        }
    }

    $actualSet = @($discoveredSkills | Sort-Object -Unique)
    $listedSet = @($listedSkills | Sort-Object -Unique)
    foreach ($skill in $actualSet) {
        if ($listedSet -notcontains $skill) {
            $issues.Add("SKILLS.md: missing active skill '$skill'")
        }
    }
    foreach ($listed in $listedSet) {
        if ($actualSet -notcontains $listed) {
            $issues.Add("SKILLS.md: lists '$listed' which has no matching <skill>/SKILL.md")
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Output "Skill validation warnings:"
    $warnings | ForEach-Object { Write-Output "- $_" }
}

if ($issues.Count -gt 0) {
    Write-Output "Skill validation failed:"
    $issues | ForEach-Object { Write-Output "- $_" }
    exit 1
}

Write-Output "Skill validation passed ($($skillFiles.Count) files checked)."
