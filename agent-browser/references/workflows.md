# agent-browser 多场景工作流参考

以下场景示例均采用 Windows PowerShell 兼容写法，不使用 `.sh` 包装脚本、Unix `export` 或任何硬编码个人路径。在非 PowerShell 环境执行时，只需直接展开变量为字面值即可。

## 场景 1：基础浏览与表单交互闭环

要点：每次页面跳转、弹窗弹出或异步列表更新后，必须重新 `snapshot -i`，不要沿用旧 `@eN`。

```powershell
$session = "form-flow-1"
try {
    agent-browser --session $session open https://app.example.com/settings
    agent-browser --session $session wait --load domcontentloaded
    agent-browser --session $session snapshot -i

    # 根据实际快照输出的 @eN 填写并提交
    agent-browser --session $session fill @e2 "Project Alpha"
    agent-browser --session $session select @e3 "Public"
    agent-browser --session $session click @e4

    # 等待结果并强制重新快照
    agent-browser --session $session wait --text "已保存"
    agent-browser --session $session snapshot -i

    # 刷新回读验证持久化
    agent-browser --session $session reload
    agent-browser --session $session wait --load domcontentloaded
    agent-browser --session $session snapshot -i
}
finally {
    agent-browser --session $session close
}
```

## 场景 2：多子 Agent 并发与多账号登录隔离

核心原则：**登录准备与并发执行解耦**。先串行或按账号独立导出状态文件，再把不同状态文件分发给各自独立 `--session` 的子 Agent，彻底避免串号与 Chrome Profile 目录锁冲突。

### 阶段 A：登录并导出各账号状态

```powershell
New-Item -ItemType Directory -Force -Path ./tmp/auth | Out-Null

# 账号 A（管理员）
try {
    agent-browser --session login-admin open https://app.example.com/login
    agent-browser --session login-admin wait --load domcontentloaded
    agent-browser --session login-admin snapshot -i
    # 按快照完成登录（敏感密码优先用 auth vault 或环境变量，避免明文硬编码）
    agent-browser --session login-admin fill @e1 $env:ADMIN_USER
    agent-browser --session login-admin fill @e2 $env:ADMIN_PASS
    agent-browser --session login-admin click @e3
    agent-browser --session login-admin wait --url "**/dashboard"
    agent-browser --session login-admin state save ./tmp/auth/admin.json
}
finally {
    agent-browser --session login-admin close
}

# 账号 B（普通成员）
try {
    agent-browser --session login-member open https://app.example.com/login
    agent-browser --session login-member wait --load domcontentloaded
    agent-browser --session login-member snapshot -i
    agent-browser --session login-member fill @e1 $env:MEMBER_USER
    agent-browser --session login-member fill @e2 $env:MEMBER_PASS
    agent-browser --session login-member click @e3
    agent-browser --session login-member wait --url "**/dashboard"
    agent-browser --session login-member state save ./tmp/auth/member.json
}
finally {
    agent-browser --session login-member close
}
```

### 阶段 B：多个子 Agent 并发加载各自状态

子 Agent A（仅使用 `--session worker-admin` 与 `admin.json`）：

```powershell
try {
    agent-browser --session worker-admin open about:blank
    agent-browser --session worker-admin state load ./tmp/auth/admin.json
    agent-browser --session worker-admin open https://app.example.com/admin/users
    agent-browser --session worker-admin wait --text "用户管理"
    agent-browser --session worker-admin snapshot -i
    # 执行管理员侧校验...
}
finally {
    agent-browser --session worker-admin close
}
```

子 Agent B（仅使用 `--session worker-member` 与 `member.json`）：

```powershell
try {
    agent-browser --session worker-member open about:blank
    agent-browser --session worker-member state load ./tmp/auth/member.json
    agent-browser --session worker-member open https://app.example.com/admin/users
    agent-browser --session worker-member wait --load domcontentloaded
    agent-browser --session worker-member snapshot -i
    # 验证权限边界（应重定向或提示无权限）...
}
finally {
    agent-browser --session worker-member close
}
```

