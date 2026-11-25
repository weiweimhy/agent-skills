---
name: nodejs
description: Preserve consumer compatibility when changing Node.js packages or command-line interfaces, including exports, bins, scripts, engine support, and published artifacts. Use when packaging or CLI behavior can affect consumers.
---

# Node.js 包与 CLI 兼容性

## 使用范围

用于会影响包使用者或 CLI 调用方的 Node.js 改动。先检查 `package.json`、锁文件、项目声明的 Node 版本、模块类型、打包配置和现有脚本；不得跨包管理器生成锁文件或升级依赖，除非任务明确要求。

## 工作方式

- 从文档、CI、发布配置和现有调用方确认支持的 Node 版本、ESM/CommonJS 入口及 CLI 调用约定；不要推断项目必须同时支持两种模块系统。
- 改动 `exports`、`bin`、`files`、`engines`、scripts 或 workspace 配置前，追踪已知消费者
  和发布产物。检查入口文件是否会被打包、CLI 的 shebang 与执行权限是否保留，以及参数、
  标准输入输出、退出码等实际公开行为是否变化。
- 使用项目已有包管理器和打包流程；不切换包管理器、不擅自升级依赖。需要验证发布兼容性时，
  将实际生成的包制品安装到临时消费项目，按已声明支持的 Node 版本与导入/CLI 入口执行
  代表性用例，避免 workspace 链接掩盖遗漏文件。
- 复用项目现有检查命令。记录使用的包管理器、Node 版本、制品版本、消费方式、退出码和未覆盖的兼容范围。

## 交付与边界

说明受影响的消费者、入口或 CLI 行为，使用的包管理器、Node 版本依据和实际执行的验证。服务端运行时实现、配置或流处理问题不属于本技能的默认范围；框架与打包器约定以项目事实为准。
