[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query = "",

    [ValidateSet("Names", "Headers", "Content")]
    [string]$Stage = "Names",

    [string]$Root = "",

    [ValidateRange(1, 200)]
    [int]$MaxResults = 20
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

function Get-MarkdownPaths {
    $ripgrep = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $ripgrep) {
        $paths = @(
            & $ripgrep.Source --files $rootFullPath -g "*.md" -g "!**/.git/**" 2>$null
        )
        if ($LASTEXITCODE -eq 0) {
            return @($paths)
        }
    }

    return @(
        Get-ChildItem -LiteralPath $rootFullPath -File -Recurse -Filter "*.md" |
            ForEach-Object { $_.FullName }
    )
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($rootFullPath.Length).TrimStart("\", "/")
    }

    return $fullPath
}

function Get-MatchScore {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return 0
    }

    if ($Text.IndexOf($Query, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        return 1000
    }

    $score = 0
    foreach ($term in $terms) {
        if ($Text.IndexOf($term, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $score += 100
        }
    }

    return $score
}

function Get-NameMatches {
    param([Parameter(Mandatory)][string[]]$Paths)

    foreach ($path in $Paths) {
        $relativePath = Get-RelativePath -Path $path
        $score = Get-MatchScore -Text $relativePath
        if ([string]::IsNullOrWhiteSpace($Query) -or $score -gt 0) {
            [PSCustomObject]@{
                Path  = $path
                Name  = $relativePath
                Score = $score
            }
        }
    }
}

function Get-FrontMatter {
    param([Parameter(Mandatory)][string]$Path)

    $lines = @(Get-Content -LiteralPath $Path -TotalCount 80)
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne "---") {
        return $null
    }

    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq "---") {
            return ($lines[0..$index] -join "`n")
        }
    }

    return $null
}

function Get-FrontMatterValue {
    param(
        [AllowNull()][string]$FrontMatter,
        [Parameter(Mandatory)][string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($FrontMatter)) {
        return ""
    }

    $escapedName = [regex]::Escape($Name)
    $pattern = "(?m)^{0}\s*:\s*(?<value>.+?)\s*$" -f $escapedName
    $match = [regex]::Match($FrontMatter, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups["value"].Value.Trim().Trim('"').Trim("'")
}

function Select-Results {
    param([Parameter(Mandatory)][object[]]$Results)

    return @(
        $Results |
            Sort-Object -Property @{ Expression = "Score"; Descending = $true }, Name |
            Select-Object -First $MaxResults
    )
}

$allPaths = @(Get-MarkdownPaths | Sort-Object)
$nameMatches = @(Get-NameMatches -Paths $allPaths)

switch ($Stage) {
    "Names" {
        $results = foreach ($match in $nameMatches) {
            [PSCustomObject]@{
                Stage = "name"
                Score = $match.Score
                Path  = $match.Name
            }
        }
        Select-Results -Results @($results)
        break
    }

    "Headers" {
        $scope = $nameMatches
        $scopeLabel = "filename matches"
        if ($scope.Count -eq 0) {
            $scope = foreach ($path in $allPaths) {
                [PSCustomObject]@{
                    Path  = $path
                    Name  = Get-RelativePath -Path $path
                    Score = 0
                }
            }
            $scopeLabel = "all note headers"
        }

        $results = foreach ($candidate in $scope) {
            $frontMatter = Get-FrontMatter -Path $candidate.Path
            $headerScore = Get-MatchScore -Text $frontMatter
            if ($scopeLabel -eq "all note headers" -and
                -not [string]::IsNullOrWhiteSpace($Query) -and
                $headerScore -eq 0) {
                continue
            }

            [PSCustomObject]@{
                Stage       = "header"
                Scope       = $scopeLabel
                Score       = $candidate.Score + $headerScore
                Path        = $candidate.Name
                Title       = Get-FrontMatterValue -FrontMatter $frontMatter -Name "title"
                Date        = Get-FrontMatterValue -FrontMatter $frontMatter -Name "date"
                Description = Get-FrontMatterValue -FrontMatter $frontMatter -Name "description"
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
        if ($null -ne $ripgrep) {
            $hits = @(
                & $ripgrep.Source --ignore-case --files-with-matches --glob "*.md" --fixed-strings -- $Query $rootFullPath 2>$null
            )
            if ($LASTEXITCODE -gt 1) {
                throw "ripgrep failed while searching note bodies."
            }
        } else {
            $hits = @(
                Get-ChildItem -LiteralPath $rootFullPath -File -Recurse -Filter "*.md" |
                    Select-String -SimpleMatch -CaseSensitive:$false -Pattern $Query -List |
                    ForEach-Object { $_.Path }
            )
        }

        $results = foreach ($hit in $hits) {
            [PSCustomObject]@{
                Stage = "content"
                Score = 1000
                Path  = Get-RelativePath -Path $hit
            }
        }
        Select-Results -Results @($results)
    }
}
