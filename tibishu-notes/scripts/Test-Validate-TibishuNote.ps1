[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$validator = Join-Path $PSScriptRoot "Validate-TibishuNote.ps1"
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "tibishu-validate-test-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    $validNote = Join-Path $tempDir "valid.md"
    Set-Content -LiteralPath $validNote -Encoding utf8 -Value @'
---
title: "有效测试笔记"
description: ""
date: "2026-11-26"
image: ""
hidden: false
draft: false
categories: []
tags: []
---

# 有效测试笔记

正文内容。

```bash
# code comment should not count as H1
echo ok
```
'@
    $res = & $validator -Path $validNote -RequireBlogFrontMatter -SkipMarkdownLint
    if (-not $res.Passed) {
        throw "Expected valid note to pass, got issues: $($res.Issues -join '; ')"
    }

    $badNote = Join-Path $tempDir "bad.md"
    Set-Content -LiteralPath $badNote -Encoding utf8 -Value @'
---
title: ""
date: "2026/11/26"
---

# 标题一

# 标题二

这是 :highlight[非标准高亮]。
'@
    $badFailed = $false
    try {
        & $validator -Path $badNote -RequireBlogFrontMatter -SkipMarkdownLint | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $badFailed = $true
        }
    } catch {
        $badFailed = $true
    }
    if (-not $badFailed) {
        throw "Expected invalid note to fail validation."
    }

    [PSCustomObject]@{
        Result = "PASS"
    }
} finally {
    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}
