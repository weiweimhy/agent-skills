---
name: frontend-implementation
description: Implement or review frontend features in an existing web project, including component behavior, forms, navigation, responsive layouts, accessibility, and interaction states. Identify the project's actual stack, then load only the matching React, Vue, or Tailwind CSS guidance when needed.
---

# 前端实现入口

用于网页功能开发与代码审查。先从依赖清单、文件扩展名、入口和相邻组件识别项目实际使用的框架、样式方案与约定；沿用现有实现方式，不为局部改动引入新的框架或状态库。

## 按需读取框架指导

- 项目或任务涉及 React/Next.js 的组件、Hooks、状态或服务端组件时，读取 [react](../react/SKILL.md)。
- 项目或任务涉及 Vue 的组件、响应性、composable、Pinia 或 SSR 时，读取 [vue](../vue/SKILL.md)。
- 项目实际使用 Tailwind CSS，且任务涉及 utility、主题或响应式样式时，读取 [tailwindcss](../tailwindcss/SKILL.md)。
- 只读取当前任务需要的框架指导。用户点名 `react`、`vue` 或 `tailwindcss` 时，保留该技能作为直接入口，即使本入口也适用。
- 静态 HTML/CSS/JavaScript 项目沿用现有结构，不加载不相关的框架技能。

## 实现与验收

- 从语义化结构、明确的状态归属和可键盘操作的交互出发，按项目已有组件和设计 token 实现。
- 覆盖与功能有关的空、加载、失败、禁用和窄屏状态。维护公共组件时保留调用方依赖的属性、事件和可访问行为。
- 沿用项目已有的构建、测试和浏览器验证方式，报告实际检查过的交互与未验证部分。

## 边界

品牌视觉决策以项目设计系统和现有资产为准；API 形状遵循已确定的服务契约。需要设计系统级的视觉方向时，使用相应的设计工作流。
