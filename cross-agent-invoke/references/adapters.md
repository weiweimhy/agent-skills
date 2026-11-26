# 跨 Agent 适配器与多宿主接入参考

本文件记录 `cross-agent-invoke` 对各目标 CLI 的参数映射、发现规则、多宿主共享加载方式及常见排障。

## 1. 目标 CLI 能力与参数映射

| 目标 (`-Target`) | 别名 | 底层 CLI | `read-only` 映射 | `workspace-write` 映射 | Prompt 传入方式 | 续聊 (`-SessionId`) |
| --- | --- | --- | --- | --- | --- | --- |
| `codex` | `codex-cli` | `codex` | `exec --sandbox read-only` | `exec --sandbox workspace-write` | `stdin` (`-`) + `-o <tmp>` | `exec resume <id> -` |
| `antigravity` | `agy` | `agy` | `--print --mode plan --sandbox` | `--print --mode accept-edits` | 位置参数 + 关闭 stdin | `--conversation <id>` |
| `workbuddy` | `codebuddy`, `cbc` | `codebuddy` / `cbc` | `-p <prompt> --permission-mode plan` | `-p <prompt> --permission-mode acceptEdits` | `-p` 参数 + 关闭 stdin | `--resume <id>` |
| `claude` | `claude-code` | `claude` | `-p --permission-mode plan` | `-p --permission-mode acceptEdits` | `stdin` | `--resume <id>` |

补充说明：

- **Codex 非 Git 目录**：脚本自动检测 `-WorkingDir` 是否为 Git 仓库；若不是，自动追加 `--skip-git-repo-check`。
- **Codex 输出提取**：脚本自动附加 `-o <tempFile>` 并在 `-OutputFormat text` 时优先返回最后一条纯净消息，避免把中间工具日志混入主输出。
- **Antigravity (`agy`)**：自动附加 `--disable-slash-commands` 与 `--print-timeout <TimeoutSeconds>s`，避免 Prompt 内斜杠被误展开或超时挂起。
- **扩展自定义参数**：任意目标特有参数均可通过 `-ExtraArgs @("--flag", "value")` 透传。

## 2. 二进制发现优先级与环境变量覆盖

`Invoke-CrossAgent.ps1`（执行调用或 `-ListAgents` 排查）按以下顺序解析目标可执行文件：

1. **环境变量显式指定（最高优先级）**：
   - `CROSS_AGENT_CODEX_BIN`
   - `CROSS_AGENT_ANTIGRAVITY_BIN`
   - `CROSS_AGENT_WORKBUDDY_BIN`
   - `CROSS_AGENT_CLAUDE_BIN`
2. **系统 `PATH`**：
   - `codex`、`agy`、`codebuddy` / `cbc` / `workbuddy`、`claude`
3. **标准安装目录自动兜底**：
   - `codex`：`$HOME/.codex/.sandbox-bin/codex.exe`、`$HOME/.codex/plugins/.plugin-appserver/codex.exe`、`%APPDATA%/npm/codex.cmd`、`$HOME/.local/bin/codex*`
   - `antigravity`：`%LOCALAPPDATA%/Programs/Antigravity CLI/agy.exe`、`$HOME/.local/bin/agy*`、`%APPDATA%/npm/agy.cmd`
   - `workbuddy`：`%LOCALAPPDATA%/codebuddy/bin/codebuddy.exe`、`$HOME/.local/bin/codebuddy*`、`%APPDATA%/npm/codebuddy.cmd`、`$HOME/.workbuddy/binaries/node/versions/*/codebuddy.cmd`、WorkBuddy 安装包内置 `resources/app.asar.unpacked/cli/bin/codebuddy*`
   - `claude`：`$HOME/.local/bin/claude*`、`%APPDATA%/npm/claude.cmd`

PowerShell 设置持久化环境变量示例（用户级）：

