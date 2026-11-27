---
name: svg-craft
description: Design, author, lint, and visually verify clean native SVGs (architecture diagrams, memory and data-structure layouts, mechanism pipelines, Bento cards, comparison figures, and layered motion-ready or SMIL-animated SVGs) with zero-dependency Node scripts and local headless Edge/Chrome rendering. Use when creating or refining technical diagrams, visual cards, or vector assets across notes, docs, slides, or motion projects.
---

# SVG Craft · 跨项目原生 SVG 制作与实渲验收

把抽象概念、代码结构、系统架构或知识要点，转化为**审美克制、XML 合法、可无损缩放、可直接嵌入文档或动效项目**的原生 `.svg` 文件。

核心原则：**先定设计系统（Token + `<defs>`），再按网格算清坐标，最后必须经由静态质检 + 本地无头浏览器实渲看图闭环验收**。绝不凭感觉盲写坐标就直接交付。

## 适用范围与工具边界

| 需求类型 | 用 `svg-craft`？ | 说明 / 替代方案 |
|---|---|---|
| 系统架构图、流程图、状态机、时序图、ER 图 | ✅ 首选 | 语义色板 + 正交圆角走线 + 防压线标签 |
| 内存布局、结构体字段、指针链、栈帧 / GC 状态图 | ✅ 首选 | 等宽偏移列 + 锚点圆点 + 清晰指针通路 |
| Bento 信息卡片、二元对比图、学术方法总览图 | ✅ 首选 | 模块化网格 + 克制配色 + 数据可视化元素 |
| 网页 / 视频分步动效资产，或文档内 SMIL 动图 | ✅ 首选 | 启用 `--motion` 分层模式或遵守 `<animateMotion>` 安全写法 |
| 极简几何 Logo / 24×24 工程图标 | ✅ 适用 | 优先复用标准几何网格与内置图标库 |
| 写实人物、照片级产品、复杂手绘插画 / 场景 | ❌ 不要硬写 SVG | 改用宿主图像工具或项目级生图技能，禁止把含文字大图直接矢量化 |

## 六步闭环工作流

```text
1. 明确画布与载体 → 静态文档 / Markdown 笔记 / 16:9 演示 / 竖版卡片，确定是否需要动效分层或 SMIL 动图
2. 选定视觉基线   → 读取 references/design-system.md 选定一套主题与 <defs> 模板（不混搭多套主题）
3. 规划网格与坐标 → 先算清分区、节点宽高、间距与连线锚点（禁止边写边猜坐标）
4. 编写原生 SVG   → 顶部 <defs> 设计系统 + 显式 xmlns/viewBox + 语义 <g> 分层 + 手动 <tspan> 换行
5. 静态 lint+实渲 → 运行 lint-svg.mjs 与 render-preview.mjs 生成 PNG，再用多模态读图亲自核查
6. 修正瑕疵再交付 → 发现溢字/压线/对齐问题后修改 SVG 并重新 lint + render 复查，零硬伤再交付
```

> **铁律**：第 5 步**不可跳过**。若当前环境缺少可用 Edge/Chrome 浏览器，必须明确声明“未完成实渲目视验收”，绝不把静态 lint 通过冒充视觉验收通过。

## 按需读取的参考文档

| 文件 | 何时读取 | 内容摘要 |
|---|---|---|
| [`references/design-system.md`](references/design-system.md) | **每次必读** | 3 套精选主题（深色科技 / 暖纸编辑 / 学术浅白）、`<defs>` 资产模板、字号阶梯、XML 兼容与微质感技巧 |
| [`references/diagram-patterns.md`](references/diagram-patterns.md) | 按图形类型选读 | 架构图、内存结构体布局、机制管线、Bento 卡片、二元对比图的网格尺寸、避坑与打样边界 |
| [`references/icons-and-motion.md`](references/icons-and-motion.md) | 需图标或动效时读 | 16 个 24×24 工程矢量图标 `<symbol>` 库、Web/视频分层动效契约（`--motion`）与 SMIL `<animateMotion>` 防双重偏移规则 |

完整深色内存布局标杆写法参考 [`examples/memory-layout-dark.svg`](examples/memory-layout-dark.svg)。

## 10 条美学与工程底线

