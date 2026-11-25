---
name: tailwindcss
description: Build or review styling that uses Tailwind CSS utilities, themes, and responsive variants, following the project's version and design tokens. Use for Tailwind-specific styling tasks or explicit invocation; for general frontend work, enter through frontend-implementation.
---

# Tailwind CSS 样式

先确认 Tailwind 主版本、构建入口、主题 token、组件库及 class 合并工具。沿用仓库当前的语法和构建方式，不把旧版配置范式套到新版项目。

- 优先复用颜色、间距、圆角、字号和断点 token。重复出现的样式应沉淀为项目 token 或组件 API，而不是在多处复制任意值。
- 从语义化 HTML 和键盘可用性开始，再添加视觉样式。按钮、链接、表单、对话框和动态内容须保留正确语义、焦点状态及可见的 focus 样式。
- 处理移动布局及实际需要的 hover、focus-visible、disabled、loading、error 和暗色模式状态，不只优化静态截图。
- 稳定复用的 utility 组合可提取为组件或项目已有的样式抽象；不要为了缩短 class 字符串而隐藏布局意图。
- 动态 class 必须能被构建工具静态发现。按数据选择样式时使用有限映射或项目已有的 safelist 策略。
- 修改主题、插件或构建配置后，按项目方式验证构建和界面；不要擅自全局重排 class 或切换 CSS 方案。

组件状态、数据获取和路由由 React/Vue 或项目自身约定负责。
通用前端任务由 [frontend-implementation](../frontend-implementation/SKILL.md) 进入；
它会在需要 Tailwind 指导时读取本技能。
