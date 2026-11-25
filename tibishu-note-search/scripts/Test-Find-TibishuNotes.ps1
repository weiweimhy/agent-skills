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
        [Parameter(Mandatory)][AllowEmptyString()][string]$Query,
        [string]$Root = ""
    )

    try {
        $searchRoot = if ([string]::IsNullOrWhiteSpace($Root)) { $fixtureRoot } else { $Root }
        return @(& $helperPath -Root $searchRoot -Stage $Stage -Query $Query)
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
        throw "$Case expected $ExpectedCount result(s), got $($Rows.Count)."
    }

    $actualPaths = @($Rows | ForEach-Object { ([string]$_.Path) -replace "\\", "/" })
    foreach ($expectedPath in $ExpectedPaths) {
        $normalizedExpectedPath = $expectedPath -replace "\\", "/"
        if (@($actualPaths | Where-Object { $_ -eq $normalizedExpectedPath }).Count -ne 1) {
            throw "$Case did not return expected path '$expectedPath' exactly once."
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
    Write-FixtureNote -RelativePath "Projects/Alpha Guide.md" -Content @'
---
title: Alpha Guide
date: 2026-01-02
description: SharedHeader for alpha
---
ContentSharedMarker appears in this guide.
'@
    Write-FixtureNote -RelativePath "Projects/Beta Guide.md" -Content @'
---
title: Beta Guide
date: 2026-02-03
description: SharedHeader for beta
---
ContentSharedMarker appears in this guide too.
'@
    Write-FixtureNote -RelativePath "Research/Atlas Network.md" -Content @'
---
title: HeaderOnly Atlas
date: 2026-03-04
description: Atlas metadata
---
BodyOnlyMarker appears only in this note.
'@
    Write-FixtureNote -RelativePath "Misc/Plain Note.md" -Content @'
Plain text without front matter.
'@

    $nameZero = @(Invoke-Search -Stage Names -Query "NoFilenameMatchNeedle")
    Assert-ResultPaths -Case "Names zero-match" -Rows $nameZero -ExpectedCount 0

    $nameOne = @(Invoke-Search -Stage Names -Query "Atlas")
    Assert-ResultPaths -Case "Names one-match" -Rows $nameOne -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Names output contract" -Rows $nameOne -ExpectedProperties @("Stage", "Score", "Path")

    $nameMany = @(Invoke-Search -Stage Names -Query "Guide")
    Assert-ResultPaths -Case "Names multi-match" -Rows $nameMany -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    $headerZero = @(Invoke-Search -Stage Headers -Query "NoHeaderMatchNeedle")
    Assert-ResultPaths -Case "Headers zero-match" -Rows $headerZero -ExpectedCount 0

    $headerOneByName = @(Invoke-Search -Stage Headers -Query "Atlas")
    Assert-ResultPaths -Case "Headers one filename match" -Rows $headerOneByName -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Headers output contract" -Rows $headerOneByName -ExpectedProperties @("Stage", "Scope", "Score", "Path", "Title", "Date", "Description")
    if ($headerOneByName[0].Scope -ne "filename matches" -or $headerOneByName[0].Title -ne "HeaderOnly Atlas") {
        throw "Headers one filename match did not preserve its scope or title."
    }

    $headerManyByName = @(Invoke-Search -Stage Headers -Query "Guide")
    Assert-ResultPaths -Case "Headers multiple filename matches" -Rows $headerManyByName -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")
    if (@($headerManyByName | Where-Object Scope -NE "filename matches").Count -gt 0) {
        throw "Headers multiple filename matches changed their scope."
    }

    $headerOneFallback = @(Invoke-Search -Stage Headers -Query "HeaderOnly")
    Assert-ResultPaths -Case "Headers one fallback match" -Rows $headerOneFallback -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    if ($headerOneFallback[0].Scope -ne "all note headers" -or $headerOneFallback[0].Title -ne "HeaderOnly Atlas") {
        throw "Headers fallback did not preserve the matching title or scope."
    }

    $headerManyFallback = @(Invoke-Search -Stage Headers -Query "SharedHeader")
    Assert-ResultPaths -Case "Headers multiple fallback matches" -Rows $headerManyFallback -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    $contentZero = @(Invoke-Search -Stage Content -Query "ContentNeverPresentNeedle")
    Assert-ResultPaths -Case "Content zero-match" -Rows $contentZero -ExpectedCount 0

    $contentOne = @(Invoke-Search -Stage Content -Query "BodyOnlyMarker")
    Assert-ResultPaths -Case "Content one-match" -Rows $contentOne -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")
    Assert-Properties -Case "Content output contract" -Rows $contentOne -ExpectedProperties @("Stage", "Score", "Path")

    $contentMany = @(Invoke-Search -Stage Content -Query "ContentSharedMarker")
    Assert-ResultPaths -Case "Content multi-match" -Rows $contentMany -ExpectedCount 2 -ExpectedPaths @("Projects/Alpha Guide.md", "Projects/Beta Guide.md")

    $emptyRoot = Join-Path $fixtureRoot "EmptyLibrary"
    New-Item -ItemType Directory -Path $emptyRoot | Out-Null
    foreach ($stage in @("Names", "Headers", "Content")) {
        $emptyLibraryResults = @(Invoke-Search -Stage $stage -Query "NoMatchNeedle" -Root $emptyRoot)
        Assert-ResultPaths -Case "$stage empty-library" -Rows $emptyLibraryResults -ExpectedCount 0
    }

    $bodyFallbackNames = @(Invoke-Search -Stage Names -Query "BodyOnlyMarker")
    $bodyFallbackHeaders = @(Invoke-Search -Stage Headers -Query "BodyOnlyMarker")
    $bodyFallbackContent = @(Invoke-Search -Stage Content -Query "BodyOnlyMarker")
    Assert-ResultPaths -Case "Body fallback after Names" -Rows $bodyFallbackNames -ExpectedCount 0
    Assert-ResultPaths -Case "Body fallback after Headers" -Rows $bodyFallbackHeaders -ExpectedCount 0
    Assert-ResultPaths -Case "Body fallback Content" -Rows $bodyFallbackContent -ExpectedCount 1 -ExpectedPaths @("Research/Atlas Network.md")

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