### 阶段 C：状态文件与进程清理检查

```powershell
# 确认没有残留会话进程
agent-browser session list

# 删除包含登录凭据的临时状态文件（确保 ./tmp 已加入 .gitignore）
Remove-Item -Force ./tmp/auth/admin.json, ./tmp/auth/member.json -ErrorAction SilentlyContinue
```

补充：

- 如果目标页在 `state load` 后立即跳转，建议采用上述 `open about:blank` → `state load <file>` → `open <target>`，或直接用 `--state <file>` 在首次启动时注入。
- 若多个会话必须连接同一个外部 Chrome（`--cdp <port>`），Cookie 与存储会共享，此时必须加 `--pin-tab` 防止互抢标签页；需要账号级完全隔离时，始终使用各自独立启动的 `--session`。

## 场景 3：前端页面视觉验收与改版回归

要点：区分“干净截图看美观”“标注截图定元素”“基线 Diff 查回归”，且**每张输出图片都必须实际打开阅读检查**。

### 3.1 多视口审美检查与元素定位

```powershell
New-Item -ItemType Directory -Force -Path ./tmp/shots | Out-Null
$session = "visual-audit"

try {
    # 桌面常规视口（干净截图：检查布局、留白、字体层级、遮挡与对比度）
    agent-browser --session $session set viewport 1440 900
    agent-browser --session $session open http://localhost:3000/dashboard
    agent-browser --session $session wait --load domcontentloaded
    agent-browser --session $session screenshot ./tmp/shots/desktop-clean.png
    agent-browser --session $session screenshot --full ./tmp/shots/desktop-full.png

    # 发现可疑区域需要定位到具体控件时，再拍标注图
    agent-browser --session $session screenshot --annotate ./tmp/shots/desktop-annotated.png

    # 暗色模式与窄屏响应式检查
    agent-browser --session $session set media dark
    agent-browser --session $session screenshot ./tmp/shots/desktop-dark.png

    agent-browser --session $session set media light
    agent-browser --session $session set viewport 390 844
    agent-browser --session $session screenshot --full ./tmp/shots/mobile-full.png

    # 同步检查运行时错误
    agent-browser --session $session console
    agent-browser --session $session errors
}
finally {
    agent-browser --session $session close
}
```

### 3.2 改版前后像素差异回归

```powershell
$session = "visual-diff"
try {
    agent-browser --session $session set viewport 1440 900

    # 改版前留存基线截图
    agent-browser --session $session open http://localhost:3000/pricing
    agent-browser --session $session wait --load domcontentloaded
    agent-browser --session $session screenshot --full ./tmp/shots/pricing-before.png

    # 应用代码改动并待页面重建后，刷新并执行视觉 diff
    agent-browser --session $session reload
    agent-browser --session $session wait --load domcontentloaded
    agent-browser --session $session diff screenshot --baseline ./tmp/shots/pricing-before.png --output ./tmp/shots/pricing-diff.png --full
}
finally {
    agent-browser --session $session close
}
```

### 3.3 强制读图核查清单

生成截图或 Diff 图后，必须调用宿主的读图工具逐一打开对应 PNG 文件，并基于真实图像内容核对：

1. **布局与对齐**：卡片网格、表头、表单标签与按钮基线是否对齐，有无意外换行或错位。
2. **留白与溢出**：容器边距是否均衡，是否存在文字被截断、重叠、被固定导航/弹窗遮挡或窄屏横向滚动条。
3. **可读性与对比度**：浅色/暗色主题下正文、次要文案、禁用态与边框是否清晰可辨。
4. **视觉回归范围**：查看 `diff.png` 中高亮差异像素是否仅落在预期改动区域，无误伤相邻组件。

若当前宿主或环境无法读取图片文件，必须明确汇报“已生成截图但未执行读图核查”，禁止将命令退出码为 0 等同于视觉验收通过。
