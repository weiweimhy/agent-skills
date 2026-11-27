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

适用场景：需要另一个 Agent 独立实现一个清晰边界的子模块、大批量单测或重构。

- **串行单写（推荐默认）**：主控暂停写入、等被调方在当前干净工作区/特性分支完成后，主控直接查看 `git diff` 并运行测试验收，零合入负担。
- **并发写隔离（所有目标通用，推荐显式 `git worktree`）**：不要依赖 Codex 原生 `-Worktree`（其托管目录路径不会通过返回 JSON 回传，合入和清理不便，且非 Git 目录会报错）；统一由主控先建显式 worktree 再传 `-WorkingDir`：

```powershell
git worktree add ../wt-subtask -b feat/subtask-agent
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target codex `
  -Mode workspace-write `
  -WorkingDir ../wt-subtask `
  -PromptFile "$env:TEMP/codex-subtask-spec.md" `
  -StderrLog "$env:TEMP/codex-subtask.stderr.log" `
  -AsJson
```

主 Agent 收口动作：在 `../wt-subtask` 中查看 `git status` / `git diff` 并运行完整测试，确认无误后再合入主分支并 `git worktree remove ../wt-subtask`。临时派单/输出/日志文件一律放在 `$env:TEMP`（或主控 Artifact 目录），禁止落盘到目标仓库目录中以免污染 `git status`。

## 模式 4：多轮续聊（同一子任务迭代）

当需要围绕同一上下文继续追问（如要求补充反例或修正审查意见）时：

- 先在首轮调用时传 `-KeepSession -OutputFormat json` 获取返回的会话 ID。
- 下一轮传 `-SessionId <id>` 复用目标 Agent 的既有会话，减少重复读仓库的 Token 消耗。

## 模式 5：Antigravity 主控 → Codex 执行规范（均衡档）

当 Antigravity 作为主控指挥 Codex（如高推理档模型）干活时，遵循“**主控做决策与人话交付，Codex 做确定性重活与异构审计**”的分工：

### 1. 任务黑白名单与路由分界
- **强制/优先委派 Codex**：
  1. **强制只读复核**：在真实代码仓库主会话中，用户要求 review/审查代码，或完成实质性改动（含按审查意见完成批量修复后）准备收尾/提交前，**必须**执行 `read-only` 独立盲测 diff 复核（边界条件、并发竞态、资源泄漏、安全边界与向后兼容）；仅用户明确要求跳过 Codex 时豁免；
  2. 契约清晰、可测试自证的独立非核心子模块、大批量单元测试、机械批量重构或静态报错清零（`workspace-write`）；
  3. 两轮止损先归纳已验证事实后仍无定因的疑难 Bug，在请求用户决策前触发一次盲测 `read-only` 第二诊断（不注入主控既有猜测）。
- **内置子 Agent vs Codex 分界**：小规模或需共享当前会话上下文的并行机械活走 Antigravity 内置 `inherit` 子 Agent；大批量、边界独立且可测试自证的重活派给 Codex。
- **零触发（主控直接完成，不派 Codex）**：
  - 需求澄清、架构设计、核心业务逻辑实现、面向人类阅读的文档/总结/图表、前端 UI/视觉验证、纯讨论或非代码仓库、单文件小修小补。

### 2. 模型、超时、监控与优雅降级
- **模型配置**：默认不传 `-Model`/`-Effort`，直接沿用 `~/.codex/config.toml` 配置，避免硬编码模型名漂移。
- **超时上限**：脚本默认 `-TimeoutSeconds 3600`（1 小时，最高可调至 `7200`）以覆盖大型任务；轻量 `read-only` 审查可按需显式收窄（如 `-TimeoutSeconds 900`）。
- **实时后台监控**：大任务务必配合 `-StderrLog "$env:TEMP/<task>.stderr.log"` 后台运行，并设置周期超时提醒；需要排查进度或怀疑网络/认证卡死时直接读取该日志文件（避免仅看 stdout 看到空白误判），确认挂死后及时终止。
- **故障降级**：若 Codex 出现未登录、网络失败、额度耗尽或超时，主控如实记录原因并直接接手闭环，不反复空转重试。

### 3. 防“束手束脚”与防“晦涩长文”的 `-PromptFile` 模板

派单前主控先消除一切设计歧义，再将模板写入 `$env:TEMP\...` 以 `-PromptFile` 下发：

#### 写任务模板（`workspace-write`）

```markdown
# 任务目标
<一句话说清要完成的具体交付>

# 已敲定的设计决策（直接遵守，禁止重新讨论或中途请示）
- <接口签名 / 数据结构 / 行为约定 1>
- <边界处理策略 2>

# 允许修改范围
- 仅修改/新增：<明确文件路径或目录列表>
- 禁止改动上述范围外文件，不做无关格式化或依赖升级。

