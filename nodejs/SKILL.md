---
name: nodejs
description: Build, refactor, or review Node.js services, CLIs, and tooling with package-manager fidelity, module-system compatibility, async cancellation, configuration validation, and stream-safe I/O. Use for Node runtime or package work.
---

# Node.js Engineering

## 使用范围

用于 Node.js 服务、命令行工具、构建脚本和运行时故障。先检查 `package.json`、锁文件、Node 版本、模块类型和现有脚本；不得跨包管理器生成锁文件或升级依赖，除非任务明确要求。

## 工作方式

- 按项目已有的 ESM 或 CommonJS 形式组织导入与导出，不混用只在某一模块系统可用的加载方式。变更模块边界时检查测试、CLI 入口和发布产物。
- 读取环境变量后尽早校验和归一化配置；不要把密钥写进代码、日志、示例配置或错误信息。区分启动期配置错误与请求期用户错误。
- 对网络、文件和子进程操作设置超时、取消或退出路径。捕获错误时保留原因链，并在库代码中把错误交给调用方决定如何呈现。
- 大文件、网络响应和管道优先使用 stream 并处理 backpressure；不要把未知大小的输入无条件读入内存。
- 修改 `package.json` 的 scripts、exports、bin、engines 或 workspace 配置前，检查它们的调用者和发布影响。开发工具与运行时依赖保持恰当分层。
- 复用项目现有测试命令，并覆盖异步失败、取消、资源清理和 CLI 非零退出码。需要真实服务的集成测试必须隔离端口、数据和凭据。

## 交付与边界

说明使用的包管理器、Node 版本假设、配置变更、兼容性影响和实际执行的验证。Express、NestJS、Vite、Next.js 等框架约定以项目事实为准；前端组件问题分别交由 React、Vue 或 Tailwind 技能处理。
