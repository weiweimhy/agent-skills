# agent-browser 命令速查

本文件按任务高频场景汇总 `agent-browser` 常用命令与排障要点。所有命令默认采用 Windows PowerShell 与跨 Shell 兼容写法；实际执行时请将 `<id>` 替换为当前任务或子 Agent 的独立会话名。

## 环境与诊断

```powershell
agent-browser --version                        # 查看 CLI 版本
agent-browser install                          # 下载并安装内置 Chrome for Testing
agent-browser doctor --offline --quick         # 快速本地体检（清理失效 socket/pid）
agent-browser doctor                           # 完整环境与启动诊断
agent-browser skills list                      # 查看当前 CLI 内置的版本同步技能
agent-browser skills get core --ref commands   # 按需读取上游完整命令参考
```

## 会话管理与生命周期

```powershell
agent-browser session id --scope worktree --prefix task  # 基于当前仓库/worktree 生成稳定会话名
agent-browser session list                               # 列出当前活跃会话
agent-browser --session <id> session info --json         # 查看会话守护进程与状态恢复诊断
agent-browser --session <id> close                       # 关闭指定会话（释放浏览器进程）
agent-browser close --all                                # 关闭全部会话（谨慎，避免影响其他任务）
```

说明：

- 会话名仅允许 Unicode 字母/数字、连字符 `-` 和下划线 `_`，不能包含空格。
- 每次调用都显式传入 `--session <id>`，避免因为宿主切换 Shell 导致退回到共享默认会话。

## 导航、阅读与等待

```powershell
agent-browser --session <id> open <url>                   # 启动并导航（支持 http/https/file/about/data）
agent-browser --session <id> open                         # 仅启动到 about:blank，便于先挂路由或加载状态
agent-browser --session <id> reload                       # 刷新页面
agent-browser --session <id> back                         # 后退
agent-browser --session <id> forward                      # 前进
agent-browser --session <id> read                         # 读取当前活跃页渲染后的可读文本
agent-browser --session <id> read <url> --outline         # 直接通过 HTTP 拉取文档页标题大纲（不启动浏览器）

# 精准等待（默认超时 25s，可通过 --timeout <ms> 调整）
agent-browser --session <id> wait @e3                     # 等待元素出现
agent-browser --session <id> wait --text "保存成功"       # 等待文本出现
agent-browser --session <id> wait --url "**/dashboard"    # 等待 URL 匹配通配符
agent-browser --session <id> wait --fn "window.__READY__ === true"
agent-browser --session <id> wait --load domcontentloaded # 等待 DOMContentLoaded
agent-browser --session <id> wait --load load             # 等待 load 事件
```

## 快照与交互（`@eN`）

```powershell
agent-browser --session <id> snapshot -i                  # 仅输出可交互元素与 @eN（推荐）
agent-browser --session <id> snapshot -i -c               # 紧凑交互快照，移除空结构节点
agent-browser --session <id> snapshot -i -u               # 附带链接 href
agent-browser --session <id> snapshot -i -s "#main"       # 仅扫描指定 CSS 区域
agent-browser --session <id> snapshot -i --delta          # 首次全量，后续仅返回结构变化
agent-browser --session <id> snapshot -i --json           # 结构化 JSON 输出

agent-browser --session <id> click @e1                    # 点击（支持 --new-tab、--button right）
agent-browser --session <id> dblclick @e1                 # 双击
agent-browser --session <id> fill @e2 "hello"             # 清空并填入文本
agent-browser --session <id> type @e2 " world"            # 不清空直接追加输入
agent-browser --session <id> press Enter                  # 发送按键（组合键如 Control+a）
agent-browser --session <id> select @e4 "选项文本"        # 选择下拉项（歧义时加 --by value 或 --by label）
agent-browser --session <id> check @e5                    # 勾选复选框（取消用 uncheck）
agent-browser --session <id> hover @e6                    # 悬停
agent-browser --session <id> upload @e7 ./sample.png      # 上传文件（相对当前工作目录）
agent-browser --session <id> scroll down 500              # 滚动页面（scrollintoview @e1 滚动到元素）

# 无快照时的语义定位（优于裸 CSS）
agent-browser --session <id> find role button click --name "提交"
agent-browser --session <id> find label "邮箱" fill "user@example.com"
agent-browser --session <id> find text "登录" click
```

> 传入以 `-` 开头的字面文本或文件名时，使用 `--` 分隔标志与值，例如：`agent-browser --session <id> fill @e2 -- --json`。

## 截图、视觉 Diff 与前端诊断

