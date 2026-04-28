function Get-SkillFrontmatter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $content = Get-Content $Path -Raw
    $match = [regex]::Match($content, '(?s)^---\r?\n(.*?)\r?\n---\r?\n?')
    if (-not $match.Success) {
        throw "Missing frontmatter: $Path"
    }

    $frontmatterText = $match.Groups[1].Value
    $body = $content.Substring($match.Length)
    $data = [ordered]@{}
    $currentArrayKey = $null

    foreach ($line in ($frontmatterText -split '\r?\n')) {
        if ($line -match '^([a-z_]+):\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            if ([string]::IsNullOrWhiteSpace($value)) {
                $data[$key] = @()
                $currentArrayKey = $key
            } else {
                $data[$key] = $value.Trim()
                $currentArrayKey = $null
            }
            continue
        }

        if ($line -match '^\s*-\s+(.+)$' -and $null -ne $currentArrayKey) {
            $items = @($data[$currentArrayKey])
            $items += $Matches[1].Trim()
            $data[$currentArrayKey] = $items
        }
    }

    $absoluteRoot = (Resolve-Path $RepoRoot).Path
    $relativePath = (Resolve-Path $Path).Path.Substring($absoluteRoot.Length + 1).Replace('\', '/')
    if ($data.Contains("slug")) {
        $slug = $data["slug"]
    } else {
        $slug = [System.IO.Path]::GetFileName((Split-Path $Path -Parent))
    }
    $strippedBody = [regex]::Replace($body, '(?ms)```.*?```', '')

    return [pscustomobject]@{
        Path = $Path
        RelativePath = $relativePath
        Frontmatter = $data
        Body = $body
        StrippedBody = $strippedBody
        Slug = $slug
    }
}

function Get-SkillFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    Get-ChildItem -Path $RepoRoot -Recurse -Filter "SKILL.md" | Sort-Object FullName
}

function Get-SkillCategoryMeta {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    switch ($Category) {
        "workflow" { return @{ Title = "Core Skills"; Emoji = "🧠"; Description = "通用流程与协作技能" } }
        "backend"  { return @{ Title = "Backend Skills"; Emoji = "🧩"; Description = "后端架构、接口与数据层技能" } }
        "frontend" { return @{ Title = "Frontend Skills"; Emoji = "🎨"; Description = "前端框架与界面工程技能" } }
        "language" { return @{ Title = "Language Skills"; Emoji = "🐹"; Description = "语言专项审查与地道实践技能" } }
        "ai"       { return @{ Title = "AI Skills"; Emoji = "🤖"; Description = "AI 辅助、提示词与文档生成技能" } }
        "utility"  { return @{ Title = "Utility Skills"; Emoji = "🔧"; Description = "工具类与仓库维护技能" } }
        default    { return @{ Title = "Other Skills"; Emoji = "📦"; Description = "未分类技能" } }
    }
}

function Get-SkillRoleLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Role
    )

    switch ($Role) {
        "entrypoint" { return "入口" }
        "workflow"   { return "流程" }
        "specialist" { return "专项" }
        default      { return $Role }
    }
}

function Get-SkillCategoryOrder {
    return @("workflow", "backend", "frontend", "language", "ai", "utility")
}
