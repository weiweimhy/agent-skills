#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Root,

    [string]$ExcludeDirRegex = '',

    [string[]]$ExcludeFileNames = @(),

    [string[]]$ForbiddenTerms = @(),

    [string[]]$PrivacyPathPatterns = @(
        '(?i)[A-Z]:\\Users\\(?!<[^>]+>|yourname|username|user\b|zhangsan\b|lisi\b|student\b|demo\b|alice\b|bob\b|Public\b|Default\b|All Users\b|\.\.\.)[^\\\s"''`]+',
        '(?i)/(?:Users|home)/(?!<[^>]+>|yourname|username|user\b|zhangsan\b|lisi\b|student\b|demo\b|alice\b|bob\b|\.\.\.)[^/\s"''`]+'
    ),

    [switch]$CheckDisasmAtnt,

    [switch]$SkipFrontMatterCheck,

    [switch]$AllowEmptyDescription,

    [string]$LabDirRegex = '(^|\\)[^\\]*-lab(\\|$)',

    [string[]]$ArtifactExtensions = @('.exe', '.sys', '.obj', '.pdb', '.dll', '.lib', '.o', '.out'),

    [string[]]$ArtifactDirNames = @('__pycache__'),

    [string[]]$AllowedArtifactPaths = @(),

    [switch]$FailOnError,

    [switch]$Json
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Root directory not found: $Root"
}

$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param(
        [string]$Severity,
        [string]$Category,
        [string]$Path,
        [int]$Line = 0,
        [string]$Detail
    )
    $findings.Add([PSCustomObject]@{
        Severity = $Severity
        Category = $Category
        Path     = $Path
        Line     = $Line
        Detail   = $Detail
    })
}

function Get-RelativeNormPath {
    param([string]$FullPath)
    $full = [System.IO.Path]::GetFullPath($FullPath)
    if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($rootFull.Length).TrimStart('\', '/')
    }
    return $full
}

function Test-IsExcludedPath {
    param(
        [System.IO.FileSystemInfo]$Item,
        [string]$RelPath
    )
    if (-not [string]::IsNullOrWhiteSpace($ExcludeDirRegex) -and ($Item.FullName -match $ExcludeDirRegex -or $RelPath -match $ExcludeDirRegex)) {
        return $true
    }
    if ($Item -is [System.IO.FileInfo] -and ($ExcludeFileNames -contains $Item.Name)) {
        return $true
    }
    return $false
}

function ConvertTo-MarkdownHeadingSlug {
    param([string]$HeadingText)
    $clean = $HeadingText.Trim()
    $clean = $clean -replace '\s+#+\s*$', ''
    $clean = $clean -replace '`([^`]*)`', '$1'
    $clean = $clean -replace '\[([^\]]+)\]\([^)]+\)', '$1'
    $clean = $clean -replace '<[^>]+>', ''
    $clean = $clean.ToLowerInvariant()
    # Keep Unicode letters, digits, whitespace, underscore and hyphen; drop other punctuation
    $clean = [regex]::Replace($clean, '[^\p{L}\p{N}\s\-_]', '')
    $clean = $clean -replace '\s', '-'
    return $clean
}

function Get-MarkdownAnchorSet {
    param([string]$Text)
    $anchors = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $counts = @{}
    $body = $Text
    $fm = [regex]::Match($Text, '(?s)^---\r?\n.*?\r?\n---\r?\n?')
    if ($fm.Success) { $body = $Text.Substring($fm.Length) }

    $inFence = $false
    foreach ($line in ($body -split '\r?\n')) {
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { continue }
        if ($line -match '^#{1,6}\s+(.+)$') {
            $base = ConvertTo-MarkdownHeadingSlug -HeadingText $Matches[1]
            if ([string]::IsNullOrWhiteSpace($base)) { continue }
            if ($counts.ContainsKey($base)) {
                $counts[$base]++
                $slug = "$base-$($counts[$base])"
            } else {
                $counts[$base] = 0
                $slug = $base
            }
            [void]$anchors.Add($slug)
        }
    }
    return $anchors
}

