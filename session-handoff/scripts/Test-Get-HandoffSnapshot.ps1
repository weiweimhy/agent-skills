[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "Get-HandoffSnapshot.ps1"
$tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) "handoff-snapshot-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempRepo | Out-Null

try {
    & git -C $tempRepo init -q | Out-Null
    & git -C $tempRepo config user.email "test@example.com" | Out-Null
    & git -C $tempRepo config user.name "Test User" | Out-Null

    Set-Content -LiteralPath (Join-Path $tempRepo "a.txt") -Value "v1" -Encoding utf8
    & git -C $tempRepo add a.txt | Out-Null
    & git -C $tempRepo commit -q -m "chore: init" | Out-Null

    $cleanSnap = & $scriptPath -RepoPath $tempRepo
    if (-not $cleanSnap.IsClean) {
        throw "Expected clean repository snapshot."
    }
    if ($cleanSnap.RecentCommits.Count -ne 1) {
        throw "Expected 1 commit, got $($cleanSnap.RecentCommits.Count)."
    }

    Set-Content -LiteralPath (Join-Path $tempRepo "a.txt") -Value "v2" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRepo "b.txt") -Value "staged" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $tempRepo "c.txt") -Value "untracked" -Encoding utf8
    & git -C $tempRepo add b.txt | Out-Null

    $dirtySnap = & $scriptPath -RepoPath $tempRepo
    if ($dirtySnap.IsClean) {
        throw "Expected dirty repository snapshot."
    }
    if ($dirtySnap.Staged.Count -ne 1 -or $dirtySnap.Unstaged.Count -ne 1 -or $dirtySnap.Untracked.Count -ne 1) {
        throw "Expected 1 staged, 1 unstaged, 1 untracked; got $($dirtySnap.Staged.Count)/$($dirtySnap.Unstaged.Count)/$($dirtySnap.Untracked.Count)."
    }

    $jsonOut = & $scriptPath -RepoPath $tempRepo -AsJson | ConvertFrom-Json
    if ($jsonOut.HeadSubject -ne "chore: init") {
        throw "Unexpected HeadSubject in JSON output: $($jsonOut.HeadSubject)."
    }

    [PSCustomObject]@{
        Result = "PASS"
    }
} finally {
    if (Test-Path -LiteralPath $tempRepo) {
        Remove-Item -LiteralPath $tempRepo -Recurse -Force
    }
}