```powershell
# 视口与主题设置
agent-browser --session <id> set viewport 1440 900        # 桌面视口
agent-browser --session <id> set viewport 390 844         # 移动端窄屏视口
agent-browser --session <id> set media dark               # 模拟暗色模式（light 切回浅色）

# 截图（输出到自定义子目录前需先确保目录存在，或省略路径写入系统临时目录；执行后必须用读图能力实际查看图片）
New-Item -ItemType Directory -Force -Path ./tmp | Out-Null
agent-browser --session <id> screenshot ./tmp/view.png                  # 干净视口截图（检查美观/布局）
agent-browser --session <id> screenshot --full ./tmp/full.png           # 干净整页长图
agent-browser --session <id> screenshot --annotate ./tmp/annotated.png  # 带 [N]->@eN 编号标注截图
agent-browser --session <id> screenshot --if-changed ./tmp/view.png     # 页面未变化时跳过截图

# 视觉与结构对比
agent-browser --session <id> diff screenshot --baseline ./tmp/before.png --output ./tmp/diff.png
agent-browser --session <id> diff screenshot --baseline ./tmp/before.png --output ./tmp/diff.png --full --threshold 0.1
agent-browser --session <id> diff snapshot                              # 对比当前与上次快照变化

# 前端排错与状态读取
agent-browser --session <id> get url                      # 获取当前 URL（亦支持 title/text/value/attr/box/styles）
agent-browser --session <id> console                      # 查看控制台日志（--clear 清空）
agent-browser --session <id> errors                       # 查看未捕获页面异常（--clear 清空）
agent-browser --session <id> network requests             # 查看网络请求（支持 --filter api）
agent-browser --session <id> a11y --tags wcag2a,wcag2aa   # 内置 axe-core 无障碍审计
agent-browser --session <id> vitals --json                # 采集 LCP/CLS/TTFB/FCP/INP 指标
```

## 状态、认证、多标签与脚本执行

```powershell
# 状态导出与加载（含 cookies、localStorage、sessionStorage；state save 不会自动创建父目录）
New-Item -ItemType Directory -Force -Path ./tmp | Out-Null
agent-browser --session <id> state save ./tmp/account.json
agent-browser --session <id> state load ./tmp/account.json
agent-browser --session <id> --state ./tmp/account.json open https://app.example.com/dashboard

# 自动持久化（按会话名自动恢复与保存）
agent-browser --session <id> --restore open https://app.example.com/dashboard

# 凭据库（通过管道从环境变量传入密码，避免命令行暴露明文或交互挂起）
$env:APP_PASSWORD | agent-browser --session <id> auth save my-app --url https://app.example.com/login --username user@example.com --password-stdin
agent-browser --session <id> auth login my-app

# 标签页、Iframe 与弹窗
agent-browser --session <id> tab                          # 列出标签页（稳定 ID 为 t1/t2...）
agent-browser --session <id> tab new --label docs https://docs.example.com
agent-browser --session <id> tab docs                     # 切换标签后需重新 snapshot
agent-browser --session <id> frame @e3                    # 切入指定 iframe（frame main 返回主文档）
agent-browser --session <id> dialog status                # 检查 confirm/prompt（accept/dismiss 处理）

# PowerShell 跨行 JavaScript 执行（避免引号转义问题）
@'
Array.from(document.querySelectorAll("table tbody tr")).map(r => r.innerText.trim());
'@ | agent-browser --session <id> eval --stdin
```

## 常见报错与排障

| 现象或报错 | 原因 | 处理方式 |
| --- | --- | --- |
| `Ref @eN is from a document that is no longer loaded` | 页面或 iframe 发生导航/刷新，旧 ref 失效 | 重新执行 `snapshot -i`，使用新 `@eN` |
| `Element not found` / `Stale ref` | 动态 DOM 已替换或元素尚未渲染 | `wait --text` 或 `scroll` 后重新 `snapshot -i` |
| `covered by <...>` | 目标按钮被弹窗、遮罩或横幅挡住 | 先关闭遮挡元素，重新 `snapshot -i` 后重试 |
| `fill` / `type` 无响应 | 自定义编辑器或受控组件拦截常规输入 | 先 `focus @eN`，再使用 `keyboard inserttext "文本"` |
| `Failed to connect` / 守护进程异常 | 升级后版本不一致或残留僵尸守护进程 | 运行 `agent-browser doctor --offline --quick` 并重新打开会话 |
| `wait --load networkidle` 超时 | SPA 存在轮询、WebSocket 或 SSE 长连接 | 改用 `wait --text`、`wait --url` 或 `wait @eN` |
