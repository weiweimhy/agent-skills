[CmdletBinding()]
param(
    [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$helperPath = Join-Path $PSScriptRoot "Find-TibishuNotes.ps1"
$tempParentPath = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd(
    [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
)
$pathComparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}

function Resolve-SafeFixturePath {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $requiredPrefix = "$tempParentPath$([System.IO.Path]::DirectorySeparatorChar)"
    if (-not $resolvedPath.StartsWith($requiredPrefix, $pathComparison)) {
        throw "Temporary fixture path is outside the expected temp parent."
    }

    return $resolvedPath
}

$fixtureRoot = Resolve-SafeFixturePath -Path (Join-Path $tempParentPath "tibishu-note-search-regression-$([guid]::NewGuid().ToString('N'))")
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null

function Write-FixtureNote {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Content
    )

    $path = Join-Path $fixtureRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding utf8
}

function Invoke-Search {
    param(
        [Parameter(Mandatory)][ValidateSet("Names", "Headers", "Content")][string]$Stage,
        [AllowEmptyString()][string]$Query = "",
        [string]$Root = "",
        [string]$Category = "",
        [string[]]$Tag = @(),
        [switch]$ExcludeHidden
    )

    try {
        $searchRoot = if ([string]::IsNullOrWhiteSpace($Root)) { $fixtureRoot } else { $Root }
        $params = @{
            Root  = $searchRoot
            Stage = $Stage
            Query = $Query
        }
        if (-not [string]::IsNullOrWhiteSpace($Category)) { $params.Category = $Category }
        if ($Tag.Count -gt 0) { $params.Tag = $Tag }
        if ($ExcludeHidden.IsPresent) { $params.ExcludeHidden = $true }
        return @(& $helperPath @params)
    } catch {
        throw "${Stage} search for '$Query' failed: $($_.Exception.Message)"
    }
}

function Assert-ResultPaths {
    param(
        [Parameter(Mandatory)][string]$Case,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory)][int]$ExpectedCount,
        [string[]]$ExpectedPaths = @()
    )

    if ($Rows.Count -ne $ExpectedCount) {
        throw "$Case expected $ExpectedCount result(s), got $($Rows.Count). Actual: $(($Rows | ForEach-Object { $_.Path }) -join ', ')"
    }

    $actualPaths = @($Rows | ForEach-Object { ([string]$_.Path) -replace "\\", "/" })
    foreach ($expectedPath in $ExpectedPaths) {
        $normalizedExpectedPath = $expectedPath -replace "\\", "/"
        if (@($actualPaths | Where-Object { $_ -eq $normalizedExpectedPath }).Count -ne 1) {
            throw "$Case did not return expected path '$expectedPath' exactly once. Actual: $($actualPaths -join ', ')"
        }
    }
}

function Assert-Properties {
    param(
        [Parameter(Mandatory)][string]$Case,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory)][string[]]$ExpectedProperties
    )

    foreach ($row in $Rows) {
        $actual = @($row.PSObject.Properties.Name | Sort-Object)
        $expected = @($ExpectedProperties | Sort-Object)
        if (Compare-Object -ReferenceObject $expected -DifferenceObject $actual) {
            throw "$Case changed the output properties: $($actual -join ', ')."
        }
    }
}

