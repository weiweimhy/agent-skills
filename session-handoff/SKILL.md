---
name: session-handoff
description: Produce or verify a structured cross-session and cross-host (Codex / Antigravity) handoff record backed by real Git workspace facts. Use when pausing a multi-step task, switching agents/hosts, or resuming an in-progress workspace.
---

# 跨会话与跨宿主交接

用于长任务暂停、切新窗口或在 Codex 与 Antigravity 之间切换接手时，生成或核对一份**基于真实工作区事实**的交接记录，避免接手方误判已完成的改动、远端推送状态或未验证缺口。

## 生成交接记录（交出方）

1. 先运行内置只读脚本采集仓库真实快照，不凭记忆手写提交哈希、分支或改动列表：

   ```powershell
   & "$PSScriptRoot\scripts\Get-HandoffSnapshot.ps1"
   ```

2. 按以下五段输出简洁交接记录（无内容项显式写“无”，不省略）：
   - **任务目标与当前阶段**：最终验收条件是什么，当前已完成到哪一步。
   - **仓库与远端事实**：来自脚本的仓库路径、分支、基线 commit、上游领先/落后状态、已暂存/未暂存/未跟踪文件。明确说明本次改动**是否已提交、是否已推送**。
   - **已执行验证与结果**：列出实际跑过的命令及退出结果；未运行的检查标为“未验证”，绝不把静态检查冒充运行时通过。
   - **关键决策与已知风险**：已确认的约束、尚未解决的阻塞或需要用户拍板的选项。
   - **下一步起点**：接手方第一条应执行的核对或开发动作。

## 接手核对（接手方）

1. 收到交接记录后，先在当前工作区运行一次 `Get-HandoffSnapshot.ps1`，核对分支、HEAD、脏文件与交接记录是否一致。
2. 若任务涉及推送、打标签或发布，先用远端状态（`Upstream` / `git fetch` 或远端查询）核对哪些动作已真实生效，再继续执行，避免重复推送或覆盖远端状态。
3. 发现工作区与交接记录存在未解释的额外修改时，先向用户说明差异，不静默清理或覆写。
