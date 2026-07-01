# Skill Inventory

本文件是人工维护的通用技能清单。每个技能都是 Codex 官方形态：`<skill-name>/SKILL.md`，frontmatter 仅包含 `name` 和 `description`。

## Core Workflow

- `code-review` - 跨语言代码审查入口。
- `git-workflow` - diff 总结、提交拆分、提交信息和 PR 前整理。
- `release` - 语义化版本、Release Notes、标签和发布检查。
- `markdown` - Markdown 格式、lint 和文档结构。

## Product, Docs, AI

- `product-manager` - 模糊需求转 PRD、User Story 和验收标准。
- `doc-generator` - README、API 文档、注释、Changelog 和交接文档。
- `architecture-consultant` - 架构方案、技术选型、权衡分析和 ADR。
- `prompt-design` - Prompt、system prompt、few-shot、评测和安全边界。

## Backend

- `api-design` - REST/API 设计、请求响应、分页和错误格式。
- `backend-patterns` - 模块边界、服务层、缓存、重试、事务和观测性。
- `validation-lint` - 参数、DTO、响应结构和配置一致性检查。

## Language And Frontend

- `go-review` - Go 代码审查。
- `python-review` - Python 代码审查。
- `typescript-review` - TypeScript/TSX 代码审查。
- `react` - React/Next.js 组件、Hooks、状态和性能边界。
- `vue` - Vue 3、Composition API、Pinia、Vite 和 SSR 边界。

## Not Included By Default

- `skill-builder`: 使用官方 `skill-creator` 替代。
- `git-commit`: 合并进 `git-workflow`。
- `mongodb-master`, `csharp-review`, `lua-review`: 过窄或低频，适合按项目需要单独添加。
- PDF、Office、GitHub、browser、imagegen、OpenAI docs 等能力：使用系统或插件技能。
