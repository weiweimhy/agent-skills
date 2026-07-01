param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path $Root).Path
. (Join-Path $repoRoot "scripts/skills-lib.ps1")

$skills = Get-SkillFiles -RepoRoot $repoRoot | ForEach-Object {
    Get-SkillFrontmatter -Path $_.FullName -RepoRoot $repoRoot
}

$outputPath = Join-Path $repoRoot "SKILLS.md"
[System.IO.File]::WriteAllText($outputPath, (New-SkillIndexContent -Skills $skills), [System.Text.UTF8Encoding]::new($false))
Write-Output "Generated $outputPath"