try {
    Write-FixtureNote -RelativePath "AGENTS.md" -Content @'
# Repo AGENTS should be excluded from note search
BodyOnlyMarker Nginx SELinux
'@
    Write-FixtureNote -RelativePath ".agents/skills/demo/SKILL.md" -Content @'
---
name: demo
description: Should never appear in note search
---
BodyOnlyMarker Atlas
'@
    Write-FixtureNote -RelativePath "Projects/00-目录.md" -Content @'
---
title: "Projects Index"
date: "2026-03-01"
hidden: true
draft: false
categories:
  - "项目实践"
tags:
  - "目录"
description: "Projects index"
---
Index page.
'@
    Write-FixtureNote -RelativePath "Projects/Alpha Guide.md" -Content @'
---
title: "Alpha Guide"
date: "2026-01-02"
hidden: false
draft: false
categories:
  - "项目实践"
tags:
  - "Go"
  - "故障复盘"
description: "SharedHeader for alpha"
---
ContentSharedMarker appears in this guide.
Line two mentions Nginx reverse proxy.
Line five resolves SELinux permission denial.
'@
    Write-FixtureNote -RelativePath "Projects/Beta Guide.md" -Content @'
---
title: "Beta Guide"
date: "2026-02-03"
hidden: false
draft: true
categories:
  - "项目实践"
tags:
  - "Lua"
  - "故障复盘"
description: "SharedHeader for beta"
---
ContentSharedMarker appears in this guide too.
Only mentions Nginx without the other keyword.
'@
    Write-FixtureNote -RelativePath "Research/Atlas Network.md" -Content @'
---
title: "HeaderOnly Atlas"
date: "2026-03-04"
hidden: false
draft: false
categories:
  - "技术经验"
tags:
  - "Lua"
description: "Atlas metadata"
---
BodyOnlyMarker appears only in this note.
'@
    Write-FixtureNote -RelativePath "Standards/01-AGENTS模板.md" -Content @'
---
title: "AGENTS Template"
date: "2026-03-05"
hidden: false
draft: false
categories:
  - "工程开发规范"
tags:
  - "AGENTS"
description: "Subfolder AGENTS note must remain searchable"
---
Subfolder AGENTS note body.
'@
    Write-FixtureNote -RelativePath "Misc/Plain Note.md" -Content @'
Plain text without front matter.
'@

    # 1. 基础 Names / Headers / Content 契约测试
    $nameZero = @(Invoke-Search -Stage Names -Query "NoFilenameMatchNeedle")
    Assert-ResultPaths -Case "Names zero-match" -Rows $nameZero -ExpectedCount 0

    $nameOne = @(Invoke-Search -Stage Names -Query "Atlas")
    Assert-ResultPaths -Case "Names one-match" -Rows $nameOne -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Names output contract" -Rows $nameOne -ExpectedProperties @("Stage", "Score", "Path")

    $nameMany = @(Invoke-Search -Stage Names -Query "Guide")
    Assert-ResultPaths -Case "Names multi-match" -Rows $nameMany -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    # 2. 排除 .agents/ 与根 AGENTS.md，但保留子目录 AGENTS 笔记
    $agentsSearch = @(Invoke-Search -Stage Names -Query "AGENTS")
    Assert-ResultPaths -Case "Exclude root AGENTS but keep subfolder" -Rows $agentsSearch -ExpectedCount 1 -ExpectedPaths @("Standards/01-AGENTS模板.md")
    $skillSearch = @(Invoke-Search -Stage Names -Query "SKILL")
    Assert-ResultPaths -Case "Exclude .agents directory" -Rows $skillSearch -ExpectedCount 0

    # 3. 入口文件在同目录查询中置顶
    $projectsList = @(Invoke-Search -Stage Names -Query "Projects")
    if ((($projectsList[0].Path) -replace "\\", "/") -ne "Projects/00-目录.md") {
        throw "Index note should rank first for directory query, got $($projectsList[0].Path)"
    }

    # 4. Headers 新输出契约与无遮蔽测试（同名+同标签全部命中）
    $headerZero = @(Invoke-Search -Stage Headers -Query "NoHeaderMatchNeedle")
    Assert-ResultPaths -Case "Headers zero-match" -Rows $headerZero -ExpectedCount 0

    $headerOneByName = @(Invoke-Search -Stage Headers -Query "Atlas")
    Assert-ResultPaths -Case "Headers one filename match" -Rows $headerOneByName -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Headers output contract" -Rows $headerOneByName -ExpectedProperties @("Stage", "Scope", "Score", "Path", "Title", "Date", "Categories", "Tags", "Hidden", "Draft", "Description")
    if ($headerOneByName[0].Title -ne "HeaderOnly Atlas" -or $headerOneByName[0].Categories -ne "技术经验" -or $headerOneByName[0].Tags -ne "Lua") {
        throw "Headers metadata fields did not parse as expected."
    }

    # 文件名含 Guide 与无文件名匹配时的 Header 融合测试
    Write-FixtureNote -RelativePath "Columns/Lua Guide.md" -Content @'
---
title: "Lua Guide"
date: "2026-03-06"
hidden: false
draft: false
categories:
  - "技术专栏"
  - "Lua 源码"
tags:
  - "Lua"
description: "Lua filename and tag match"
---
Lua body.
'@
    $luaHeaders = @(Invoke-Search -Stage Headers -Query "Lua")
    Assert-ResultPaths -Case "Headers unshadowed tag matches" -Rows $luaHeaders -ExpectedCount 3 -ExpectedPaths @("Columns/Lua Guide.md", "Projects/Beta Guide.md", "Research/Atlas Network.md")
    if ((($luaHeaders[0].Path) -replace "\\", "/") -ne "Columns/Lua Guide.md") {
        throw "Filename + tag match should rank highest in Headers, got $($luaHeaders[0].Path)"
    }

    $headerManyFallback = @(Invoke-Search -Stage Headers -Query "SharedHeader")
    Assert-ResultPaths -Case "Headers multiple fallback matches" -Rows $headerManyFallback -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    # 5. 结构化过滤测试（-Category, -Tag 多值交集, -ExcludeHidden）
    $catAndTag = @(Invoke-Search -Stage Headers -Category "项目实践" -Tag @("Go", "故障复盘"))
    Assert-ResultPaths -Case "Filter by Category + multi Tag" -Rows $catAndTag -ExpectedCount 1 -ExpectedPaths @("Projects/Alpha Guide.md")

    $catNoHidden = @(Invoke-Search -Stage Headers -Category "项目实践" -ExcludeHidden)
    Assert-ResultPaths -Case "Filter by Category + ExcludeHidden" -Rows $catNoHidden -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    $namesWithTag = @(Invoke-Search -Stage Names -Tag @("Lua"))
    Assert-ResultPaths -Case "Names stage supports -Tag filter" -Rows $namesWithTag -ExpectedCount 3 -ExpectedPaths @("Columns/Lua Guide.md", "Projects/Beta Guide.md", "Research/Atlas Network.md")

    # 6. Content 阶段单短语与多词空格 AND 检索测试（同时验证排除 AGENTS.md 与 .agents/）
    $contentZero = @(Invoke-Search -Stage Content -Query "ContentNeverPresentNeedle")
    Assert-ResultPaths -Case "Content zero-match" -Rows $contentZero -ExpectedCount 0

    $contentOne = @(Invoke-Search -Stage Content -Query "BodyOnlyMarker")
    Assert-ResultPaths -Case "Content one-match excludes AGENTS/.agents" -Rows $contentOne -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Content output contract" -Rows $contentOne -ExpectedProperties @("Stage", "Score", "Path")

    $contentMultiTerm = @(Invoke-Search -Stage Content -Query "Nginx SELinux")
    Assert-ResultPaths -Case "Content multi-term AND match" -Rows $contentMultiTerm -ExpectedCount 1 -ExpectedPaths @("Projects/Alpha Guide.md")

    $contentWithTag = @(Invoke-Search -Stage Content -Query "ContentSharedMarker" -Tag @("Lua"))
    Assert-ResultPaths -Case "Content with Tag filter" -Rows $contentWithTag -ExpectedCount 1 -ExpectedPaths @("Projects/Beta Guide.md")

    # 7. 空库兜底测试
    $emptyRoot = Join-Path $fixtureRoot "EmptyLibrary"
    New-Item -ItemType Directory -Path $emptyRoot | Out-Null
    foreach ($stage in @("Names", "Headers", "Content")) {
        $emptyLibraryResults = @(Invoke-Search -Stage $stage -Query "NoMatchNeedle" -Root $emptyRoot)
        Assert-ResultPaths -Case "$stage empty-library" -Rows $emptyLibraryResults -ExpectedCount 0
    }

    [pscustomobject]@{
        Result = "PASS"
    }
} finally {
    if ($KeepFixture) {
        Write-Output "Fixture kept at: $fixtureRoot"
    } elseif (Test-Path -LiteralPath $fixtureRoot) {
        $safeFixturePath = Resolve-SafeFixturePath -Path $fixtureRoot
        Remove-Item -LiteralPath $safeFixturePath -Recurse -Force
    }
}