function Parse-TranslatePair {
    param([string]$TransformText)
    $dx = 0.0; $dy = 0.0
    if ([string]::IsNullOrWhiteSpace($TransformText)) { return @($dx, $dy) }
    foreach ($m in [regex]::Matches($TransformText, 'translate\(\s*([+-]?\d+(?:\.\d+)?)(?:[\s,]+([+-]?\d+(?:\.\d+)?))?\s*\)')) {
        $dx += [double]$m.Groups[1].Value
        if ($m.Groups[2].Success) { $dy += [double]$m.Groups[2].Value }
    }
    return @($dx, $dy)
}

function Get-ElementAncestorTranslate {
    param([System.Xml.XmlNode]$Node)
    $tx = 0.0; $ty = 0.0
    $curr = $Node
    while ($null -ne $curr -and $curr.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        if ($curr.Attributes['transform']) {
            $pair = Parse-TranslatePair -TransformText $curr.Attributes['transform'].Value
            $tx += $pair[0]; $ty += $pair[1]
        }
        $curr = $curr.ParentNode
    }
    return @($tx, $ty)
}

# --- 1. File inventory ---
$allFiles = @(Get-ChildItem -LiteralPath $rootFull -Recurse -File)
$allMd = @($allFiles | Where-Object { $_.Extension -ieq '.md' })
$formalMd = @($allMd | Where-Object { -not (Test-IsExcludedPath -Item $_ -RelPath (Get-RelativeNormPath $_.FullName)) })
$allSvg = @($allFiles | Where-Object { $_.Extension -ieq '.svg' -and -not (Test-IsExcludedPath -Item $_ -RelPath (Get-RelativeNormPath $_.FullName)) })

# --- 2. SVG XML & animateMotion DOM checks ---
$svgXmlErrors = 0
$totalAnimateMotion = 0
$svgMotionErrors = 0

foreach ($svg in $allSvg) {
    $relSvg = Get-RelativeNormPath $svg.FullName
    $rawSvg = Get-Content -LiteralPath $svg.FullName -Raw -Encoding UTF8
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.XmlResolver = $null
    try {
        $xmlDoc.LoadXml($rawSvg)
    } catch {
        $svgXmlErrors++
        Add-Finding -Severity 'Error' -Category 'SVG_XML' -Path $relSvg -Detail "XML parse error: $($_.Exception.Message)"
        continue
    }

    $motions = $xmlDoc.GetElementsByTagName('animateMotion')
    $totalAnimateMotion += $motions.Count
    foreach ($am in $motions) {
        $hostNode = $am.ParentNode
        if ($null -eq $hostNode -or $hostNode.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

        $cxAttr = $hostNode.Attributes['cx']
        $cyAttr = $hostNode.Attributes['cy']
        $xAttr = $hostNode.Attributes['x']
        $yAttr = $hostNode.Attributes['y']

        $localX = if ($cxAttr) { [double]$cxAttr.Value } elseif ($xAttr) { [double]$xAttr.Value } else { 0.0 }
        $localY = if ($cyAttr) { [double]$cyAttr.Value } elseif ($yAttr) { [double]$yAttr.Value } else { 0.0 }

        $ancestorTrans = Get-ElementAncestorTranslate -Node $hostNode
        $effectiveX = $localX + $ancestorTrans[0]
        $effectiveY = $localY + $ancestorTrans[1]

        # Check static (0,0) anchor when host has cx/cy=0,0 and no non-zero ancestor translate
        if (($null -ne $cxAttr -or $null -ne $cyAttr) -and $localX -eq 0.0 -and $localY -eq 0.0 -and $ancestorTrans[0] -eq 0.0 -and $ancestorTrans[1] -eq 0.0) {
            $svgMotionErrors++
            Add-Finding -Severity 'Error' -Category 'SVG_ZERO_ANCHOR' -Path $relSvg -Detail "Host <$($hostNode.Name)> has static (0,0) with no ancestor translate(); breaks static-frame placement."
        }

        $hasMpath = $false
        foreach ($child in $am.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.LocalName -eq 'mpath') {
                $hasMpath = $true
                break
            }
        }

        if ($hasMpath -and ($effectiveX -ne 0.0 -or $effectiveY -ne 0.0)) {
            $svgMotionErrors++
            Add-Finding -Severity 'Error' -Category 'SVG_DOUBLE_OFFSET_MPATH' -Path $relSvg -Detail "<animateMotion> uses <mpath> while host effective offset is ($effectiveX, $effectiveY); W3C animateMotion adds CTM and causes double offset."
            continue
        }

        $pathAttr = $am.Attributes['path']
        if ($pathAttr -and ($effectiveX -ne 0.0 -or $effectiveY -ne 0.0)) {
            $pathStr = $pathAttr.Value.Trim()
            if ($pathStr -match '^M\s*([+-]?\d+(?:\.\d+)?)[\s,]+([+-]?\d+(?:\.\d+)?)') {
                $px = [double]$Matches[1]
                $py = [double]$Matches[2]
                if ($px -ne 0.0 -or $py -ne 0.0) {
                    $svgMotionErrors++
                    Add-Finding -Severity 'Error' -Category 'SVG_DOUBLE_OFFSET_PATH' -Path $relSvg -Detail "<animateMotion path='M $px $py ...'> on host offset ($effectiveX, $effectiveY); relative path must start at M 0 0."
                }
            } elseif ($pathStr -notmatch '^m\s*0[\s,]+0\b') {
                $svgMotionErrors++
                Add-Finding -Severity 'Warning' -Category 'SVG_MOTION_PATH' -Path $relSvg -Detail "<animateMotion path='$pathStr'> does not start at M 0 0 / m 0 0; verify coordinate frame."
            }
        }
    }
}

