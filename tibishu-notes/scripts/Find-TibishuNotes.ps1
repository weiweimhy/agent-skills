[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query = "",

    [ValidateSet("Names", "Headers", "Content")]
    [string]$Stage = "Names",

    [string]$Root = "",

    [ValidateRange(1, 200)]
    [int]$MaxResults = 20,

    [string]$Category = "",

    [string[]]$Tag = @(),

    [switch]$ExcludeHidden
)

$ErrorActionPreference = "Stop"
$noteRootEnvironmentVariable = "TIBISHU_NOTES_PATH"

function Resolve-NoteRoot {
    $configuredRoot = $Root
    if ([string]::IsNullOrWhiteSpace($configuredRoot)) {
        $configuredRoot = [Environment]::GetEnvironmentVariable(
            $noteRootEnvironmentVariable,
            [EnvironmentVariableTarget]::Process
        )
    }
    if ([string]::IsNullOrWhiteSpace($configuredRoot)) {
        $configuredRoot = [Environment]::GetEnvironmentVariable(
            $noteRootEnvironmentVariable,
            [EnvironmentVariableTarget]::User
        )
    }
    if ([string]::IsNullOrWhiteSpace($configuredRoot)) {
        throw "未设置 $noteRootEnvironmentVariable。请在提笔书的 笔记库 → 笔记路径 中配置。"
    }
    if (-not (Test-Path -LiteralPath $configuredRoot -PathType Container)) {
        throw "笔记路径不存在或不是文件夹：$configuredRoot"
    }
    return [System.IO.Path]::GetFullPath($configuredRoot).TrimEnd("\", "/")
}

$rootFullPath = Resolve-NoteRoot
$terms = @($Query -split "\s+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$normalizedTags = @($Tag | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
$hasMetadataFilter = (-not [string]::IsNullOrWhiteSpace($Category)) -or ($normalizedTags.Count -gt 0) -or $ExcludeHidden.IsPresent

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($rootFullPath.Length).TrimStart("\", "/")
    }

    return $fullPath
}

function Test-IsExcludedPath {
    param([Parameter(Mandatory)][string]$RelativePath)

    $unixRel = $RelativePath -replace "\\", "/"
    if ($unixRel -match '(^|/)\.(git|agents|skill-staging)(/|$)') {
        return $true
    }
    if ($unixRel -ieq 'AGENTS.md') {
        return $true
    }
    return $false
}

function Get-MarkdownPaths {
    $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
    $rawPaths = @()
    if ($null -ne $ripgrep) {
        $paths = @(
            & $ripgrep.Source --files $rootFullPath -g "*.md" -g "!**/.git/**" -g "!**/.agents/**" -g "!**/.skill-staging/**" 2>$null
        )
        if ($LASTEXITCODE -eq 0) {
            $rawPaths = @($paths)
        }
    }

    if ($rawPaths.Count -eq 0) {
        $rawPaths = @(
            Get-ChildItem -LiteralPath $rootFullPath -File -Recurse -Filter "*.md" |
                ForEach-Object { $_.FullName }
        )
    }

    return @(
        $rawPaths | Where-Object {
            $rel = Get-RelativePath -Path $_
            -not (Test-IsExcludedPath -RelativePath $rel)
        }
    )
}

function Test-IsIndexFile {
    param([Parameter(Mandatory)][string]$RelativePath)

    $fileName = [System.IO.Path]::GetFileName($RelativePath)
    return ($fileName -match '^(00-|README\.md$)')
}

function Get-TextMatchScore {
    param(
        [AllowNull()][string]$Text,
        [int]$ExactScore = 1000,
        [int]$TermScore = 100
    )

    if ([string]::IsNullOrWhiteSpace($Query) -or [string]::IsNullOrWhiteSpace($Text)) {
        return 0
    }

    if ($Text.IndexOf($Query, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        return $ExactScore
    }

    $score = 0
    foreach ($term in $terms) {
        if ($Text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $score += $TermScore
        }
    }

    return $score
}

function Get-PathMatchScore {
    param([Parameter(Mandatory)][string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return 0
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($RelativePath)
    $fileScore = Get-TextMatchScore -Text $fileName -ExactScore 1200 -TermScore 150
    if ($fileScore -ge 1200) {
        return $fileScore
    }

    $pathScore = Get-TextMatchScore -Text $RelativePath -ExactScore 1000 -TermScore 100
    $best = [Math]::Max($fileScore, $pathScore)
    if ($best -gt 0 -and (Test-IsIndexFile -RelativePath $RelativePath)) {
        $best += 20
    }
    return $best
}

function Get-FrontMatter {
    param([Parameter(Mandatory)][string]$Path)

    $reader = $null
    try {
        $reader = [System.IO.StreamReader]::new($Path, [System.Text.Encoding]::UTF8, $true)
        $firstLine = $reader.ReadLine()
        if ($null -eq $firstLine -or $firstLine.Trim() -ne "---") {
            return $null
        }

        $sb = [System.Text.StringBuilder]::new()
        for ($index = 1; $index -lt 80; $index++) {
            $line = $reader.ReadLine()
            if ($null -eq $line) {
                return $null
            }
            if ($line.Trim() -eq "---") {
                return $sb.ToString().TrimEnd("`r", "`n")
            }
            [void]$sb.AppendLine($line)
        }
        return $null
    }
    finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
    }
}

function Get-YamlFieldRaw {
    param(
        [AllowNull()][string]$FrontMatter,
        [Parameter(Mandatory)][string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($FrontMatter)) {
        return ""
    }

    $escapedName = [regex]::Escape($Name)
    $pattern = '(?ms)^(?:"{0}"|''{0}''|{0}):\s*(?<value>.*?)(?=^(?:"[A-Za-z0-9_-]+"|''[A-Za-z0-9_-]+''|[A-Za-z0-9_-]+):\s*|\z)' -f $escapedName
    $match = [regex]::Match($FrontMatter, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups["value"].Value.Trim()
}

function Parse-YamlStringList {
    param([AllowNull()][string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return @() }
    $trimmed = $Raw.Trim()
    if ($trimmed -eq '[]') { return @() }

    $items = [System.Collections.Generic.List[string]]::new()
    if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
        $inner = $trimmed.Substring(1, $trimmed.Length - 2)
        foreach ($part in ($inner -split ',')) {
            $val = $part.Trim().Trim([char[]]@('"', "'"))
            if (-not [string]::IsNullOrWhiteSpace($val)) { $items.Add($val) }
        }
        return @($items)
    }

    foreach ($line in ($trimmed -split '\r?\n')) {
        if ($line -match '^\s*-\s*(.+?)\s*$') {
            $val = $Matches[1].Trim().Trim([char[]]@('"', "'"))
            if (-not [string]::IsNullOrWhiteSpace($val)) { $items.Add($val) }
        }
    }
    return @($items)
}

function Get-ParsedHeader {
    param([Parameter(Mandatory)][string]$Path)

    $fm = Get-FrontMatter -Path $Path
    $title = (Get-YamlFieldRaw -FrontMatter $fm -Name "title").Trim([char[]]@('"', "'"))
    $date = (Get-YamlFieldRaw -FrontMatter $fm -Name "date").Trim([char[]]@('"', "'"))
    $description = (Get-YamlFieldRaw -FrontMatter $fm -Name "description").Trim([char[]]@('"', "'"))
    $categories = @(Parse-YamlStringList -Raw (Get-YamlFieldRaw -FrontMatter $fm -Name "categories"))
    $tags = @(Parse-YamlStringList -Raw (Get-YamlFieldRaw -FrontMatter $fm -Name "tags"))
    $hiddenRaw = (Get-YamlFieldRaw -FrontMatter $fm -Name "hidden").Trim([char[]]@('"', "'"))
    $draftRaw = (Get-YamlFieldRaw -FrontMatter $fm -Name "draft").Trim([char[]]@('"', "'"))

    return [PSCustomObject]@{
        Raw         = $fm
        Title       = $title
        Date        = $date
        Description = $description
        Categories  = $categories
        Tags        = $tags
        Hidden      = ($hiddenRaw -ieq 'true')
        Draft       = ($draftRaw -ieq 'true')
    }
}

function Test-MatchesMetadataFilter {
    param([Parameter(Mandatory)][pscustomobject]$Header)

    if ($ExcludeHidden.IsPresent -and $Header.Hidden) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $catHit = @($Header.Categories | Where-Object { $_ -ieq $Category.Trim() }).Count -gt 0
        if (-not $catHit) {
            return $false
        }
    }

    foreach ($reqTag in $normalizedTags) {
        $tagHit = @($Header.Tags | Where-Object { $_ -ieq $reqTag }).Count -gt 0
        if (-not $tagHit) {
            return $false
        }
    }

    return $true
}

function Get-HeaderMatchScore {
    param([Parameter(Mandatory)][pscustomobject]$Header)

    if ([string]::IsNullOrWhiteSpace($Query) -or [string]::IsNullOrWhiteSpace($Header.Raw)) {
        return 0
    }

    $score = 0
    $score += Get-TextMatchScore -Text $Header.Title -ExactScore 600 -TermScore 120
    $score += Get-TextMatchScore -Text $Header.Description -ExactScore 300 -TermScore 80

    foreach ($cat in $Header.Categories) {
        if ($cat -ieq $Query) {
            $score += 500
        }
        else {
            foreach ($term in $terms) {
                if ($cat -ieq $term) { $score += 250 }
            }
        }
    }

    foreach ($t in $Header.Tags) {
        if ($t -ieq $Query) {
            $score += 500
        }
        else {
            foreach ($term in $terms) {
                if ($t -ieq $term) { $score += 250 }
            }
        }
    }

    if ($score -eq 0) {
        $score = Get-TextMatchScore -Text $Header.Raw -ExactScore 200 -TermScore 50
    }

    return $score
}

function Select-Results {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results)

    return @(
        $Results |
            Sort-Object -Property @{ Expression = "Score"; Descending = $true }, Path |
            Select-Object -First $MaxResults
    )
}

$allPaths = @(Get-MarkdownPaths | Sort-Object)

switch ($Stage) {
    "Names" {
        $results = foreach ($path in $allPaths) {
            $relativePath = Get-RelativePath -Path $path
            $score = Get-PathMatchScore -RelativePath $relativePath
            if (-not [string]::IsNullOrWhiteSpace($Query) -and $score -eq 0) {
                continue
            }

            if ($hasMetadataFilter) {
                $header = Get-ParsedHeader -Path $path
                if (-not (Test-MatchesMetadataFilter -Header $header)) {
                    continue
                }
            }

            if ([string]::IsNullOrWhiteSpace($Query) -and (Test-IsIndexFile -RelativePath $relativePath)) {
                $score += 20
            }

            [PSCustomObject]@{
                Stage = "name"
                Score = $score
                Path  = $relativePath
            }
        }
        Select-Results -Results @($results)
        break
    }

    "Headers" {
        $results = foreach ($path in $allPaths) {
            $relativePath = Get-RelativePath -Path $path
            $header = Get-ParsedHeader -Path $path
            if ($hasMetadataFilter -and (-not (Test-MatchesMetadataFilter -Header $header))) {
                continue
            }

            $nameScore = Get-PathMatchScore -RelativePath $relativePath
            $headerScore = Get-HeaderMatchScore -Header $header
            $totalScore = $nameScore + $headerScore

            if (-not [string]::IsNullOrWhiteSpace($Query) -and $totalScore -eq 0) {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($Query) -and (Test-IsIndexFile -RelativePath $relativePath)) {
                $totalScore += 20
            }

            $scopeLabel = if ($nameScore -gt 0 -and $headerScore -gt 0) {
                "name + header"
            } elseif ($nameScore -gt 0) {
                "filename matches"
            } elseif ($hasMetadataFilter -and [string]::IsNullOrWhiteSpace($Query)) {
                "filtered headers"
            } else {
                "all note headers"
            }

            [PSCustomObject]@{
                Stage       = "header"
                Scope       = $scopeLabel
                Score       = $totalScore
                Path        = $relativePath
                Title       = $header.Title
                Date        = $header.Date
                Categories  = ($header.Categories -join ", ")
                Tags        = ($header.Tags -join ", ")
                Hidden      = $header.Hidden
                Draft       = $header.Draft
                Description = $header.Description
            }
        }
        Select-Results -Results @($results)
        break
    }

    "Content" {
        if ([string]::IsNullOrWhiteSpace($Query)) {
            throw "Content search requires -Query."
        }

        $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
        $hits = @()
        [string[]]$searchTerms = if ($terms.Count -gt 0) { @($terms) } else { @($Query) }

        if ($null -ne $ripgrep) {
            $firstTerm = [string]$searchTerms[0]
            $currentHits = @(
                & $ripgrep.Source --ignore-case --files-with-matches --glob "*.md" --glob "!**/.git/**" --glob "!**/.agents/**" --glob "!**/.skill-staging/**" --fixed-strings -e $firstTerm $rootFullPath 2>$null
            )
            if ($LASTEXITCODE -gt 1) {
                throw "ripgrep failed while searching note bodies."
            }

            $currentHits = @(
                $currentHits | Where-Object {
                    -not (Test-IsExcludedPath -RelativePath (Get-RelativePath -Path $_))
                }
            )

            for ($i = 1; $i -lt $searchTerms.Count -and $currentHits.Count -gt 0; $i++) {
                $nextTerm = [string]$searchTerms[$i]
                $nextHits = @(
                    & $ripgrep.Source --ignore-case --files-with-matches --fixed-strings -e $nextTerm @currentHits 2>$null
                )
                if ($LASTEXITCODE -gt 1) {
                    throw "ripgrep failed while intersecting multi-term content search."
                }
                $currentHits = @($nextHits)
            }
            $hits = @($currentHits)
        }
        else {
            $currentHits = @($allPaths)
            foreach ($term in $searchTerms) {
                if ($currentHits.Count -eq 0) { break }
                $currentHits = @(
                    $currentHits | Where-Object {
                        $null -ne (Select-String -LiteralPath $_ -SimpleMatch -CaseSensitive:$false -Pattern $term -List)
                    }
                )
            }
            $hits = @($currentHits)
        }

        $results = foreach ($hit in $hits) {
            $relativePath = Get-RelativePath -Path $hit
            if ($hasMetadataFilter) {
                $header = Get-ParsedHeader -Path $hit
                if (-not (Test-MatchesMetadataFilter -Header $header)) {
                    continue
                }
            }

            $score = 1000 + (Get-PathMatchScore -RelativePath $relativePath)
            [PSCustomObject]@{
                Stage = "content"
                Score = $score
                Path  = $relativePath
            }
        }
        Select-Results -Results @($results)
    }
}
