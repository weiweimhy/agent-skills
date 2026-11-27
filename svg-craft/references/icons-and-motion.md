# 工程图标库与动效规范（Icons & Motion）

---

## 一、内置 24×24 标准工程图标库（Lucide 几何风格）

**铁律**：不要让模型凭空手绘复杂贝塞尔插画，也**不要在工程 SVG 中插入彩色 Emoji**（跨平台字体不一致、破坏工程审美）。

使用时把所需图标放进 `<defs>` 作为 `<symbol id="ic-xxx" viewBox="0 0 24 24">`，并在 `<symbol>` 内包裹 `<g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">`；调用处通过 `<g transform="translate(x, y)" color="#93C5FD"><use href="#ic-xxx" width="20" height="20" /></g>` 复用，保证各浏览器与独立 SVG 查看器继承 `currentColor` 一致：

```xml
<symbol id="ic-table" viewBox="0 0 24 24">
  <g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
    <rect x="3" y="3" width="18" height="18" rx="2" />
    <path d="M3 9h18M3 15h18M9 3v18" />
  </g>
</symbol>
```

| 图标名 | 适用语义 | 24×24 标准矢量路径 |
|---|---|---|
| `ic-cpu` | VM / 引擎 / 处理器 / 核心逻辑 | `<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 15h3M1 9h3M1 15h3"/>` |
| `ic-database` | 数据库 / 持久化 / 堆存储 | `<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14c0 1.66 4.03 3 9 3s9-1.34 9-3V5"/><path d="M3 12c0 1.66 4.03 3 9 3s9-1.34 9-3"/>` |
| `ic-layers` | 分层 / 栈帧 / 数组区 / 架构层 | `<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 12 12 17 22 12"/><polyline points="2 17 12 22 22 17"/>` |
| `ic-code` | 源码 / 字节码 / 函数 / 编译器 | `<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>` |
| `ic-box` | 结构体 / 对象 / 容器 / 模块 | `<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5M12 22V12"/>` |
| `ic-table` | 表结构 / 哈希表 / 矩阵 | `<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18"/>` |
| `ic-link` | 指针 / 引用 / 链表关系 | `<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>` |
| `ic-zap` | 缓存 / 快速路径 / 触发器 / 事件 | `<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>` |
| `ic-shield` | 安全 / 鉴权 / 写屏障（Barrier） | `<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>` |
| `ic-recycle` | 垃圾回收（GC）/ 周期循环 | `<path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/>` |
| `ic-server` | 服务节点 / 后端 / 运行时 | `<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/>` |
| `ic-globe` | 客户端 / 外部网络 / Web | `<circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>` |
| `ic-git-branch` | 分支 / 状态转换 / 决策 | `<line x1="6" y1="3" x2="6" y2="15"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 0 1-9 9"/>` |
| `ic-terminal` | CLI / 调试器 / 日志 | `<polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/>` |
| `ic-alert` | 陷阱 / 异常 / 性能瓶颈 | `<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>` |
| `ic-check` | 结论 / 通过 / 命中 | `<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>` |

> 需要其他图标时优先从开源图标库（Lucide / Tabler / Phosphor）提取标准 24×24 路径，不要手工盲拼复杂曲线。

---

## 二、动效模式 A · 交互与视频分层契约（`--motion`）

当 SVG 将嵌入网页演示、交互文档或代码驱动的视频时间轴（如 `render(t)` / 逐步揭示）时，遵循以下 DOM 契约：

### 1. 标准顶层分组顺序

```xml
<svg viewBox="0 0 1280 720" xmlns="http://www.w3.org/2000/svg">
  <defs>...</defs>
  <g id="layer-bg">...</g>
  <g id="layer-regions">...</g>
  <g id="layer-edges">...</g>
  <g id="layer-nodes">...</g>
  <g id="layer-overlay-edges">...</g>
  <g id="layer-annotations">...</g>
  <g id="layer-legend">...</g>
</svg>
```

### 2. 元素控制钩子约定

- **语义 ID**：每个可独立控制的对象都带可读短 ID，如 `id="node-header"`、`id="edge-array-ptr"`、`id="callout-summary"`。
- **节拍标注**：添加 `data-step="0"`、`data-step="1"`、`data-step="2"` 表示归属演示的第几拍；可用 `data-group="..."` 批量高亮同类对象。
- **路径描边绘制**：需做线条生长动效的 `<path>` 加 `class="anim-edge"` 与归一化 `pathLength="1"`（驱动方直接设置 `stroke-dasharray: 1` 与 `stroke-dashoffset: 1 - progress`，无需测量真实像素长度；若具体项目脚手架约定 `pathLength="100"` 则按项目约定覆盖）。
- **聚焦高亮（Spotlight）**：每个独立节点必须是完整 `<g>`（包含底框、图标、文字），便于演示层一键切 `opacity: 1` vs `0.22`。
- **防破坏可动画性**：压缩时禁止移除 `id`、`class`、`data-*` 和语义 `<g>`，也不要把不同节拍的元素合并进同一条 `<path>`。

---

## 三、动效模式 B · 独立文档 SMIL 动图规范（`<animateMotion>`）

当 SVG 作为独立 `.svg` 嵌入 Markdown 笔记或网页，希望在无 JS 环境下用 SMIL 光点引导视线时，**必须遵守以下防双重偏移规则**（`lint-svg.mjs` 会自动按 DOM 校验拦截违规写法）：

1. **静态帧 100% 完整**：不支持 SMIL 的预览器里，所有节点、字段名、箭头与因果标注必须已完整呈现；动效只做辅助引导。
2. **W3C `<animateMotion>` 防双重偏移安全写法**：按 W3C 规范，`<animateMotion>` 的位移会**叠加**在宿主 `cx`/`cy` 和祖先 `<g transform="translate(...)">` 上：
   - **写法 A（首选）**：保留静态 `cx`/`cy`，`path` 从 `M 0 0` 起算相对位移：
     ```xml
     <circle cx="292" cy="166" r="4.5" fill="#22D3EE">
       <animateMotion dur="2.2s" repeatCount="indefinite" path="M 0 0 L 30 0" />
     </circle>
     ```
   - **写法 B（带滤镜或局部坐标系）**：外包 `<g transform="translate(x0, y0)">` + 原点圆点 + 相对 `path="M 0 0 ..."`。
   - **严禁**：非零 `cx`/`cy`（或非零祖先 `translate`）再配绝对画布 `path="M x0 y0 ..."` 或 `<mpath href="..."/>`（动画时双倍坐标飞出画布）；也严禁无外层 `translate` 时把静态 `cx`/`cy` 写成 `0,0`（静态帧光点全堆左上角）。
3. **双态视觉验收**：先运行 `render-preview.mjs --freeze` 确认 `t=0` 静态帧无误，再去掉 `--freeze` 核查运动中光点未飞出走廊。