# 必跑验证命令
- <构建 / 单测 / Lint 命令；必须实测通过后再结束>
- 若验证命令因 Windows 沙箱限制（如缓存目录/本地端口/网络）失败，勿绕过或死磕，直接按第 1 项如实报阻塞，由主控在本地复测。

# 输出格式要求（严格遵守，供主控程序化验收，禁止长篇散文、铺垫或附加终端提交/归档提醒）
1. 结论：已完成 / 阻塞（附唯一阻塞根因）
2. 变更清单：`文件路径` - 一句话改动说明
3. 验证输出：实际执行的命令与通过/失败结果摘要
4. 风险/遗留：仅列有代码证据（`路径:行号`）的问题；无则写“无”
```

#### 只读复核 / 盲测模板（`read-only`）

```markdown
# 审查/诊断目标
<例如：审查当前 git diff 中的边界/并发/安全/回归问题；或：基于给定现象与日志做独立根因定位>

# 约束与输出要求（禁止散文、客套及终端收尾提醒）
- 仅报有代码或日志实证的问题；无问题直接回复“无实质问题”。
- 每条按 `[严重度] 文件:行号 | 根因与影响 | 最小修复建议` 单行输出。
```

> 进阶：若纯 Prompt 仍无法压住冗长输出，可通过 `-ExtraArgs @("--output-schema", "<绝对路径schema.json>")` 透传 Codex 原生 JSON Schema 强约束最终返回结构；启用时 Schema 文件必须使用 `$env:TEMP\...` **绝对路径**（避免跨 `-WorkingDir` 找不到），且必须将上述 Markdown 输出格式替换为与 Schema 匹配的 JSON 字段要求，勿混用。

## 模式 6：Codex 主控 → Antigravity 执行规范（均衡档）

当 Codex 桌面版/CLI 作为主控调用 `antigravity` (`agy`) 时，采用与模式 5 互补的不对称分工（**Codex 主写代码与验证，Antigravity 主补可读文档、方案权衡与异构复核**），且**仅在主会话触发**（被外部委派为 worker 或存在 `CROSS_AGENT_DEPTH` 时严禁反向触发）。

### 1. 任务黑白名单
- **优先委派 Antigravity**：
  1. 面向人类阅读的长文档、设计说明、变更总结、排查报告的起草或可读性改写（默认 `read-only` 出稿由 Codex 核验写入；或仅限定文档文件路径 `workspace-write`）；
  2. 模糊需求的多方案架构权衡对比，或实质性改动后的 `read-only` 异构 diff 复核；
  3. 两轮止损归纳事实后仍无定因的盲测 `read-only` 第二诊断（不注入 Codex 既有猜测）。
- **零触发（Codex 直接完成，不派 Antigravity）**：
  - 常规代码编写、单元测试、机械重构、简单单文件修改、已有明确答案的小问答。

### 2. 调用要点与防坑
- **Prompt 精炼传路径**：`agy` 通过位置参数接收 Prompt（受 Windows 命令行长度限制），`-PromptFile` 只写清晰目标、约束和**相关文件路径/命令提示**，让 `agy` 自行读取仓库文件，不要把大段 diff 或整文件内容硬粘贴进 Prompt。
- **模型与超时**：默认沿用本机 `agy` 配置，需要深度评审或长文写作时可按需传 `-Model pro -Effort high`；脚本默认 `-TimeoutSeconds 3600`（轻量评审可显式收窄如 `-TimeoutSeconds 900`），长任务配合 `-StderrLog "$env:TEMP/<task>.stderr.log"`。
- **沙箱审批与降级**：Codex 桌面版终端沙箱可能拦截 `agy` 访问 `~/.gemini` 或网络；需放行时按提示审批，若认证/网络/超时失败直接记录原因并由 Codex 兜底完成。

### 3. 推荐命令示例

```powershell
pwsh "<skill-dir>/scripts/Invoke-CrossAgent.ps1" `
  -Target antigravity `
  -Mode read-only `
  -WorkingDir . `
  -PromptFile "$env:TEMP/agy-doc-or-review.md" `
  -OutputFile "$env:TEMP/agy-result.md" `
  -StderrLog "$env:TEMP/agy-task.stderr.log" `
  -AsJson
```

## 禁止事项

- 禁止将外部 Agent 的自然语言输出直接当作已验证事实写入最终交付报告。
- 禁止在未隔离工作目录的情况下并发启动多个 `-Mode workspace-write` Agent 改动同一仓库。
- 禁止通过 `-AllowLoop` 构造自动循环互评（如 A 无限改完给 B 审、B 再自动调 A 改），多轮收敛应由主 Agent 控制明确的最大轮数（通常不超过 2 轮）。
