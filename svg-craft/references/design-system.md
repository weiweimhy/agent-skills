# SVG 设计系统（Design System）

制作高颜值原生 SVG 的第一原则：**先定 Token 和 `<defs>`，再画第一个 `<rect>`**。本文件提供 3 套主题色板、即插即用的 `<defs>` 资产模板、字号阶梯、独立 XML 兼容基线与微质感手法。

---

## 一、三套精选主题色板

根据内容载体选定一套，不要把多套主题混着调。

### 主题 A · 深色工程科技（Dark Engineering）
> 适合：系统架构、虚拟机 / 内存 / GC 原理、协议与底层机制、深色技术笔记与演示视频。

| Token | 色值 | 用途 |
|---|---|---|
| `bg-canvas` | `#0F172A`（或 `#0B0F19`） | 画布主底色（禁止纯黑 `#000000`） |
| `bg-grid` | `#1E293B` | 32px 背景网格线 / 点阵 |
| `bg-surface` | `#162033` | 通用暗卡片底色 |
| `border-subtle` | `#334155` | 次级分割线 / 区域虚线框 |
| `text-primary` | `#F1F5F9` | 主标题、核心节点名 |
| `text-secondary` | `#94A3B8` | 副标题、次级说明、连线标注 |
| `text-muted` | `#64748B` | 图例辅助字、内存偏移刻度 |

**按语义角色编码的 6 个柔和强调色（填充用 `12%–15%` 透明度，边框用 `100%` 描边，文字用浅一档色阶）：**

| 语义角色 | 边框 / 图标色 | 文字浅色 | 填充色（RGBA） | 适用场景 |
|---|---|---|---|---|
| 入口 / 指针 / 活跃路径 | `#22D3EE` (Cyan) | `#67E8F9` | `rgba(34,211,238,0.12)` | 客户端、入口、当前高亮焦点 |
| 控制流 / API / 调度 | `#60A5FA` (Blue) | `#93C5FD` | `rgba(96,165,250,0.12)` | 网关、指令分发、控制平面 |
| 核心逻辑 / 正常状态 | `#34D399` (Emerald) | `#6EE7B7` | `rgba(52,211,153,0.12)` | 业务模块、活跃对象、成功路径 |
| 存储 / 内存结构 / 表 | `#A78BFA` (Violet) | `#C4B5FD` | `rgba(167,139,250,0.12)` | DB、缓存、Heap / Map、元数据 |
| 队列 / 异步 / 缓冲 | `#FB923C` (Orange) | `#FDBA74` | `rgba(251,146,60,0.12)` | MQ、冲突链、写屏障、异步事件 |
| 风险 / 拦截 / 回收 | `#FB7185` (Rose) | `#FDA4AF` | `rgba(251,113,133,0.12)` | 鉴权、异常、边界告警、待回收对象 |

> 若为 `tech-deepdive-note-workflow` 系列技术笔记配深色图，沿用同一 `#0F172A` 深岩蓝底色家族即可；横版紧凑笔记常用 `viewBox="0 0 960 560"` 或 `920 560`，宽屏演示常用 `1280 720`。

---

### 主题 B · 暖纸编辑风（Warm Editorial / Bento）
> 适合：知识卡片、Bento 便当格信息图、二元对比图、科普教学与社交长图。

| Token | 色值 | 用途 |
|---|---|---|
| `bg-canvas` | `#F5F2EC` | 暖纸画布底色 |
| `bg-card` | `#FFFDF9` | 主内容卡片底色 |
| `tint-sand` | `#EBE3D5` | 辅助模块底色 1（沙米色） |
| `tint-sage` | `#DCE6D8` | 辅助模块底色 2（鼠尾草绿） |
| `tint-blue` | `#DBE5F0` | 辅助模块底色 3（雾霾蓝） |
| `tint-peach` | `#F4E1D6` | 辅助模块底色 4（暖桃色） |
| `border-card` | `#E2DCD0` | 极细 1px 卡片描边 |
| `text-primary` | `#1C1917` | 墨黑主文字 |
| `text-secondary` | `#57534E` | 正文与副标题 |
| `accent-hero` | `#D94E3B`（朱红）或 `#2563EB`（群青） | **全图最多出现 2 处**，只标核心结论/数字 |

---

### 主题 C · 学术出版浅白（Academic / Technical Light）
> 适合：论文方法总览图、白底技术博客、PDF 讲义、README 文档插图（单色打印友好，在暗色 Markdown 页面中仍清晰可读）。

| Token | 色值 | 用途 |
|---|---|---|
| `bg-canvas` | `#F8FAFC` | 柔和浅灰白画布（禁止刺眼 `#FFFFFF` 纯白画布底） |
| `bg-grid` | `#E2E8F0` | 极淡辅助点阵 |
| `bg-card` | `#FFFFFF` | 节点卡片底色 |
| `border-default` | `#CBD5E1` | 默认边框 |
| `text-primary` | `#0F172A` | 深岩黑文字 |
| `text-secondary` | `#475569` | 说明文字 / 连线标注 |
| `accent-1`（主色） | `#1D4ED8`（深蓝） / 底 `#EFF6FF` | 核心流程模块 |
| `accent-2`（辅色） | `#0F766E`（青绿） / 底 `#F0FDFA` | 输出 / 验证 / 数据模块 |
| `accent-3`（强调） | `#B45309`（琥珀） / 底 `#FFFBEB` | 关键改动 / 瓶颈 / 注意点 |

---

## 二、即插即用的 `<defs>` 资产模板