```powershell
[Environment]::SetEnvironmentVariable("CROSS_AGENT_WORKBUDDY_BIN", "<path-to-codebuddy-exe>", "User")
```

## 3. 让 Codex、Antigravity、WorkBuddy 三端共享同一份 Skill

遵循“单源部署、多端发现”原则，不复制技能目录：

1. **Codex**：自动从 `~/.agents/skills/` 发现，无需额外配置。
2. **Antigravity**：在源仓库运行 `pwsh ./scripts/connect-antigravity.ps1`，将 `~/.agents/skills/` 注册到 `~/.gemini/config/skills.json`，然后执行 `/skills reload`。
3. **WorkBuddy / CodeBuddy**：其用户技能目录通常为 `~/.codebuddy/skills/`（或 `~/.workbuddy/skills/`）。在 Windows 上建立目录联接（Junction），无需管理员权限且同步零维护成本：

   ```powershell
   New-Item -ItemType Directory -Force -Path "$HOME/.codebuddy/skills" | Out-Null
   New-Item -ItemType Junction `
     -Path "$HOME/.codebuddy/skills/cross-agent-invoke" `
     -Target "$HOME/.agents/skills/cross-agent-invoke"
   ```

   如果希望 WorkBuddy 直接共享整个个人技能库，也可按需对常用技能逐个建 Junction，避免不同宿主的路径冲突。

## 4. 常见排障

- **被拦截提示 `Self-invocation blocked` / `Cross-agent recursion blocked` / `Cross-agent loop blocked`**：
  - 这是防死循环护栏正常生效。同宿主请优先用内置子 Agent；确需两层委派时由人工显式传 `-MaxDepth 2`。
- **子 Agent 退出码非 0 且 Stderr 提示未登录 / Auth Error**：
  - 先在独立终端以交互方式运行对应 CLI 完成登录（例如 `codex`、`agy`、`codebuddy`、`claude`），确认交互式会话正常后再走无头调用。
- **在沙箱中调用失败（无法访问目标认证文件或本地端口）**：
  - 某些宿主默认终端沙箱会阻断访问 `~/.codex`、`~/.gemini` 或网络请求。此时需向用户请求放开该条命令的沙箱/审批，不得绕过权限边界。
- **网络请求超时 / `Reconnecting...`（常见于直连受限环境调用 Codex / Claude）**：
  - 子进程会继承当前 Shell 的 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`。如遇 `request timed out`，先在调用终端确认代理环境变量已设置，或用 `-TimeoutSeconds` 适当放宽超时并检查 `Stderr`。
- **中文乱码或长 Prompt 截断**：
  - 始终通过 `Invoke-CrossAgent.ps1`（内部使用 UTF-8 进程流）并配合 `-PromptFile` / `-OutputFile` 传递大段中文文本。

## 5. GitHub 参考与选型说明

本技能在设计前已检索以下 GitHub 开源方案并吸收其有效实践（CLI 包装、前置检查、只读第二意见、Worktree 隔离）：

- `sysCat64/codex-agy-plugin`：Codex 单向调用 `agy --print` 的轻量封装。
- `crazyzhang277/codex-antigravity-bridge`：Codex 通过 MCP + Git worktree 监督 Antigravity。
- `yamadashy/skills`（`codex-exec` / `claude-exec` / `consult-codex`）与 `bassemZohdy/delegate-skills`：Codex 与 Claude 之间的只读咨询和 worktree 委派模式。
- `rennerdo30/agent-bridge` / `nia-teams/agent-bridge`：多 Agent 桥接与登录/隔离流程参考。

由于现有公开仓库普遍只覆盖单向/双端、依赖常驻 MCP 服务或 Unix Shell 脚本，且未同时原生支持 Codex、Antigravity (`agy`) 与 WorkBuddy/CodeBuddy (`codebuddy`/`cbc`) 的 Windows PowerShell 交叉调用与统一防递归护栏，因此在本库维护单一、零常驻服务的 `cross-agent-invoke` 技能。