# --- 3. Markdown caches for anchor validation ---
$anchorCache = @{}
$textCache = @{}
foreach ($md in $allMd) {
    $text = Get-Content -LiteralPath $md.FullName -Raw -Encoding UTF8
    $textCache[$md.FullName] = $text
    $anchorCache[$md.FullName] = Get-MarkdownAnchorSet -Text $text
}

# --- 4. Markdown QA checks ---
$linksChecked = 0
$brokenLinks = 0
$brokenAnchors = 0
$fmErrors = 0
$forbiddenHits = 0
$privacyHits = 0
$atntHits = 0

foreach ($md in $formalMd) {
    $relMd = Get-RelativeNormPath $md.FullName
    $raw = $textCache[$md.FullName]
    $lines = $raw -split '\r?\n'

    # 4a. Frontmatter & H1 check
    $bodyStartLine = 0
    $bodyText = $raw
    $fmMatch = [regex]::Match($raw, '(?s)^---\r?\n(.*?)\r?\n---\r?\n?')
    $fmTitle = $null

    if (-not $SkipFrontMatterCheck) {
        if (-not $fmMatch.Success) {
            $fmErrors++
            Add-Finding -Severity 'Error' -Category 'FRONTMATTER_MISSING' -Path $relMd -Line 1 -Detail 'Missing YAML frontmatter block at top of file.'
        } else {
            $fmLines = $fmMatch.Groups[1].Value -split '\r?\n'
            $bodyStartLine = $fmLines.Count + 2
            $bodyText = $raw.Substring($fmMatch.Length)

            $keys = @{}
            foreach ($fl in $fmLines) {
                if ([string]::IsNullOrWhiteSpace($fl) -or $fl.TrimStart().StartsWith('#')) { continue }
                if ($fl -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
                    $keys[$Matches[1]] = $Matches[2].Trim()
                }
            }

            foreach ($req in @('title', 'description', 'date', 'image', 'hidden', 'draft', 'categories', 'tags')) {
                if (-not $keys.ContainsKey($req)) {
                    $fmErrors++
                    Add-Finding -Severity 'Error' -Category 'FRONTMATTER_KEY' -Path $relMd -Line 1 -Detail "Missing required Blog frontmatter key '$req'."
                }
            }
            if ($keys.ContainsKey('title')) {
                if ($keys['title'] -match '^"(.+)"$') {
                    $fmTitle = $Matches[1]
                } elseif ($keys['title'] -match "^'(.+)'$") {
                    $fmTitle = $Matches[1]
                    $fmErrors++
                    Add-Finding -Severity 'Warning' -Category 'FRONTMATTER_QUOTE' -Path $relMd -Line 2 -Detail "Frontmatter 'title' should use double quotes."
                } else {
                    $fmErrors++
                    Add-Finding -Severity 'Error' -Category 'FRONTMATTER_TITLE' -Path $relMd -Line 2 -Detail "Frontmatter 'title' must be non-empty quoted string."
                }
            }
            if ($keys.ContainsKey('date') -and $keys['date'] -notmatch '^"\d{4}-\d{2}-\d{2}"$') {
                $fmErrors++
                Add-Finding -Severity 'Error' -Category 'FRONTMATTER_DATE' -Path $relMd -Line 1 -Detail "Frontmatter 'date' must use double-quoted YYYY-MM-DD format."
            }
            if (-not $AllowEmptyDescription -and $keys.ContainsKey('description') -and $keys['description'] -in @('""', "''", '')) {
                Add-Finding -Severity 'Warning' -Category 'FRONTMATTER_DESC' -Path $relMd -Line 1 -Detail "Frontmatter 'description' is empty."
            }
            foreach ($bk in @('hidden', 'draft')) {
                if ($keys.ContainsKey($bk) -and $keys[$bk] -notin @('true', 'false')) {
                    $fmErrors++
                    Add-Finding -Severity 'Error' -Category 'FRONTMATTER_BOOL' -Path $relMd -Line 1 -Detail "Frontmatter '$bk' must be true or false."
                }
            }
        }
    } elseif ($fmMatch.Success) {
        $bodyStartLine = ($fmMatch.Groups[1].Value -split '\r?\n').Count + 2
        $bodyText = $raw.Substring($fmMatch.Length)
    }

    # 4b. Line-by-line body inspection (fences tracked)
    $inFence = $false
    $fenceLang = ''
    $h1List = New-Object System.Collections.Generic.List[object]

    $bodyLines = $bodyText -split '\r?\n'
    for ($idx = 0; $idx -lt $bodyLines.Count; $idx++) {
        $ln = $bodyLines[$idx]
        $actualLine = $bodyStartLine + $idx + 1

        if ($ln -match '^\s*(?:`{3,}|~{3,})\s*([^\s`~]*)') {
            if (-not $inFence) {
                $inFence = $true
                $fenceLang = $Matches[1].ToLowerInvariant()
            } else {
                $inFence = $false
                $fenceLang = ''
            }
            continue
        }

        # Privacy path scan across entire file body (including code blocks)
        foreach ($pp in $PrivacyPathPatterns) {
            foreach ($pm in [regex]::Matches($ln, $pp)) {
                $privacyHits++
                Add-Finding -Severity 'Error' -Category 'PRIVACY_PATH' -Path $relMd -Line $actualLine -Detail "Possible personal absolute path leaked: '$($pm.Value)'"
            }
        }

        # Forbidden term scan
        foreach ($ft in $ForbiddenTerms) {
            if ([string]::IsNullOrWhiteSpace($ft)) { continue }
            foreach ($fmHit in [regex]::Matches($ln, $ft)) {
                $forbiddenHits++
                Add-Finding -Severity 'Error' -Category 'FORBIDDEN_TERM' -Path $relMd -Line $actualLine -Detail "Matched forbidden term pattern '$ft': '$($fmHit.Value)'"
            }
        }

        if ($inFence) {
            if ($CheckDisasmAtnt -and $fenceLang -in @('asm', 'x86asm', 'nasm', 'intel', 'masm', 'text', 'objdump', '')) {
                $isAtntReg = $ln -match '(?<![A-Za-z0-9_])%(?:r(?:ax|bx|cx|dx|si|di|bp|sp|8|9|10|11|12|13|14|15)|e(?:ax|bx|cx|dx|si|di|bp|sp))\b'
                $isAtntOp = $ln -match '(?:^|\s)(?:mov|add|sub|cmp|lea|xor|push|pop|test|imul|and|or)[qlwb]\s+(?:\$(?:0x[0-9a-fA-F]+|\d+)|%[a-z0-9]+)'
                if ($isAtntReg -or $isAtntOp) {
                    # Ignore explicit C inline asm templates inside snippets if marked with __asm__ / asm volatile
                    if ($ln -notmatch '__asm__|asm\s+volatile') {
                        $atntHits++
                        Add-Finding -Severity 'Warning' -Category 'DISASM_ATNT' -Path $relMd -Line $actualLine -Detail "Possible AT&T syntax inside fenced block ($fenceLang): $($ln.Trim())"
                    }
                }
            }
            continue
        }

        if ($ln -match '^#\s+(.+)$') {
            $h1List.Add([PSCustomObject]@{ Text = $Matches[1].Trim(); Line = $actualLine })
        }

        if ($ln -match ':highlight\[') {
            Add-Finding -Severity 'Error' -Category 'NONSTANDARD_MD' -Path $relMd -Line $actualLine -Detail "Nonstandard ':highlight[...]' syntax."
        }

        # Strip inline code spans before scanning Wiki Links and relative links
        $lineNoInlineCode = [regex]::Replace($ln, '`[^`]+`', '')
        foreach ($wm in [regex]::Matches($lineNoInlineCode, '\[\[[^\]]+\]\]')) {
            if ($wm.Value -match '^\[\[(?:[A-Za-z_]\w*::[A-Za-z_]\w*|nodiscard|maybe_unused|noreturn|fallthrough|deprecated|likely|unlikely)\]\]$') { continue }
            Add-Finding -Severity 'Warning' -Category 'WIKI_LINK' -Path $relMd -Line $actualLine -Detail "Wiki Link syntax detected: $($wm.Value)"
        }

        # Relative Markdown links & images
        foreach ($lm in [regex]::Matches($lineNoInlineCode, '!?\[[^\]]*\]\((?<target>[^)]+)\)')) {
            $rawTarget = $lm.Groups['target'].Value.Trim()
            # Drop optional Markdown link title: path "title"
            if ($rawTarget -match '^<([^>]+)>') {
                $rawTarget = $Matches[1].Trim()
            } elseif ($rawTarget -match '^([^\s]+)\s+["'']') {
                $rawTarget = $Matches[1].Trim()
            }

            if ($rawTarget -match '^(https?://|mailto:|ftp://|file://|data:)') { continue }

            $linksChecked++
            $parts = $rawTarget -split '#', 2
            $relFilePart = [System.Uri]::UnescapeDataString($parts[0])
            $fragPart = if ($parts.Count -gt 1) { [System.Uri]::UnescapeDataString($parts[1]) } else { '' }

            $targetFull = $null
            if ([string]::IsNullOrWhiteSpace($relFilePart)) {
                $targetFull = $md.FullName
            } else {
                $candidate = [System.IO.Path]::GetFullPath((Join-Path $md.DirectoryName $relFilePart))
                if (Test-Path -LiteralPath $candidate) {
                    $targetFull = $candidate
                } elseif ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetExtension($candidate)) -and (Test-Path -LiteralPath "$candidate.md")) {
                    $targetFull = "$candidate.md"
                } else {
                    $brokenLinks++
                    Add-Finding -Severity 'Error' -Category 'BROKEN_LINK' -Path $relMd -Line $actualLine -Detail "Broken relative target '$rawTarget'"
                    continue
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($fragPart) -and $targetFull -and ($targetFull -match '\.md$')) {
                if (-not $anchorCache.ContainsKey($targetFull) -and (Test-Path -LiteralPath $targetFull -PathType Leaf)) {
                    $tRaw = Get-Content -LiteralPath $targetFull -Raw -Encoding UTF8
                    $anchorCache[$targetFull] = Get-MarkdownAnchorSet -Text $tRaw
                }
                if ($anchorCache.ContainsKey($targetFull)) {
                    $slugCandidate = $fragPart.ToLowerInvariant()
                    if (-not $anchorCache[$targetFull].Contains($slugCandidate) -and -not $anchorCache[$targetFull].Contains($fragPart)) {
                        $brokenAnchors++
                        Add-Finding -Severity 'Error' -Category 'BROKEN_ANCHOR' -Path $relMd -Line $actualLine -Detail "Broken heading anchor '#$fragPart' in '$rawTarget'"
                    }
                }
            }
        }
    }

    if (-not $SkipFrontMatterCheck) {
        if ($h1List.Count -ne 1) {
            $fmErrors++
            Add-Finding -Severity 'Error' -Category 'H1_COUNT' -Path $relMd -Line ($bodyStartLine + 1) -Detail "Expected exactly 1 H1 heading, found $($h1List.Count)."
        } elseif ($null -ne $fmTitle -and $h1List[0].Text -ne $fmTitle) {
            $fmErrors++
            Add-Finding -Severity 'Error' -Category 'TITLE_H1_MISMATCH' -Path $relMd -Line $h1List[0].Line -Detail "Frontmatter title '$fmTitle' != H1 '$($h1List[0].Text)'."
        }
    }
}

