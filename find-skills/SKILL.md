---
name: find-skills
description: Discover, evaluate, and install agent skills across project, global, skills.sh (vercel-labs/skills CLI), and GitHub sources. Use when the user asks "is there a skill for X", "find a skill for X", wants to extend agent capabilities, or before authoring a new skill.
---

# Find Skills

按固定优先级检索、评估并安全引入 Agent Skills，基于 [vercel-labs/skills](https://github.com/vercel-labs/skills)（MIT）`find-skills` 适配为跨宿主与 Windows PowerShell 兼容工作流。

## 检索优先级（严格按顺序）

收到“找技能 / 有没有现成技能 / 扩展能力”或准备新建技能前，**必须按以下四级顺序逐层排查**，前一层已满足时直接复用，避免重复引入：

1. **项目目录（Project）**：
   - 检查当前工作区内的项目级技能目录（`.agents/skills/`、`.codex/skills/`、`.claude/skills/`）以及项目 `AGENTS.md` 约定。
   - 可运行 `skills list` 查看当前项目已安装技能。
2. **全局目录（Global）**：
   - 检查个人全局技能库（`~/.agents/skills/` 及其源仓库 `SKILLS.md`）与 `skills list -g`。
   - 检查当前宿主内置技能、已安装插件及 Marketplace 能力，避免复制官方或插件已有技能。
3. **`find-skills`（`skills.sh` 开放生态）**：
   - 前置检查：`skills --version`；若未全局安装，使用 `npx skills ...`（要求 Node.js >= 22.20），或先 `npm install -g skills`。
   - 按具体领域关键词检索：

     ```powershell
     skills find <query>
     skills find <query> --owner <owner>
     ```

   - 常见高频领域可同步核对 [skills.sh](https://skills.sh/) 榜单（如 `vercel-labs/agent-skills`、`anthropics/skills`）。
4. **GitHub 源码检索**：
   - 当 `find-skills` 未命中或需要核查具体实现细节时，优先用已认证的 `gh` CLI 精确检索：

     ```powershell
     gh search repos "<topic> agent skill" --sort stars --limit 10
     gh search code "filename:SKILL.md <keyword>" --limit 10
     gh api repos/<owner>/<repo>/contents/<path>/SKILL.md
     ```

   - 若 `gh` 不可用或网络受限，回退网页搜索。

## 推荐与引入前的质量核查

**不要仅凭搜索标题推荐或安装技能**，引入前必须核实：

- **安装量与可信来源**：`skills.sh` 优先选择安装量 1K+ 或官方/知名维护者来源（如 `vercel-labs`、`anthropics`、`microsoft`）；低于 100 安装量或 `<100` Stars 的仓库需审慎核查。
- **源码与安全边界**：先通过 `skills add <owner/repo> --list` 或 `gh api` 查阅目标 `SKILL.md` 及附带脚本，确认无越权命令、凭证外泄、提示词注入或硬编码个人路径。
- **跨宿主与 Windows 兼容**：确认命令不强依赖 Unix 专属脚本或特定单一宿主；若不兼容，评估是按项目适配还是在源仓库改造。

## 安全安装与落点规则

向用户汇报候选项时，给出技能名、核心能力、来源/安装量或 Stars、详情链接与建议落点；确认后再执行安装：

- **仅临时试用（不落盘）**：

  ```powershell
  skills use <owner/repo@skill>
  ```

- **项目级安装（默认推荐）**：仅当前项目需要的技能直接安装到项目目录：

  ```powershell
  skills add <owner/repo> --list
  skills add <owner/repo@skill> -y
  ```

- **全局共享技能（保护 Git 部署 clone）**：
  - 执行全局安装前，先检查 `~/.agents/skills/.git` 是否存在。
  - **若 `~/.agents/skills` 是 Git 托管的个人技能部署 clone，严禁直接运行 `skills add ... -g`**（会向部署目录写入未跟踪文件并破坏 `git pull --ff-only`）。应将选定技能引入/适配到个人技能源仓库，完成校验、提交并推送后再快进同步部署 clone。
  - 仅在非 Git 托管的独立全局目录，或用户明确指定写入某个宿主目录（`-a <agent>`）时，才使用 `skills add <owner/repo@skill> -g`。

## 四级均未命中时

1. 明确列出四级检索尝试过的关键词与结论，不编造不存在的技能。
2. 优先说明可以直接用通用工程能力完成当前任务。
3. 若该能力会高频复用，建议新建技能（项目内可用 `skills init <name>` 或官方 `skill-creator`，跨项目通用能力落入全局技能源仓库）。
