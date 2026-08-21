---
name: tailwindcss
description: Build or review Tailwind CSS interfaces with existing design tokens, semantic HTML, responsive states, accessible interaction, and maintainable component boundaries. Use for Tailwind utility classes, themes, or frontend styling work.
---

# Tailwind CSS Engineering

## 使用范围

用于使用 Tailwind CSS 构建或审查 React、Vue 或静态页面的样式。先识别 Tailwind 主版本、构建入口、现有主题 token、组件库和 class 合并工具；不要把旧版本配置范式套用到新版本项目。

## 工作方式

- 先复用现有颜色、间距、圆角、字号和断点 token。重复出现的任意值应优先沉淀为项目 token 或组件 API，而不是在多处复制。
- 从语义化 HTML 和键盘可用性开始，再添加视觉样式。按钮、链接、表单控件、对话框和动态内容必须保留正确语义、焦点状态和可见的 focus 样式。
- 设计移动优先的响应式布局，并同时处理 hover、focus-visible、disabled、loading、error 和暗色模式等实际状态；不要只为静态截图优化。
- 当一组 utility 表达稳定、可复用的语义时，提取为组件或项目已有的样式抽象；不要为了缩短 class 字符串而隐藏布局和交互意图。
- 动态 class 必须能被构建工具静态发现。需要根据数据生成样式时，使用有限的映射表或项目已有的 safelist 策略，避免拼接任意 class 名。
- 修改主题、插件、预处理或构建配置后，运行项目实际的构建与界面验证；不要在未确认的情况下全局重排 class 或切换 CSS 方案。

## 交付与边界

说明使用的 token、响应式与交互状态、无障碍处理和验证方法。组件状态、数据获取与路由属于 React/Vue 或项目技能的职责；品牌视觉与设计系统规范应以项目资产和文档为准。
