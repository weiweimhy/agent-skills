#requires -Version 7.0
$ErrorActionPreference = 'Stop'

$qaScript = Join-Path $PSScriptRoot 'Invoke-DeepdiveNoteQA.ps1'
if (-not (Test-Path -LiteralPath $qaScript -PathType Leaf)) {
    throw "Missing QA script: $qaScript"
}

$tmpRoot = Join-Path $env:TEMP ("deepdive_qa_test_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
[void](New-Item -ItemType Directory -Path $tmpRoot -Force)

try {
    # 1. Valid baseline fixture (1 formal md, 1 legacy excluded md, 2 valid SVGs using Method A & Method B, 1 allowed artifact)
    $validDir = Join-Path $tmpRoot 'valid'
    $labDir = Join-Path $validDir 'demo-lab'
    $legacyDir = Join-Path $validDir 'legacy'
    [void](New-Item -ItemType Directory -Path $labDir, $legacyDir -Force)

    @'
---
title: "Valid Note Title"
description: "Valid description"
date: "2026-11-26"
image: ""
hidden: false
draft: false
categories: ["Test"]
tags: ["QA"]
---

# Valid Note Title

See [Method A SVG](demo-lab/method-a.svg), [Method B SVG](demo-lab/method-b.svg), and [section anchor](#sub-section-one).

## Sub Section One

OK! Safe placeholders: `C:\Users\Public`, `C:\Users\zhangsan`, and `[[clang::musttail]]`.

```text
float_money=$1000.67 (int) $0 = 9 labelset foo.exe:$1420
```
'@ | Set-Content -LiteralPath (Join-Path $validDir '01-valid.md') -Encoding UTF8

    "# Broken old draft [missing](nope.md)" | Set-Content -LiteralPath (Join-Path $legacyDir 'old.md') -Encoding UTF8

    # SVG Method A (cx/cy + M 0 0) + 1 commented <animateMotion> to verify XML DOM ignores comments
    @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" width="400" height="200">
  <rect width="400" height="200" fill="#0f172a"/>
  <!-- <circle cx="10" cy="10" r="4"><animateMotion path="M 10 10 L 50 10"/></circle> -->
  <circle cx="50" cy="100" r="5" fill="#38bdf8">
    <animateMotion dur="2s" repeatCount="indefinite" path="M 0 0 L 100 0"/>
  </circle>
</svg>
'@ | Set-Content -LiteralPath (Join-Path $labDir 'method-a.svg') -Encoding UTF8

    # SVG Method B (<g translate> + cx=0 cy=0 + M 0 0)
    @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200" width="400" height="200">
  <rect width="400" height="200" fill="#0f172a"/>
  <g transform="translate(80, 120)">
    <circle cx="0" cy="0" r="5" fill="#a78bfa">
      <animateMotion dur="2s" repeatCount="indefinite" path="M 0 0 L 60 0"/>
    </circle>
  </g>
</svg>
'@ | Set-Content -LiteralPath (Join-Path $labDir 'method-b.svg') -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $labDir 'keep.exe') -Value 'MZ' -Encoding ASCII

    $validRes = & $qaScript -Root $validDir -ExcludeDirRegex '\\legacy\\' -CheckDisasmAtnt -AllowedArtifactPaths @('demo-lab/keep.exe') -Json | ConvertFrom-Json
    if (-not $validRes.Passed -or $validRes.Warnings -ne 0) { throw "Expected valid fixture to pass cleanly, got Errors=$($validRes.Errors) Warnings=$($validRes.Warnings)" }
    if ($validRes.SvgAnimateMotions -ne 2) { throw "Expected 2 valid animateMotion XML nodes, got $($validRes.SvgAnimateMotions)" }
    if ($validRes.LinksChecked -ne 3) { throw "Expected 3 links checked, got $($validRes.LinksChecked)" }
    if ($validRes.AllowedArtifacts -ne 1 -or $validRes.UnexpectedArtifacts -ne 0) { throw "Artifact allowlist mismatch" }

    # 2. Failing fixture covering every detector
    $badDir = Join-Path $tmpRoot 'bad'
    $badLab = Join-Path $badDir 'sample-lab'
    [void](New-Item -ItemType Directory -Path $badLab -Force)

    @'
---
title: "Title A"
description: ""
date: "2026/11/26"
image: ""
hidden: false
draft: false
categories: ["Test"]
---

# Title B

- [broken file](missing.md)
- [broken anchor](#non-existent-heading)
- Old term: PE64
- Leak: C:\Users\myprivuser\secret.txt
- Dollar ok: $1000.67 and `[[clang::musttail]]`

```asm
movq %rax, %rbx
```
'@ | Set-Content -LiteralPath (Join-Path $badDir 'bad.md') -Encoding UTF8

    @'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 200">
  <path id="p1" d="M 50 50 L 150 50"/>
  <circle cx="50" cy="50" r="4"><animateMotion dur="1s" path="M 50 50 L 150 50"/></circle>
  <circle cx="0" cy="0" r="4"><animateMotion dur="1s"><mpath href="#p1"/></animateMotion></circle>
  <circle cx="80" cy="80" r="4"><animateMotion dur="1s"><mpath href="#p1"/></animateMotion></circle>
</svg>
'@ | Set-Content -LiteralPath (Join-Path $badLab 'bad-motion.svg') -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $badLab 'leftover.exe') -Value 'MZ' -Encoding ASCII

    $badRes = & $qaScript -Root $badDir -ForbiddenTerms @('PE64') -CheckDisasmAtnt -Json | ConvertFrom-Json
    if ($badRes.Passed) { throw "Expected bad fixture to fail" }
    if ($badRes.BrokenLinks -ne 1) { throw "Expected 1 broken link, got $($badRes.BrokenLinks)" }
    if ($badRes.BrokenAnchors -ne 1) { throw "Expected 1 broken anchor, got $($badRes.BrokenAnchors)" }
    if ($badRes.FrontmatterErrors -lt 3) { throw "Expected >=3 frontmatter/H1 errors, got $($badRes.FrontmatterErrors)" }
    if ($badRes.ForbiddenTermHits -ne 1) { throw "Expected 1 forbidden term hit, got $($badRes.ForbiddenTermHits)" }
    if ($badRes.PrivacyPathHits -ne 1) { throw "Expected 1 privacy path hit, got $($badRes.PrivacyPathHits)" }
    if ($badRes.DisasmAtntWarnings -ne 1) { throw "Expected 1 AT&T disasm warning, got $($badRes.DisasmAtntWarnings)" }
    if ($badRes.SvgMotionErrors -ne 3) { throw "Expected 3 SVG motion errors (double path + zero anchor + double mpath), got $($badRes.SvgMotionErrors)" }
    if ($badRes.UnexpectedArtifacts -ne 1) { throw "Expected 1 unexpected artifact, got $($badRes.UnexpectedArtifacts)" }

    Write-Output "Test-DeepdiveNoteQA passed all assertions (valid fixture passed; bad fixture caught all $($badRes.Errors) errors + $($badRes.Warnings) warnings)."
} finally {
    if (Test-Path -LiteralPath $tmpRoot) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force
    }
}