# --- 5. Build artifact / binary residue scan ---
$unexpectedArtifacts = 0
$allowedArtifacts = 0

foreach ($f in $allFiles) {
    if (Test-IsExcludedPath -Item $f -RelPath (Get-RelativeNormPath $f.FullName)) { continue }
    $rel = Get-RelativeNormPath $f.FullName
    $relSlash = $rel.Replace('\', '/')
    $isArtifact = ($ArtifactExtensions -contains $f.Extension.ToLowerInvariant()) -or ($f.FullName -match '(\\|/)__pycache__(\\|/)')
    if (-not $isArtifact) { continue }

    $isAllowed = $false
    foreach ($pat in $AllowedArtifactPaths) {
        $patNorm = $pat.Replace('\', '/')
        if ($relSlash -like $patNorm) {
            $isAllowed = $true
            break
        }
    }

    if ($isAllowed) {
        $allowedArtifacts++
    } else {
        $inLabDir = (-not [string]::IsNullOrWhiteSpace($LabDirRegex)) -and ($f.DirectoryName -match $LabDirRegex)
        $unexpectedArtifacts++
        $sev = if ($inLabDir) { 'Error' } else { 'Warning' }
        Add-Finding -Severity $sev -Category 'ARTIFACT_RESIDUE' -Path $rel -Detail "Build/binary artifact found$(if ($inLabDir) { ' inside lab directory' } else { '' }): $($f.Name)"
    }
}

$allDirs = @(Get-ChildItem -LiteralPath $rootFull -Recurse -Directory)
foreach ($d in $allDirs) {
    if ($ArtifactDirNames -contains $d.Name) {
        $relDir = Get-RelativeNormPath $d.FullName
        if (-not (Test-IsExcludedPath -Item $d -RelPath $relDir)) {
            $unexpectedArtifacts++
            Add-Finding -Severity 'Error' -Category 'ARTIFACT_DIR' -Path $relDir -Detail "Artifact cache directory '$($d.Name)' found."
        }
    }
}

$errorCount = @($findings | Where-Object { $_.Severity -eq 'Error' }).Count
$warningCount = @($findings | Where-Object { $_.Severity -eq 'Warning' }).Count

$summary = [PSCustomObject]@{
    Root                = $rootFull
    TotalFiles          = $allFiles.Count
    TotalMarkdown       = $allMd.Count
    FormalMarkdown      = $formalMd.Count
    TotalSvg            = $allSvg.Count
    SvgXmlErrors        = $svgXmlErrors
    SvgAnimateMotions   = $totalAnimateMotion
    SvgMotionErrors     = $svgMotionErrors
    LinksChecked        = $linksChecked
    BrokenLinks         = $brokenLinks
    BrokenAnchors       = $brokenAnchors
    FrontmatterErrors   = $fmErrors
    ForbiddenTermHits   = $forbiddenHits
    PrivacyPathHits     = $privacyHits
    DisasmAtntWarnings  = $atntHits
    AllowedArtifacts    = $allowedArtifacts
    UnexpectedArtifacts = $unexpectedArtifacts
    Errors              = $errorCount
    Warnings            = $warningCount
    Passed              = ($errorCount -eq 0)
    Findings            = $findings.ToArray()
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 6
} else {
    Write-Output "=== Deepdive Note QA Summary ==="
    $summary | Select-Object Root, TotalFiles, TotalMarkdown, FormalMarkdown, TotalSvg, SvgXmlErrors, SvgAnimateMotions, SvgMotionErrors, LinksChecked, BrokenLinks, BrokenAnchors, FrontmatterErrors, ForbiddenTermHits, PrivacyPathHits, DisasmAtntWarnings, AllowedArtifacts, UnexpectedArtifacts, Errors, Warnings, Passed | Format-List
    if ($findings.Count -gt 0) {
        Write-Output "=== Findings ==="
        $findings | Format-Table Severity, Category, Path, Line, Detail -Wrap -AutoSize
    } else {
        Write-Output "All QA checks passed with 0 findings."
    }
}

if ($FailOnError -and $errorCount -gt 0) {
    exit 1
}
