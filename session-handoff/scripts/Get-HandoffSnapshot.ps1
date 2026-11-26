[CmdletBinding()]
param(
    [string]$RepoPath = ".",

    [ValidateRange(1, 20)]
    [int]$RecentCommits = 5,

    [switch]$AsJson
)

$ErrorActionPreference = "Stop"

$resolved = (Resolve-Path -LiteralPath $RepoPath).Path

function Invoke-Git {
    param([string[]]$Arguments)
    $output = & git -C $resolved @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return @($output)
}

$topLevel = Invoke-Git -Arguments @("rev-parse", "--show-toplevel")
if (-not $topLevel -or $topLevel.Count -eq 0) {
    throw "Not a Git repository: $resolved"
}

$branch = (Invoke-Git -Arguments @("rev-parse", "--abbrev-ref", "HEAD")) -join ""
$headSha = (Invoke-Git -Arguments @("rev-parse", "--short", "HEAD")) -join ""
$headSubject = (Invoke-Git -Arguments @("log", "-1", "--pretty=%s")) -join ""
$upstream = (Invoke-Git -Arguments @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")) -join ""

$ahead = $null
$behind = $null
if (-not [string]::IsNullOrWhiteSpace($upstream)) {
    $counts = (Invoke-Git -Arguments @("rev-list", "--left-right", "--count", "$upstream...HEAD")) -join ""
    if ($counts -match '^(\d+)\s+(\d+)$') {
        $behind = [int]$Matches[1]
        $ahead = [int]$Matches[2]
    }
}

$statusLines = @(Invoke-Git -Arguments @("status", "--porcelain=v1") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$staged = New-Object System.Collections.Generic.List[string]
$unstaged = New-Object System.Collections.Generic.List[string]
$untracked = New-Object System.Collections.Generic.List[string]

foreach ($line in $statusLines) {
    if ($line.Length -lt 4) { continue }
    $x = $line[0]
    $y = $line[1]
    $file = $line.Substring(3)
    if ($x -eq '?' -and $y -eq '?') {
        $untracked.Add($file)
    } else {
        if ($x -ne ' ') { $staged.Add("$x $file") }
        if ($y -ne ' ') { $unstaged.Add("$y $file") }
    }
}

$recent = @(Invoke-Git -Arguments @("log", "-n", "$RecentCommits", "--oneline"))

$snapshot = [PSCustomObject]@{
    CapturedAt     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
    RepositoryRoot = ($topLevel -join "").Replace('\', '/')
    Branch         = $branch
    HeadCommit     = $headSha
    HeadSubject    = $headSubject
    Upstream       = if ([string]::IsNullOrWhiteSpace($upstream)) { "none" } else { $upstream }
    Ahead          = $ahead
    Behind         = $behind
    IsClean        = ($statusLines.Count -eq 0)
    Staged         = @($staged)
    Unstaged       = @($unstaged)
    Untracked      = @($untracked)
    RecentCommits  = @($recent)
}

if ($AsJson) {
    $snapshot | ConvertTo-Json -Depth 4
} else {
    $snapshot
}
