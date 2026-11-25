---
name: vue
description: Provide Vue-specific implementation and review guidance for Vue 3 components, Composition API, reactivity, composables, Pinia, Vite, and SSR. Use when the project or request specifically involves Vue, or when explicitly invoked; for general frontend work, enter through frontend-implementation.
---

# Vue 开发

从依赖清单、应用入口和相邻组件确认 Vue 版本、组件写法及是否启用 SSR。维护 Options API 组件时沿用已有写法；新组件跟随项目约定，
明确要求迁移时再调整 API 风格。

- 父子组件通过 props 和事件交换数据。跨组件共享业务状态时沿用项目已有的 Pinia 或其他方案。
- 提取 composable 时保留输入的响应性，检查解构是否让值失去更新，并明确谁负责清理事件监听、定时器和连接。
- SSR 项目按请求创建可变状态。浏览器 API 放在客户端生命周期使用，首次渲染保持服务端和客户端输出一致。
- 修复表单、路由或响应式问题时，从用户操作验证状态变化。沿用项目的组件测试或浏览器测试；长列表、深层响应式对象等性能优化应针对实际瓶颈。

通用前端需求由 [frontend-implementation](../frontend-implementation/SKILL.md) 进入；它会在任务需要时读取本技能。