1. **明确 `xmlns`、`viewBox` 与网格**：16:9 演示默认 `0 0 1280 720`（或 `1920 1080`），技术笔记横图常用 `0 0 1200 720` / `960 560`，竖版卡片默认 `0 0 800 1000`。所有坐标落到 `8px`（或 `4px`）网格。
2. **禁止纯黑与刺眼纯白底**：深色用 `#0F172A` / `#0B0F19`，浅色用 `#F8FAFC` / `#F5F2EC` / `#FAFAF9`。
3. **色彩克制（60-30-10）**：按语义角色编码，单图主色板 ≤ 4–5 种，高饱和强调色仅聚焦核心结论（同屏 ≤ 2 处）。
4. **顶部建 `<defs>` 设计系统**：统一声明 `<pattern>`、锐利 `<marker>`、渐变与柔和 `<filter>`，拒绝重复手写杂乱内联样式；所有 `url(#id)` 与 `href="#id"` 必须指向已存在且唯一的 `id`。
5. **留白 ≥ 25%–30%**：外边距至少 `40–56px`，卡片内边距 `16–24px`，单张图核心节点控制在 **5–12 个**；超 15 个必须分层或拆图。
6. **连线不穿框不压字**：优先正交圆角折线（`L` + `Q`）或平滑三次贝塞尔（`C`）；端点精准落到节点边框或锚点；线上标签用与底色同色的圆角垫底框隔开线条。
7. **文本防溢出、XML 转义与显式字体栈**：
   - 无衬线：`'PingFang SC', 'Microsoft YaHei', 'Noto Sans SC', system-ui, -apple-system, sans-serif`
   - 等宽：`'JetBrains Mono', 'Cascadia Code', 'Fira Code', Consolas, monospace`
   - 多行文本手动拆 `<tspan>`；汉字按 `1.0 × fontSize`、ASCII 按 `0.58 × fontSize` 估算宽度，左右各留 ≥ `16px` 余量；文本和属性中的 `&` / `<` 必须转义为 `&amp;` / `&lt;`。
8. **禁止用彩色 Emoji 充当工程图标**：使用 `references/icons-and-motion.md` 中的 24×24 几何矢量图标。
9. **语义分层与动效安全**：按渲染顺序组织 `layer-bg` → `layer-regions` → `layer-edges` → `layer-nodes` → `layer-overlay-edges`（可选）→ `layer-annotations` → `layer-legend`。若含 SMIL `<animateMotion>`，必须保证静态帧 100% 完整且路径从 `M 0 0` 相对起算防双重偏移。
10. **必须实渲读图验收**：先跑 `lint-svg.mjs`，再跑 `render-preview.mjs` 出 PNG，用读图工具检查无重叠、无裁切、无对齐歪斜后再交付。

## 内置质检与渲染命令（零外部 npm 依赖）

脚本位于 `<skill-dir>/scripts/`（全局部署后默认为 `~/.agents/skills/svg-craft/scripts/`），支持 Windows PowerShell、macOS 与 Linux：

```powershell
# 1. 静态 XML 与规范检查（检查 XML 转义/闭合、xmlns、viewBox、纯黑/纯白、重复 id、悬空引用、卡片与画布溢字、矩形重叠、Emoji 与 animateMotion 双重偏移）
node "<skill-dir>/scripts/lint-svg.mjs" path/to/diagram.svg
# 面向交互/视频的分层动效检查：
node "<skill-dir>/scripts/lint-svg.mjs" path/to/diagram.svg --motion

# 2. 本地无头 Edge/Chrome 渲染为高清 PNG（默认输出到系统临时目录，不污染当前项目仓库）
node "<skill-dir>/scripts/render-preview.mjs" path/to/diagram.svg
# 检查 SMIL/CSS 动图的静态首帧（t=0），或显式指定输出路径：
node "<skill-dir>/scripts/render-preview.mjs" path/to/diagram.svg --freeze --scale 2 --out "$env:TEMP/preview.png"
```

## 视觉验收检查清单

打开 `render-preview.mjs` 输出的 PNG 后逐项确认，发现任意瑕疵立即修改并重新 lint + render：

- [ ] **文字**：无裁切、无撞边、无重叠，字号层级清晰，无未转义符号或乱码回退。
- [ ] **连线与箭头**：起终点贴合边框或锚点，无悬空穿框，箭头不盖字，连线标签清晰可读。
- [ ] **对齐与留白**：同行同列边缘对齐、间距一致、留白舒适、图例不遮挡主体。
- [ ] **配色与对比度**：文字在底色上高可读，焦点明确，无刺眼霓虹或发灰暗沉。
- [ ] **动效就绪（如适用）**：`--motion` 模式下独立元素由完整 `<g id="...">` 包裹；SMIL 动图 `--freeze` 静态首帧信息 100% 完整。

## 跨技能协作

- **配合 `tech-deepdive-note-workflow` / `tibishu-notes`**：系列技术笔记的单张 SVG 绘制与视觉验收使用本技能；全库批量巡检（断链、Frontmatter、实验产物与全库 SVG 检查）仍由对应笔记技能的 QA 脚本执行。
- **交付前压缩**：如需 SVGO 压缩用于网页发布，动效 SVG 必须保留 `id`、`class`、`data-*` 和语义 `<g>`（禁用 `cleanupIds` / `collapseGroups`）。
