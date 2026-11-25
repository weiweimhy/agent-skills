---
name: react
description: Provide React-specific implementation and review guidance for components, Hooks, state flow, data fetching, Server Components, and TypeScript TSX. Use when the project or request specifically involves React or Next.js, or when explicitly invoked; for general frontend work, enter through frontend-implementation.
---

# React 开发

从依赖清单、应用入口和相邻组件确认 React/Next.js 版本、渲染方式、状态归属和取数约定。保持项目当前的组件与数据层边界；
只处理本任务实际涉及的 React 行为。

- 将交互状态放在需要它的最近共同组件。能从 props 或已有状态推导的值直接计算，避免用 effect 同步副本。连接外部系统的 effect 要处理依赖变化和清理。
- 按项目现有的加载和缓存机制处理服务端数据，覆盖加载、失败、重试及过期响应。仅在框架支持服务器组件时划分服务端与客户端边界，并检查传递的数据和交互职责。
- 性能任务先定位慢路径，区分串行取数、包体积和渲染开销。判断重渲染成本时使用 Profiler，再按测量结果决定是否调整组件边界或缓存计算结果。
- 沿用项目现有测试或浏览器流程验证受影响的交互。维护公共组件时保留调用方依赖的 props、事件和可访问行为。

通用前端需求由 [frontend-implementation](../frontend-implementation/SKILL.md) 进入；它会在任务需要时读取本技能。
