# 深色技术原理 SVG 动图规范卡（随取速查版）

> 适用场景：内存字节布局、双栏地址/指针映射、位段拆解、多阶段并发演化与复杂结构嵌套图。仅需高层路线或简单调用时序时优先用 Mermaid。单张 SVG 的设计系统、通用图标库及无头浏览器 PNG 实渲看图闭环可直接配合全局 `svg-craft` 技能（其 `lint-svg.mjs` 与 `render-preview.mjs --freeze` 已原生支持下文的 `<animateMotion>` 防双重偏移检测与静态首帧验收）。

## 1. 标准深色画布与 CSS 模板

- **画布尺寸**：横版 `viewBox="0 0 W H"`，常用 `920×560`、`960×560`、`960×620` 或横向窄条 `880×420`。
- **核心色板与字体栈**：

```xml
<defs>
  <style>
    .bg { fill: #0f172a; }
    .panel { fill: #1e293b; stroke: #334155; stroke-width: 1.5; }
    .codebox { fill: #0f172a; stroke: #475569; stroke-width: 1; }
    .legend { fill: #111827; stroke: #334155; stroke-width: 1; }
    .title { font-family: "Segoe UI", "Microsoft YaHei", sans-serif; font-size: 18px; font-weight: 700; fill: #f8fafc; }
    .subtitle { font-family: "Segoe UI", "Microsoft YaHei", sans-serif; font-size: 12px; fill: #94a3b8; }
    .card-title { font-family: "Segoe UI", "Microsoft YaHei", sans-serif; font-size: 12.5px; font-weight: 700; fill: #f8fafc; }
    .body { font-family: "Segoe UI", "Microsoft YaHei", sans-serif; font-size: 11px; fill: #cbd5e1; }
    .mono { font-family: Consolas, "Cascadia Mono", monospace; font-size: 10.5px; font-weight: 600; fill: #e2e8f0; }
    .flow { fill: none; stroke-width: 2.2; stroke-dasharray: 5 4; }
  </style>
</defs>
```

- **六色语义高亮（描边 / 标题底 / 强调文字）**：
  - **蓝（主架构 / 蓝图）**：`#38bdf8` / `#0c4a6e` / `#7dd3fc`
  - **青（数据 / 结构演化）**：`#22d3ee` / `#164e63` / `#67e8f9`
  - **琥珀（偏移 / 转换 / 跳转）**：`#f59e0b` / `#78350f` / `#fbbf24`
  - **绿（实测命中 / 验证通过）**：`#22c55e` / `#14532d` / `#4ade80`
  - **红（边界 / 拦截 / 误判提醒）**：`#f87171` / `#7f1d1d` / `#fca5a5`
  - **紫（高级机制 / 元数据）**：`#a78bfa` / `#4c1d95` / `#c4b5fd`

## 2. 静态帧与防溢框纪律

1. **静态帧信息 100% 完整**：不支持 SMIL 动画的 Markdown 预览器里，所有数值、字段名、箭头因果关系必须已完整呈现；动效只负责引导视线沿走廊通道移动，不承担遮蔽或补出核心文字的职责。
2. **字符宽度估算**：汉字宽度 ≈ `font-size`，等宽 ASCII ≈ `0.6 × font-size`；每个内嵌盒子右边界至少留 `12px` 安全边距，多行文字行距 ≥ `17px`。
3. **路径通道隔离**：虚线箭头与光点只穿过卡片间隙走廊，不横穿卡片内文字。

## 3. W3C `<animateMotion>` 防双重偏移安全模板

> 按 W3C SVG 规范，`<animateMotion>` 产生的平移会**叠加**在宿主元素自身的 `cx`/`cy` 和祖先 `<g transform="translate(...)">` 上。

### 写法 A：保留静态 `cx`/`cy` + 相对 `path`（首选）

`path` 从 `M 0 0` 起算，后续每个坐标点减去起点 `(x0, y0)`：

```xml
<path d="M 292 166 L 322 166" class="flow" stroke="#38bdf8"/>
<circle cx="292" cy="166" r="4.5" fill="#38bdf8">
  <animateMotion dur="2.2s" repeatCount="indefinite" path="M 0 0 L 30 0"/>
</circle>
```

### 写法 B：外包 `<g translate(x0, y0)>` + 原点圆点 + 相对 `path`

适用于给光点挂滤镜或局部坐标系分组：

```xml
<path d="M 301 174 L 331 174" class="flow" stroke="#a78bfa"/>
<g transform="translate(301, 174)">
  <circle cx="0" cy="0" r="5" fill="#a78bfa" filter="url(#glow)">
    <animateMotion path="M 0 0 L 28 0" dur="2.6s" repeatCount="indefinite"/>
  </circle>
</g>
```

### 严禁写法（会被自动 QA 拦截）

- 禁止在非零 `cx`/`cy`（或非零祖先 `translate`）圆点里写画布绝对路径 `path="M x0 y0 ..."` 或挂绝对路径 `<mpath href="..."/>`（动画时双倍坐标飞出画布）。
- 禁止为迁就绝对 `<mpath>` 把无外层 `translate` 的圆点静态 `cx`/`cy` 写成 `(0, 0)`（静态帧光点全部堆死在左上角）。
- 禁止依赖纯文本正则校验 `<animateMotion>`，务必按 `[xml]` DOM 解析检查有效节点（屏蔽注释残留）。
