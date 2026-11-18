---
name: react
description: React development guidance for components, hooks, state management, Server Components, performance boundaries, and TypeScript TSX patterns. Use when building or reviewing React/Next.js UI, hooks, or frontend state flow.
---

# React 开发

从相邻组件、包清单和框架入口确认 React 版本、渲染方式、状态归属和取数约定。新增功能优先复用现有组件与数据层；引入状态库或调整目录结构时说明要解决的具体问题。

- 将交互状态放在需要它的最近共同组件。能从 props 或已有状态推导的值直接计算，避免用 effect 同步副本。连接外部系统的 effect 要处理依赖变化和清理。
- 按项目现有的加载和缓存机制处理服务端数据，覆盖加载、失败、重试及过期响应。仅在框架支持服务器组件时划分服务端与客户端边界，并检查传递的数据和交互职责。
- 性能任务先复现慢路径，区分串行取数、包体积和渲染开销。需要判断重渲染成本时使用 Profiler，再按测量结果决定是否调整组件边界或缓存计算结果。
- 用项目现有的测试或浏览器流程验证受影响的交互。维护公共组件时保留调用方依赖的 props、事件和可访问行为。
