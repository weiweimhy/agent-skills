# 个人 Agent Skills

Codex 与 Antigravity 共用的个人技能库，适用于多个项目且不绑定 Go、Python、前端或文档项目。将本仓库直接克隆到 `~/.agents/skills/`，供当前用户的所有项目使用；不要将它作为项目子模块，也不要复制到单个项目中。

当前个人技术栈覆盖 Unity/C#/Lua、Go/Python/Redis/Nginx，以及 React/Vue/Tailwind CSS/Node.js；本库仅沉淀这些方向中跨项目重复出现的工程工作流。

## 设计原则

- 使用 Agent Skills 目录结构：每个技能目录包含一个 `SKILL.md`。
- `SKILL.md` frontmatter 只保留 `name` 和 `description`，供宿主按任务选择技能。
- 技能优先覆盖跨项目高频工作流；窄栈、低频、可由系统/插件技能直接覆盖的能力不放入本仓库。
- 官方或插件技能不复制成本地空壳，只在需要时安装和启用。

## 源仓库与部署目录

在独立的源工作仓库中修改、校验、提交并推送技能。可用 `git rev-parse --show-toplevel` 确认当前仓库根目录。

个人技能目录是部署 clone。推送后先检查该目录的工作区状态，再依照本仓库 [AGENTS.md](AGENTS.md) 同步。

其他电脑首次安装时，克隆同一远端：

```powershell
git clone git@github.com:weiweimhy/agent-skills.git ~/.agents/skills
```

后续更新同样只执行：

```powershell
git -C ~/.agents/skills pull --ff-only
```

更新后请新建或重新打开 Codex 任务，以重新发现技能。仅适用于某个项目的技能，
应直接提交到该项目的 `.agents/skills/`；项目级规则保留在该项目的 `AGENTS.md`。

## 技能与使用方式

完整入口见 [技能清单](SKILLS.md)。配置双宿主、选择协作方式和验证结果见 [AI 开发使用说明](AI-WORKFLOW.md)。

## 推荐配套技能

这些技能建议通过 Codex 系统/插件安装，不复制到本仓库：

