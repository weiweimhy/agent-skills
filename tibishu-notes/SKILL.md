---
name: tibishu-notes
description: Search, read, create, organize, revise, and validate Markdown notes in the knowledge base configured by TIBISHU_NOTES_PATH. Use when locating existing Tibishu notes via layered search or adding, editing, organizing, and linting Tibishu Markdown notes.
---

# Tibishu Notes

统一处理由 `TIBISHU_NOTES_PATH` 指向的个人 Markdown 笔记库的检索与写作。

## 解析笔记根目录

1. 先读进程环境变量 `TIBISHU_NOTES_PATH`；若为空，在 Windows 上再读用户级环境变量。
2. 若均未设置或目录不存在，停止操作并请用户在提笔书桌面端配置 **笔记库 → 笔记路径**。
3. Markdown 文件属于用户资产，`.noteimg*` 属于编辑器元数据，不作为笔记源文件读写。

## 分层只读检索（先搜后读、先搜后写）

查找已有笔记，或新建/整理笔记前确认现有主题目录与命名约定时，优先使用内置只读脚本，逐层收窄、一旦定位明确即停止，避免整库读入上下文：

```powershell
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Names -Query "关键词"
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Headers -Query "关键词"
& "$PSScriptRoot\scripts\Find-TibishuNotes.ps1" -Stage Content -Query "关键词"
```

- `Names`：仅匹配目录名与文件名（最高优先级分类）。
- `Headers`：仅在 `Names` 有多候选或零命中时读取开头 YAML front matter（不读正文）。
- `Content`：仅在前两层无法定位时用 `rg` 搜索正文命中路径；读正文前先看 front matter 消歧。
- 列表请求只返回路径与元数据；问答请求仅读取最小必要集合，引用路径并区分原文事实与推断。
- 检索阶段严禁修改笔记库或创建持久索引。

## 新建与修订工作流

1. 先检查笔记库根目录已有主题文件夹与邻近笔记，沿用清晰的既有主题目录、命名习惯与术语，不复制旧格式缺陷；若属于全新独立主题，在根目录下新建一个简洁的中文主题文件夹。
2. 绝不静默覆盖既有笔记；同名时以日期或明确限定词消歧。除非用户明确要求，不修改既有笔记正文或其已有 front matter。
3. 新建笔记必须在文件最开头包含如下 Blog front matter（填写 `title` 与 `date`，未提供值的可选字段保留空字符串或空数组，字符串加引号）：

   ```yaml
   ---
   title: "笔记标题"
   description: ""
   date: "YYYY-MM-DD"
   image: ""
   hidden: false
   draft: false
   categories: []
   tags: []
   ---
   ```

4. 遵循 UTF-8 标准 Markdown：front matter 之后仅保留一个 `#` 一级标题，逐级向下使用 ATX 标题；使用 `-` 无序列表、带语言标记的代码围栏，并在标题、列表、引用与代码块前后保留空行；避免原生 HTML 与 `:highlight[...]` 等非标准扩展。

## 确定性校验与 Lint

每次新增或修改笔记后，对变更文件执行内置校验脚本（校验 front matter 结构、单 H1、非标准扩展，并在可用时调用 `markdownlint-cli2`）：

```powershell
& "$PSScriptRoot\scripts\Validate-TibishuNote.ps1" -Path "<absolute-note-path>" -RequireBlogFrontMatter
```

- 修订无历史 Blog header 的既有笔记且用户未要求补 header 时，可省略 `-RequireBlogFrontMatter`。
- 修复报告的全部错误后再交付；若本机未安装 `markdownlint-cli2`，如实向用户说明（不静默安装包），并完成人工核对。
- 不要仅为清理 lint 而批量格式化无关既有笔记，也不擅自修改笔记库的 lint 配置。
