# Skill Inventory

本文件是人工维护的通用技能清单，并与 `scripts/validate-skills.ps1` 自动对齐检查。每个技能遵循 Agent Skills 目录结构：`<skill-name>/SKILL.md`，frontmatter 仅包含 `name` 和 `description`。

本库只保留强前沿 Agent 依然需要的高信号能力：**私有资产与脚本、强个人工作流约束、高频翻车的领域防呆，以及可复现的验证/交接闭环**。

## Core Workflow & Verification

- `code-review` - 跨语言代码审查唯一入口，按需加载 Go、Python、TypeScript、安全边界与有状态变更/迁移专项参考。
- `git-workflow` - diff 总结、提交拆分、中文 Conventional Commit 信息与授权边界。
- `release` - 版本约定、Release Notes、标签、制品与消费者侧验证（含 Node.js 包/CLI 兼容参考）及回退说明。
- `frontend-verify` - 前端改动后的真实浏览器端到端验收闭环（真实交互、Console/Network、刷新回读与视口检查）。
- `agent-browser` - 跨宿主无头/有头浏览器自动化 CLI 工作流：基于 `snapshot -i` 与 `@eN` 的交互闭环、多子 Agent/多账号 `--session` 与 `state` 隔离，以及强制读图核查的前端视觉验收。
- `session-handoff` - 跨会话与跨宿主（Codex / Antigravity）结构化交接，附带 Git 工作区快照采集脚本。
- `cross-agent-invoke` - 跨 Agent 交叉调用工作流：通过统一脚本在 Codex、Antigravity (`agy`)、WorkBuddy/CodeBuddy (`codebuddy`/`cbc`) 与 Claude Code 间进行非交互调用，含 CLI 自动发现、只读/写权限映射与防递归回环护栏。
- `find-skills` - 技能发现、评估与安全引入工作流：严格按 `项目目录 -> 全局目录 -> find-skills (skills.sh / vercel-labs/skills CLI) -> GitHub` 顺序检索并保护 Git 托管的全局部署目录。
- `retro-to-guardrail` - 人工纠正沉淀路由：按优先级将经验落入自动化测试、项目文档、共享 Skill 或评测回归集。
- `agent-evals` - 对照任务路由、行为与验收成本，用独立证据评估智能体与技能收益。

## Project Setup & Personal Notes

- `project-standards-init` - 按仓库事实初始化或刷新 `AGENTS.md` 与工程文档，按需加载前端设计契约、Android 模板与规范库检索规则。
- `tibishu-notes` - 读写一体的个人笔记技能：分层只读检索、新建与整理、Blog front matter 与 markdownlint 确定性校验。

## Specialized Game Client

- `unity-csharp` - Unity C# 生命周期、序列化与 Prefab/Scene 资产兼容性、热点性能与主线程边界。
- `lua` - Lua 模块导出、table 语义、协程生命周期、热点与宿主语言桥接边界。

## Not Included By Default

- `debugging`、`api-design`、`containers`、`nginx`、`observability`、`ci-cd`、`test-engineering`、`experiment`：前沿强模型已内化相关通用工程常识，作为常驻全局技能反而增加路由噪音与汇报仪式；具体项目约定写入各仓库 `AGENTS.md`。
- `security-baseline`、`database-migrations`、`redis`、`backend-patterns`：高危反直觉核查点已浓缩并入 `code-review/references/`（`security.md`、`data-and-concurrency.md`），不再单独占顶层入口。
- `nodejs`：包与 CLI 消费端兼容验证已下沉至 `release/references/npm-package.md`。
- `tibishu-note-search`：已合并进读写一体的 `tibishu-notes`。
- `skill-builder`：使用官方 `skill-creator` 替代。
- `git-commit`：已合并进 `git-workflow`。
- `mongodb-master`、`csharp-review`、`lua-review`：过窄或低频，按项目需要单独放入项目 `.agents/skills/`。
- PDF、Office、GitHub、宿主内置交互式 browser 插件、OpenAI docs 和普通 imagegen 等能力：使用系统或插件技能。
