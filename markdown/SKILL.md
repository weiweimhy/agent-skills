---
name: markdown
description: Fix or explain Markdown-specific formatting and lint issues such as headings, lists, tables, code fences, and links in CommonMark or GitHub Flavored Markdown. Use when markup quality is the task; use a content or document skill for substantive drafting.
---

# Markdown 格式与语法

聚焦 Markdown 标记、格式和 lint 问题。编写 Markdown 文件时依据目标平台和仓库约定处理，不为套用规则损害可读性。实质性文案、PRD、
技术文档内容由相应的内容或文档技能负责；需要时可显式调用 `markdown`。

## 检查要点

- 标题层级连续，标题前后有空行；遵循目标仓库的 H1 和标题风格约定。
- 列表缩进和标记一致，列表前后留空行。
- 代码围栏前后留空行，并标记语言；代码示例与正文中的反引号配对。
- 链接有非空目标和清楚的描述，图片有替代文本；仓库内相对链接应指向实际存在的文件或锚点。
- 按项目启用的 markdownlint 规则处理空格、尾随空白和行尾换行；不要臆断项目采用某个版本的全部规则。

## 处理方式

根据用户给出的 lint 输出或目标文件指出具体问题并修复。规则与可读性冲突时说明选择依据；没有被要求时不重写文档内容或结构。

## 参考资料

- [CommonMark Spec](https://spec.commonmark.org/)
- [GitHub Flavored Markdown](https://github.github.com/gfm/)
- [markdownlint Rules](https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md)
