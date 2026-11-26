# 跨 Agent 交叉协作模式

根据任务风险与修改范围选择最小复杂度的调用模式，避免为了“用多模型”而徒增耗时和上下文噪音。

## 模式 1：独立第二意见 / 跨模型 Code Review（推荐最高频）

适用场景：主 Agent 完成实现或复杂改动后，由另一模型独立审查当前 diff，寻找盲区、边界漏洞或兼容性回归。

```powershell
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target codex `
  -Mode read-only `
  -WorkingDir . `
  -Prompt "只读审查当前 git diff（运行 git diff 与 git status 核对），按严重程度列出真实存在的正确性、并发、安全或向后兼容问题，并给出文件与行号证据；无问题直接说明。" `
  -AsJson
```

主 Agent 收口动作：逐条验证返回的问题，过滤误报，仅采纳有真实证据的缺陷并记录核验结果。

## 模式 2：多方向交叉诊断（平行视角）

适用场景：根因不明的偶发故障，需要不同模型基于同一份日志或最小复现脚本各自提出独立假设。

- 始终保持 `-Mode read-only`。
- 给不同目标分配明确且不重叠的证据切片或视角（例如 Antigravity 查客户端状态流，Codex 查服务端并发与数据库事务，WorkBuddy 整理日志时间线或排查文档），最后由主 Agent 汇总并设计最小实验裁决根因。

## 模式 3：Worktree 隔离委派修改（写操作）

适用场景：需要另一个 Agent 独立实现一个清晰边界的子模块、脚本或修复，且不与当前主工作区产生写冲突。

### 委派给 Codex（支持原生 `-Worktree`）

```powershell
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target codex `
  -Mode workspace-write `
  -Worktree `
  -PromptFile "./tmp/subtask-spec.md" `
  -TimeoutSeconds 600 `
  -AsJson
```

### 委派给 Antigravity / WorkBuddy / Claude（手动 Worktree 隔离）

```powershell
git worktree add ../wt-subtask -b feat/subtask-agent
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target antigravity `
  -Mode workspace-write `
  -WorkingDir ../wt-subtask `
  -PromptFile "./tmp/subtask-spec.md" `
  -TimeoutSeconds 600 `
  -AsJson
```

主 Agent 收口动作：在 `../wt-subtask` 中查看 `git status` / `git diff` 并运行完整测试，确认无误后再合入主分支并 `git worktree remove ../wt-subtask`。

## 模式 4：多轮续聊（同一子任务迭代）

当需要围绕同一上下文继续追问（如要求补充反例或修正审查意见）时：

- 先在首轮调用时传 `-KeepSession -OutputFormat json` 获取返回的会话 ID。
- 下一轮传 `-SessionId <id>` 复用目标 Agent 的既有会话，减少重复读仓库的 Token 消耗。

## 禁止事项

- 禁止将外部 Agent 的自然语言输出直接当作已验证事实写入最终交付报告。
- 禁止在未隔离工作目录的情况下并发启动多个 `-Mode workspace-write` Agent 改动同一仓库。
- 禁止通过 `-AllowLoop` 构造自动循环互评（如 A 无限改完给 B 审、B 再自动调 A 改），多轮收敛应由主 Agent 控制明确的最大轮数（通常不超过 2 轮）。
