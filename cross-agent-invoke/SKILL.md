---
name: cross-agent-invoke
description: Invoke another local CLI coding agent (Codex, Antigravity agy, WorkBuddy/CodeBuddy, Claude Code) non-interactively from any host agent with built-in binary discovery, read-only or write permission mapping, anti-recursion call-chain guards, and structured results. Use when cross-calling between Codex, Antigravity, WorkBuddy, or Claude for independent second opinions, cross-model review, parallel diagnosis, or delegating isolated subtasks.
---

# 跨 Agent 交叉调用（Cross-Agent Invoke）

通过单脚本 `Invoke-CrossAgent.ps1` 在 **Codex (`codex`)、Antigravity (`agy`)、WorkBuddy / CodeBuddy (`codebuddy` / `cbc`) 与 Claude Code (`claude`)** 之间进行双向/多向非交互调用，内置本地 CLI 自动发现、权限沙箱映射、UTF-8 进程流与防递归护栏。

> 适用边界：同宿主内部并行子任务优先使用宿主内置子 Agent；跨会话人工交接使用 `session-handoff`；需要**主 Agent 自动调用另一个异构 Agent 执行并收回结果**时使用本技能。

## 1. 直接发起调用

直接运行 `Invoke-CrossAgent.ps1`，脚本内部自动解析目标 CLI（含环境变量覆盖、`PATH` 与常见安装目录），默认采用 **`read-only`（只读/Plan 沙箱）**：

```powershell
# 示例 1：默认只读模式，向 Codex 请求独立 diff 复核或第二意见
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target codex `
  -WorkingDir . `
  -Prompt "独立审查当前 git diff 中的边界条件、并发安全与回归风险，只报有代码证据的问题。" `
  -AsJson

# 示例 2：调用 Antigravity (agy) 做方案分析（支持指定模型与推理深度）
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target antigravity `
  -Model pro `
  -Effort high `
  -Prompt "对比当前模块两种重构方案的依赖影响与测试成本。" `
  -AsJson

# 示例 3：调用 WorkBuddy (codebuddy) 执行分析或受控修改
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target workbuddy `
  -Mode read-only `
  -PromptFile "./tmp/task-brief.md" `
  -OutputFile "./tmp/wb-result.md"
```

- 长任务描述优先用 `-PromptFile` 传入，避免多行文本与引号转义问题；调试新参数可加 `-DryRun` 预检。
- 目标别名：`codex` / `codex-cli`、`antigravity` / `agy`、`workbuddy` / `codebuddy` / `cbc`、`claude` / `claude-code`。
- **按需排查本机可用 Agent**（无需每次调用前预跑，仅在不确定安装状态或报错找不到 CLI 时使用）：

  ```powershell
  pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" -ListAgents -CheckVersion -AsJson
  ```

- 自定义安装目录可通过环境变量覆盖：`CROSS_AGENT_CODEX_BIN`、`CROSS_AGENT_ANTIGRAVITY_BIN`、`CROSS_AGENT_WORKBUDDY_BIN`、`CROSS_AGENT_CLAUDE_BIN`。

## 2. 安全护栏与防并发冲突

1. **防递归与防回环（强制开启）**：
   - 自动维护 `CROSS_AGENT_DEPTH`（默认上限 `-MaxDepth 1`，禁止二级嵌套）与 `CROSS_AGENT_CHAIN`（拦截 `A -> B -> A` 环路），默认阻止同宿主自调用（除非显式传入 `-AllowSelf`）。
   - 除非传入 `-RawPrompt`，自动在 Prompt 顶部追加委派护栏，禁止被调用方再次触发跨 Agent 调用。
2. **最小权限原则**：
   - 诊断、代码审查、方案咨询、文档归纳保持默认 `-Mode read-only`；仅明确委派写代码时传 `-Mode workspace-write`。
3. **写操作工作区隔离**：
   - 严禁多个写模式 Agent 并发修改同一工作目录中的重叠文件。
   - 委派 Codex 写代码优先加 `-Worktree`；委派 Antigravity / WorkBuddy / Claude 并行写代码时，先建独立 `git worktree` 并传给 `-WorkingDir`，完成后再审查合入。

## 3. 主 Agent 验收与汇报责任

- **外部 Agent 输出视为候选证据，而非最终事实**：收到返回值后，主 Agent 必须核对其引用的文件路径、行号、命令结果或改动 diff，再向用户下结论。
- 委派写操作后，主 Agent 必须在对应工作区或 worktree 运行测试/校验并检查 `git diff`；目标 CLI 未安装或认证/网络失败时如实汇报，不伪造结果。
- 汇报时明确记录：**目标 Agent、实际模式（read-only / workspace-write）、耗时/退出码、采纳或驳回理由**。

## 4. 按需参考

- 各 CLI 参数映射、WorkBuddy 共享挂载、环境变量覆盖与排障：见 [适配器与多宿主接入参考](references/adapters.md)。
- 第二意见复核、交叉诊断、Worktree 隔离委派与多轮续聊模式：见 [交叉协作模式](references/patterns.md)。
