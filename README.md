# Codex Skills

个人通用 Codex skill 库，适用于多个项目且不绑定 Go、Python、前端或文档项目。将本仓库直接克隆到 `~/.agents/skills/`，供当前用户的所有项目使用；不要将它作为项目子模块，也不要复制到单个项目中。

当前个人技术栈覆盖 Unity/C#/Lua、Go/Python/Redis/Nginx，以及 React/Vue/Tailwind CSS/Node.js；本库仅沉淀这些方向中跨项目重复出现的工程工作流。

## 设计原则

- 使用 Codex 官方 skill 形态：每个技能目录包含一个 `SKILL.md`。
- `SKILL.md` frontmatter 只保留 `name` 和 `description`，让 Codex 用官方触发机制选择技能。
- 技能优先覆盖跨项目高频工作流；窄栈、低频、可由系统/插件技能直接覆盖的能力不放入本仓库。
- 官方或插件技能不复制成本地空壳，只在需要时安装和启用。

## 源仓库与部署目录

`E:\\agents-skills` 是此电脑上唯一允许直接编辑的源工作仓库。修改技能后，在此目录完成校验、提交和推送。

`C:\\Users\\mhy\\.agents\\skills` 是部署用 clone，不直接编辑；只从远端快进更新：

```powershell
git -C C:\\Users\\mhy\\.agents\\skills pull --ff-only
```

其他电脑首次安装时，克隆同一远端：

```powershell
git clone git@github.com:weiweimhy/agent-skills.git ~/.agents/skills
```

后续更新同样只执行：

```powershell
git -C ~/.agents/skills pull --ff-only
```

更新后请新建或重新打开 Codex 任务，以重新发现技能。仅适用于某个项目的技能，应直接提交到该项目的 `.agents/skills/`；项目级规则则保留在该项目的 `AGENTS.md`。

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

### 游戏、Web 与基础设施

- `unity-csharp`: Unity 生命周期、序列化、性能与测试边界。
- `lua`: Lua 模块、table、协程与宿主语言互操作。
- `nodejs`: Node.js 运行时、包管理、异步、配置与流式 I/O。
- `tailwindcss`: Tailwind token、响应式状态、无障碍与组件样式边界。
- `redis`: Redis key/TTL 契约、原子性、缓存、锁与故障退化。
- `nginx`: Nginx 反向代理、TLS、缓存、WebSocket 与安全变更。
- `test-engineering`: 跨技术栈的测试分层、隔离、异步可靠性与回归验证。

### 交付、运维与安全

- `observability`: 结构化日志、指标、链路追踪、健康信号与隐私边界。
- `containers`: Dockerfile、Compose、镜像构建、依赖就绪和运行时配置。
- `ci-cd`: 构建与测试门禁、制品追溯、最小权限交付和回退策略。
- `security-baseline`: 信任边界、输入处理、密钥、依赖和安全审查基线。
- `database-migrations`: Schema/数据迁移、兼容发布、锁风险、恢复与验证。

## 删减策略

本次整理删除了这些类型的技能：

- 被官方系统技能替代：本地 `skill-builder` 改由官方 `skill-creator` 承担。
- 过窄或低频专项：`mongodb-master`、`csharp-review`、`lua-review` 暂不作为通用库默认项。
- 可合并工作流：`git-commit` 合并进 `git-workflow`，避免 Git 相关触发分裂。
- 旧自定义 schema 工具：删除 `generate-skills-index.ps1` 和旧索引库，改为官方 frontmatter 校验。

## 推荐配套技能

这些技能建议通过 Codex 系统/插件安装，不复制到本仓库：

- `skill-creator`: 创建和重构本仓库技能时使用。
- `skill-installer`: 从受支持来源安装额外技能时使用。
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

## 跨电脑同步

每台电脑都将本仓库克隆到 `~/.agents/skills/`。修改技能后，在本仓库提交并推送；其他电脑执行上述更新命令即可获得相同版本。

`tibishu-*` 技能依赖的 `TIBISHU_NOTES_PATH`（或桌面端的笔记库路径）仍需在每台电脑单独配置。

## 维护规则

- 新技能优先用官方 `skill-creator` 设计。
- 新技能目录名使用 kebab-case，并与 `name` 一致。
- 不新增 README、安装说明、变更日志等技能内辅助文档，除非该文件是技能执行必需资源。
- 如果一个能力只适用于单个项目，优先放到该项目自己的 `.agents/skills`，不要放进这个通用库。
