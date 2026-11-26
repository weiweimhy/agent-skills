[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$RequireBlogFrontMatter,

    [switch]$SkipMarkdownLint
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Note file not found: $Path"
}

$fullPath = (Resolve-Path -LiteralPath $Path).Path
$raw = Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
$issues = New-Object System.Collections.Generic.List[string]

$body = $raw
$hasFrontMatter = $false
$fmMatch = [regex]::Match($raw, '(?s)^---\r?\n(.*?)\r?\n---\r?\n?')

if ($fmMatch.Success) {
    $hasFrontMatter = $true
    $fmText = $fmMatch.Groups[1].Value
    $body = $raw.Substring($fmMatch.Length)

    $keys = @{}
    foreach ($line in ($fmText -split '\r?\n')) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            continue
        }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            $keys[$Matches[1]] = $Matches[2].Trim()
        }
    }

    if ($RequireBlogFrontMatter) {
        foreach ($requiredKey in @("title", "description", "date", "image", "hidden", "draft", "categories", "tags")) {
            if (-not $keys.ContainsKey($requiredKey)) {
                $issues.Add("Missing Blog front matter key '$requiredKey'.")
            }
        }
        if ($keys.ContainsKey("title") -and $keys["title"] -notmatch '^".+"$') {
            $issues.Add("Blog front matter 'title' must be a non-empty double-quoted string.")
        }
        if ($keys.ContainsKey("date") -and $keys["date"] -notmatch '^"\d{4}-\d{2}-\d{2}"$') {
            $issues.Add("Blog front matter 'date' must use quoted YYYY-MM-DD format.")
        }
        foreach ($boolKey in @("hidden", "draft")) {
            if ($keys.ContainsKey($boolKey) -and $keys[$boolKey] -notin @("true", "false")) {
                $issues.Add("Blog front matter '$boolKey' must be boolean true or false.")
            }
        }
    }
} elseif ($RequireBlogFrontMatter) {
    $issues.Add("Missing YAML Blog front matter block at top of file.")
}

# Inspect Markdown body outside fenced code blocks
$inFence = $false
$h1Count = 0
$lineNumber = 0
foreach ($line in ($body -split '\r?\n')) {
    $lineNumber++
    if ($line -match '^\s*(`{3,}|~{3,})') {
        $inFence = -not $inFence
        continue
    }
    if ($inFence) {
        continue
    }
    if ($line -match '^#\s+\S') {
        $h1Count++
    }
    if ($line -match ':highlight\[') {
        $issues.Add("Body line ${lineNumber}: avoid nonstandard ':highlight[...]' extension.")
    }
}

if ($h1Count -ne 1) {
    $issues.Add("Expected exactly one H1 heading in note body, found $h1Count.")
}

$lintStatus = "skipped"
if (-not $SkipMarkdownLint) {
    $linter = Get-Command markdownlint-cli2 -ErrorAction SilentlyContinue
    if ($null -ne $linter) {
        $lintOutput = & $linter.Source $fullPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            $lintStatus = "failed"
            $issues.Add("markdownlint-cli2 reported errors: $($lintOutput -join ' | ')")
        } else {
            $lintStatus = "passed"
        }
    } else {
        $lintStatus = "not_installed"
    }
}

$result = [PSCustomObject]@{
    Path           = $fullPath
    HasFrontMatter = $hasFrontMatter
    MarkdownLint   = $lintStatus
    Passed         = ($issues.Count -eq 0)
    Issues         = @($issues)
}

$result
if ($issues.Count -gt 0) {
    exit 1
}
