# Skill Inventory

本文件是人工维护的通用技能清单。每个技能都是 Agent Skills 目录结构：`<skill-name>/SKILL.md`，
frontmatter 仅包含 `name` 和 `description`。

## Core Workflow

- `debugging` - 从故障现象设计区分性实验，复现并验证修复。
- `experiment` - 对固定基线运行受控实验并复测候选方案。
- `agent-evals` - 对照任务路由与产物，用独立证据评估智能体。
- `code-review` - 跨语言代码审查入口。
- `git-workflow` - diff 总结、提交拆分、提交信息和 PR 前整理。
- `release` - 语义化版本、Release Notes、标签和发布检查。
- `markdown` - 显式处理 Markdown lint、渲染和格式问题。

## Tooling Setup

- `tibishu-note-search` - 分层检索已有个人笔记。
- `tibishu-notes` - 按笔记库约定编写、整理和验证笔记。
- `semi-mcp-setup` - Semi Design MCP 的项目级配置、验证与故障排查。
- `relay-imagegen` - 通过 Codex 已配置的 OpenAI 兼容中转端点生成或编辑图片。

## Product, Docs, AI

- `project-standards-init` - 工程规范初始化，包含前端风格、组件、图标、动效及后续交付契约。
- `product-manager` - 模糊需求转 PRD、User Story 和验收标准。
- `doc-generator` - 从代码校准 README、API 示例、变更记录和交接说明。
- `architecture-consultant` - 架构方案、技术选型、权衡分析和 ADR。
- `prompt-design` - Prompt、system prompt、few-shot、评测和安全边界。
- `gpt-agy-collaboration` - 跨宿主分工、独立审查、交接和长任务恢复。

## Backend

- `api-design` - REST/API 设计、请求响应、分页和错误格式。
- `backend-patterns` - 模块边界、服务层、缓存、重试、事务和观测性。
- `validation-lint` - 校验既有契约与配置的跨字段、跨环境语义。

## Language And Frontend

- `frontend-implementation` - 从用户交互组织前端实现，按框架加载专项。
- `go-review` - Go 代码审查。
- `python-review` - Python 代码审查。
- `typescript-review` - TypeScript/TSX 代码审查。
- `react` - React/Next.js 组件、Hooks、状态和性能边界。
- `vue` - Vue 3、Composition API、Pinia、Vite 和 SSR 边界。
- `nodejs` - Node.js 运行时、包管理、异步、配置和流式 I/O。
- `tailwindcss` - Tailwind CSS token、响应式状态、无障碍与可维护样式。

## Game, Infrastructure, And Quality

- `unity-csharp` - Unity C# 生命周期、序列化、性能和测试边界。
- `lua` - Lua 模块、table、协程和宿主语言互操作。
- `redis` - Redis key/TTL 契约、原子性、缓存、锁和故障退化。
- `nginx` - Nginx 代理、TLS、缓存、WebSocket 和安全变更。
- `test-engineering` - 跨技术栈的测试分层、隔离、异步可靠性和回归验证。

## Delivery, Operations, And Security

- `observability` - 日志、指标、链路追踪、健康信号和遥测隐私边界。
- `containers` - Dockerfile、Compose、镜像构建、依赖就绪和运行时配置。
- `ci-cd` - 构建/测试门禁、制品追溯、最小权限交付和回退策略。
- `security-baseline` - 信任边界、输入处理、密钥、依赖和安全审查基线。
- `database-migrations` - Schema/数据迁移、兼容发布、锁风险、恢复和验证。

## Not Included By Default

- `skill-builder`: 使用官方 `skill-creator` 替代。
- `git-commit`: 合并进 `git-workflow`。
- `mongodb-master`, `csharp-review`, `lua-review`: 过窄或低频，适合按项目需要单独添加。
- PDF、Office、GitHub、browser、OpenAI docs 和普通 imagegen 等能力：使用系统或
  插件技能；中转端点图片生成使用本库的 `relay-imagegen`。
