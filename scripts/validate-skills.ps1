param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path $Root).Path
$issues = New-Object System.Collections.Generic.List[string]
$reservedDirs = @(".git", ".github", ".agents", ".codex", "scripts")
$skillFiles = Get-ChildItem -Path $repoRoot -Recurse -Filter "SKILL.md" | Sort-Object FullName

if ($skillFiles.Count -eq 0) {
    $issues.Add("No SKILL.md files found.")
}

foreach ($file in $skillFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
    $parent = Split-Path $file.FullName -Parent
    $skillName = Split-Path $parent -Leaf

    if ((Split-Path $parent -Parent) -ne $repoRoot) {
        $issues.Add("${relative}: skill must live at <skill-name>/SKILL.md")
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

    if ($values.ContainsKey("description") -and $values["description"].Length -lt 80) {
        $issues.Add("${relative}: description should be specific enough for Codex routing")
    }

    if ($content.Substring($match.Length) -notmatch '(?m)^#\s+') {
        $issues.Add("${relative}: missing top-level heading")
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

if ($issues.Count -gt 0) {
    Write-Output "Skill validation failed:"
    $issues | ForEach-Object { Write-Output "- $_" }
    exit 1
}

Write-Output "Skill validation passed ($($skillFiles.Count) files checked)."
