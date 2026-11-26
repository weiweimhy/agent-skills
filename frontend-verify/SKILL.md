---
name: frontend-verify
description: End-to-end real-browser verification workflow for frontend changes, checking user flows, console/network errors, reload persistence, and responsive layouts across Antigravity browser tools or Playwright CLI. Use after implementing or fixing UI behavior and before declaring frontend work done.
---

# 前端真实浏览器验收闭环

用于前端功能改动、样式调整或交互修复后的真实页面验收，防止把“代码编译通过”或“静态读代码”误报为“页面已正常工作”。

## 验收前准备

1. 从仓库 `package.json`、文档或现有脚本确认真实的开发服务器启动命令、监听地址与测试账号/前置条件；不臆造端口或命令。
2. 按当前宿主选择可用浏览器入口：
   - **Antigravity**：优先委托内置 `browser` 子代理执行页面操作与视觉检查。
   - **Codex / 其他宿主**：使用项目既有 E2E 工具（如 Playwright / Cypress）或按需安装的 Playwright CLI。
   - 若当前环境无法启动服务或无可用浏览器工具，明确标注为“未做浏览器实测”并说明阻塞原因，绝不伪造已验收结果。

## 必查五项闭环

按本次改动涉及的范围逐项核实：

1. **真实交互路径**：从用户实际入口进入页面，按真实步骤完成核心操作（点击、输入、提交、切换状态），不只停留在首屏加载。
2. **持久化与刷新回读**：涉及表单保存、设置变更、筛选状态或路由参数时，操作完成后执行**页面刷新（Reload）**，核实数据与 UI 状态是否正确恢复；失败时分别排查接口响应、本地/服务端存储与页面初始化恢复三段。
3. **控制台与网络检查**：检查浏览器 Console 是否出现未捕获异常、React/Vue hydration 或运行时警告；检查 Network 关键请求的状态码与返回体是否符合预期，无静默 4xx/5xx。
4. **边界与视口检查**：针对受影响页面至少核对桌面常规视口与窄屏视口（若涉及移动端或响应式），确认无横向溢出、文字截断遮挡、不可点击重叠或焦点丢失；涉及暗色/多主题时核对可读性与对比度。
5. **证据留存与收尾**：保留关键验证截图或明确观察记录；验收完成后关闭本轮临时启动且无需常驻的本地进程（除非用户要求保持运行）。

## 交付汇报

汇报必须明确区分三项：
- **实际运行过的命令与访问路径**（URL、操作步骤、测试视口）；
- **观察到的真实结果**（交互、刷新回读、Console/Network 状态、视觉检查）；
- **未覆盖或受环境限制的缺口**（例如特定浏览器、真实登录态或生产数据）。