在 `<svg>` 顶部按需放入，**禁止每个箭头或阴影重复写样式**：

```xml
<defs>
  <!-- 1. 细腻点阵背景（深色版，浅色改 fill="#CBD5E1"） -->
  <pattern id="dot-grid" width="24" height="24" patternUnits="userSpaceOnUse">
    <circle cx="2" cy="2" r="1" fill="#1E293B" />
  </pattern>

  <!-- 2. 工程细网格背景 -->
  <pattern id="line-grid" width="32" height="32" patternUnits="userSpaceOnUse">
    <path d="M 32 0 L 0 0 0 32" fill="none" stroke="#1E293B" stroke-width="0.8" />
  </pattern>

  <!-- 3. 锐利小箭头（默认灰色 + 高亮青色 + 空心异步） -->
  <marker id="arrow-muted" viewBox="0 0 10 10" refX="8.5" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M 1 1.5 L 8.5 5 L 1 8.5 z" fill="#64748B" />
  </marker>
  <marker id="arrow-accent" viewBox="0 0 10 10" refX="8.5" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M 1 1.5 L 8.5 5 L 1 8.5 z" fill="#22D3EE" />
  </marker>
  <marker id="arrow-hollow" viewBox="0 0 10 10" refX="8.5" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M 1.5 1.8 L 8.2 5 L 1.5 8.2 z" fill="#0F172A" stroke="#64748B" stroke-width="1.3" />
  </marker>

  <!-- 4. 极柔和卡片阴影（浅色主题用 dy="4" stdDeviation="6" flood-opacity="0.08"） -->
  <filter id="soft-shadow" x="-10%" y="-10%" width="125%" height="130%">
    <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#020617" flood-opacity="0.35" />
  </filter>

  <!-- 5. 微妙顶部高光渐变（给深色卡片去塑料感） -->
  <linearGradient id="card-sheen" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.06" />
    <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.00" />
  </linearGradient>

  <!-- 6. 可选：极淡纸感噪点（用于大背景 / Bento 卡片，opacity="0.035"） -->
  <filter id="paper-grain" x="0%" y="0%" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch" />
    <feColorMatrix type="saturate" values="0" />
  </filter>
</defs>
```

---

## 三、排版与字号阶梯（1280×720 基准）

> 若画布为 `1920×1080`，字号整体乘以 `1.35–1.5`；若为紧凑笔记 `960×560`，字号乘以 `0.8–0.85`；若为竖版 `800×1000`，标题取 `30–36px`。

| 层级 | 字号 | 字重 | 行高（`<tspan dy>`） | 字体栈 |
|---|---|---|---|---|
| 主标题 | `26–32px` | `700` | `36px` | 无衬线 |
| 副标题 / 页眉标注 | `13–15px` | `400–500` | `20px` | 无衬线 / 等宽 |
| 区域标题（Region Label） | `12–13px` | `600` | `18px` | 等宽 + `letter-spacing="0.06em"` |
| 节点主名称 | `14–16px` | `600–700` | `20px` | 无衬线 / 等宽 |
| 节点副说明 / 字段值 | `11.5–13px` | `400` | `17px` | 等宽 / 无衬线 |
| 连线标注 / 图例文字 | `11–12px` | `500` | `15px` | 等宽 |

**安全文本宽度估算公式（防止中文字串撑爆框）：**
- 每个汉字 / 全角标点 ≈ `1.0 × fontSize`
- 每个拉丁字母 / 数字 / 符号 ≈ `0.58 × fontSize`（大写 `M`/`W` 约 `0.68 × fontSize`）
- 卡片最小宽度 ≥ `估算文本宽度 + 图标宽(如有) + 左右 padding(至少 32px)`

---

## 四、独立 SVG 的 XML 兼容底线与微质感技巧

### 独立 `.svg` 必守 XML 规则
1. **显式声明命名空间与底板**：根 `<svg>` 必须包含 `xmlns="http://www.w3.org/2000/svg"` 与 `viewBox`，并在 `layer-bg` 绘制显式底色矩形（避免浅色图嵌入深色 README / 笔记界面时透明发黑看不清）。
2. **严格 XML 实体转义**：文本与属性值中禁止裸写 `&`（必须写 `&amp;`）或 `<`（必须写 `&lt;`），禁止使用仅 HTML 支持的 `&nbsp;`（改用普通空格或 `&#160;`）。
3. **内嵌 `<style>` 兼容写法**：XML 正文允许单独的 `>`，但若 `<style>` 内包含 `<`、`&` 或可能触发实体/标签误解析的内容，请按 XML 转义或用 `<![CDATA[ ... ]]>` 包裹（注意 `CDATA` 内禁止出现 `]]>`）。

### 四个提升高级感的微细节
1. **顶部细装饰色条**：在浅色卡片或结构体头部加 `3–4px` 高的圆角彩色顶条（配合 `<clipPath>`），比整框涂重色克制得多。
2. **连线标签“防压线底框”**：压在线条上的标签（如 `POST /api`、`next ->`），先放略宽于文字的 `<rect rx="4" fill="<局部底色>"/>`，再放 `<text>`，让线条自然断开让出文字。
3. **线条粗细四档分化**：背景网格 `0.75px`、区域虚线框 `1.25px`（`stroke-dasharray="6 4"`）、节点边框与常规连线 `1.5px`、主高亮路径 `2.25–2.5px`。
4. **圆润拐角与圆头收口**：连线统一 `stroke-linecap="round" stroke-linejoin="round"`，直角拐弯用 `Q` 二次贝塞尔做 `8–12px` 圆角。
