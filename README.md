# Codex Skills

个人通用 Codex skill 库。这个仓库可以直接作为子仓库挂到不同项目的 `.codex/skills` 目录下使用，不绑定 Go、Python、前端或文档项目。

## 设计原则

- 使用 Codex 官方 skill 形态：每个技能目录包含一个 `SKILL.md`。
- `SKILL.md` frontmatter 只保留 `name` 和 `description`，让 Codex 用官方触发机制选择技能。
- 技能优先覆盖跨项目高频工作流；窄栈、低频、可由系统/插件技能直接覆盖的能力不放入本仓库。
- 官方或插件技能不复制成本地空壳，只在需要时安装和启用。

## 推荐安装路径

```powershell
git submodule add <repo-url> .codex/skills
git submodule update --init --recursive
```

也可以把本仓库作为普通目录放到 `~/.codex/skills` 或项目级 `.codex/skills` 下。

## 本地保留技能

### 通用工作流

- `code-review`: 跨语言代码审查入口。
- `git-workflow`: diff 总结、提交拆分、Conventional Commit 和 PR 前整理。
- `release`: 版本号、Release Notes、标签和发布检查。
- `markdown`: Markdown 写作、格式和 lint 规则。

### 需求、文档与 AI 协作

- `product-manager`: 模糊需求转 User Story、PRD 和验收标准。
- `doc-generator`: README、API 文档、注释、Changelog 和交接文档。
- `architecture-consultant`: 架构设计、技术选型、权衡分析和 ADR。
- `prompt-design`: Prompt、system prompt、few-shot 和评测方案设计。

### 后端与接口

- `api-design`: REST/API 路径、请求响应、分页和错误格式。
- `backend-patterns`: 后端模块边界、服务层、缓存、重试、事务和观测性。
- `validation-lint`: 参数、DTO、响应结构和配置文件一致性检查。

### 常用技术栈

- `go-review`: Go 代码审查。
- `python-review`: Python 代码审查。
- `typescript-review`: TypeScript/TSX 代码审查。
- `react`: React/Next.js 组件、Hooks、状态和性能边界。
- `vue`: Vue 3、Composition API、Pinia、Vite 和 SSR 边界。

## 删减策略

本次整理删除了这些类型的技能：

- 被官方系统技能替代：本地 `skill-builder` 改由官方 `skill-creator` 承担。
- 过窄或低频专项：`mongodb-master`、`csharp-review`、`lua-review` 暂不作为通用库默认项。
- 可合并工作流：`git-commit` 合并进 `git-workflow`，避免 Git 相关触发分裂。
- 旧自定义 schema 工具：删除 `generate-skills-index.ps1` 和旧索引库，改为官方 frontmatter 校验。

## 推荐配套技能

这些技能建议通过 Codex 系统/插件安装，不复制到本仓库：

- `skill-creator`: 创建和重构本仓库技能时使用。
- `browser:control-in-app-browser`: 前端和网页验收。
- `github:github`, `github:gh-fix-ci`, `github:gh-address-comments`, `github:yeet`: GitHub、CI、PR 和发布协作。
- `openai-docs`: OpenAI/Codex 官方文档查询。
- `pdf:pdf`, `documents:documents`, `spreadsheets:Spreadsheets`, `presentations:Presentations`: 文档型项目和交付物处理。
- `imagegen`: 前端、产品页或游戏素材生成。
- `plugin-creator`: 需要把技能、工具和 MCP 封装成插件时使用。

## 校验

```powershell
pwsh ./scripts/validate-skills.ps1
```

校验脚本会检查：

- 每个一级技能目录都有 `SKILL.md`。
- frontmatter 只使用 `name` 和 `description`。
- `name` 与目录名一致。
- `description` 足够具体，适合 Codex 触发。

## 跨电脑同步个人技能

`tibishu-notes`、`tibishu-note-search` 和 `project-standards-init` 由这套脚本维护。
在编辑它们的主电脑运行：

```powershell
pwsh ./scripts/Publish-PersonalSkills.ps1
```

发布脚本也会提交这两个同步脚本本身，确保从属电脑可从同一仓库取得安装脚本。

首次在另一台电脑运行（可从本仓库目录直接执行，也可将脚本复制过去执行）：

```powershell
pwsh ./scripts/Install-PersonalSkills.ps1
```

安装脚本将仓库克隆到 `~/.codex/skill-source/agent-skills`，并在
`~/.codex/skills` 中为每个技能建立目录联接。后续重复运行安装脚本即可：
它先在临时 worktree 中校验远端版本，只在校验通过后才 fast-forward 更新
实际被 Codex 使用的版本；不会覆盖普通目录或指向其他位置的现有联接。

在从属电脑不要直接修改这些联接中的技能文件，应始终在主电脑修改并发布。
`tibishu-*` 技能依赖的 `TIBISHU_NOTES_PATH`（或桌面端的笔记库路径）仍需在每台
电脑单独配置。

## 维护规则

- 新技能优先用官方 `skill-creator` 设计。
- 新技能目录名使用 kebab-case，并与 `name` 一致。
- 不新增 README、安装说明、变更日志等技能内辅助文档，除非该文件是技能执行必需资源。
- 如果一个能力只适用于单个项目，优先放到该项目自己的 `.codex/skills`，不要放进这个通用库。