- `skill-creator`: 创建和重构本仓库技能时使用。
- `skill-installer`: 从受支持来源安装额外技能时使用。
- 浏览器控制按环境启用，用于交互和视觉验收。需要可重复的浏览器操作时，可按需安装 [Playwright CLI 技能](https://github.com/microsoft/playwright-cli)。
- GitHub 集成按需启用，处理 CI、PR 或审查评论时，以当前环境提供的插件和技能为准。
- `openai-docs`: OpenAI/Codex 官方文档查询。
- `pdf:pdf`, `documents:documents`, `spreadsheets:Spreadsheets`,
  `presentations:Presentations`: 文档型项目和交付物处理。
- `imagegen`: 使用内置端点生成前端、产品页或游戏素材。
- `plugin-creator`: 需要把技能、工具和 MCP 封装成插件时使用。

## 项目基座初始化

`project-standards-init` 遵循“**做赋能基座，不做思维牢笼**”理念，按仓库事实生成精悍的根 `AGENTS.md`（目标 50–120 行，聚焦版本锚点、快慢验证分层命令、Golden Samples 标杆样例、公共复用入口、只读生成物、非显而易见的 Gotchas 与 Always/Ask First/Never 边界），并在复杂仓库中按需拆分子目录 `AGENTS.md`、`DESIGN.md` 或专题 `docs/`。多领域开源实践与实证取舍见 [GitHub 多领域最佳实践来源](project-standards-init/references/github-best-practices.md)。

### 前端项目初始化

使用 `project-standards-init` 初始化前端时，工程规则与视觉方向正交分离：既有项目提炼设计系统与标杆页面，新项目结合产品任务与信息密度确立清晰、可逆的审美基线，写入独立 `DESIGN.md`（已有设计文档则沿用），并声明“代码是数值真源、新规范优先旧页”，配合真实父容器渲染验收，在保证一致性的同时不限制 AI 的界面表达力。

示例：`使用 project-standards-init 初始化这个前端项目，面向独立摄影师的作品网站，根据横竖构图和系列顺序组织浏览，保留照片说明，验证窄屏阅读与键盘翻页。`

初始化本身不安装 UI 库或生成业务页面；若需一并落地实现，可追加“落实主题 token、共享组件与代表页面并验收”。

### Android 项目初始化

使用 `project-standards-init` 规划 Kotlin 原生 Android 项目时，可从
[Android 初始化模板](project-standards-init/references/android-project-template.md) 选择文档资产。
基线建议为 Kotlin、Jetpack Compose、稳定 Material 3；Material 3 Expressive 按具体 API
核对稳定性。规范覆盖状态管理、模块边界、构建兼容、原生自适应布局、无障碍与设备验收。
默认从单 app 模块起步，Hilt、持久化、网络和多模块随项目需求选择。

示例：`使用 project-standards-init 初始化这个 Kotlin Android 项目的规范，UI 采用
Jetpack Compose 与稳定 Material 3，参考 Material 3 Expressive；先检查仓库事实，
生成 AGENTS.md 和适用文档，核实版本兼容、真实 Gradle 任务和设备验收方式。`

这些资源是文档模板。用于具体项目时，替换产品与工程事实、裁剪条件章节，保留
尚未实现或验证的状态；初始化规范本身不安装依赖或生成可运行应用。

## 校验与同步

```powershell
pwsh ./scripts/validate-skills.ps1
```

校验脚本会检查：

- 发现的每个 `SKILL.md` 均位于一级技能目录。
- frontmatter 只使用 `name` 和 `description`，且 `name` 与目录名一致。
- `SKILL.md` 行数不超预算（防止提示词膨胀），且 `SKILL.md` 与 `agents/*.yaml` 不含硬编码的个人绝对路径。
- `SKILLS.md` 活跃清单与实际技能目录完全一致。

源仓库推送到远端后，可用安全同步脚本快进更新个人部署 clone（遵循 [AGENTS.md](AGENTS.md)，遇到与源库不同的本地改动会自动中止保护）：

```powershell
pwsh ./scripts/sync-deployment.ps1 -CheckAntigravity
```

## 跨电脑同步

每台电脑都将本仓库克隆到 `~/.agents/skills/`。修改技能后，在本仓库提交并推送；其他电脑执行
一键同步脚本即可拉取最新提交并按本机已安装的宿主自动对齐技能接入：

```powershell
pwsh ~/.agents/skills/scripts/sync-machine.ps1
```

该脚本默认先检查 `~/.agents/skills/` 工作区干净并执行 `git pull --ff-only`，然后按宿主发现
机制幂等处理：

- **Codex / DSH**：原生读取 `~/.agents/skills/`，仅做状态与同名覆盖体检，绝不修改
  `~/.codex/skills/`（若某版 DSH 需要联接到 `~/.dsh/skills/`，可追加 `-LinkDsh`）。
- **Antigravity**：幂等注册 `~/.gemini/config/skills.json`，已有其他条目时保留原文件并给出
  追加片段。
- **WorkBuddy / CodeBuddy / Claude Code**：自动检测本机存在的 `~/.workbuddy`、`~/.codebuddy`、
  `~/.claude`，按一级含 `SKILL.md` 的技能目录逐个维护 Directory Junction（新增技能自动补链，
  已删技能自动清理失效链接，宿主自带或本地真实目录自动保留不覆盖）。

常用选项：加 `-WhatIf` 预演变更，加 `-SkipPull` 跳过 `git pull`（适合手动拉取后再同步），
加 `-Hosts codex,antigravity,workbuddy,claude,dsh` 显式指定目标宿主。

`tibishu-notes` 技能依赖的 `TIBISHU_NOTES_PATH`（或桌面端的笔记库路径）仍需在每台电脑单独配置。

## 维护规则

- 新技能优先用官方 `skill-creator` 设计。
- 新技能目录名使用 kebab-case，并与 `name` 一致。
- 不新增 README、安装说明、变更日志等技能内辅助文档，除非该文件是技能执行必需资源。
- 如果一个能力只适用于单个项目，优先放到该项目自己的 `.agents/skills`，不要放进这个通用库。
