---
name: project-standards-init
description: Initialize or refresh an AI-enabling project foundation (lean AGENTS.md, optional DESIGN.md, scoped docs, and executable verification harness) or maintain reusable standards templates. Grounded in repository facts to amplify AI judgment without over-constraining it. Use for setup or foundation work, not routine feature work.
---

# 项目基座初始化

为仓库建立**赋能 AI、而非限制 AI** 的轻量化项目基座（Project Foundation）：用高信噪比的导航地图、可执行验证闭环、标杆样例指针与隐形踩坑提示放大 AI 的工程与审美发挥，而不是堆砌通用说教或官僚审计表。

## 核心定位：基座，而非牢笼

好的项目基座只回答四个问题，其余空间留给 AI 自主判断：

1. **去哪看（Map & Accelerators）**：关键入口、标杆样例（Golden Samples）、已有公共工具与生成物边界，避免 AI 盲猜或重复造轮子。
2. **怎么验（Fast Feedback Harness）**：实测可用的局部快速检查与防卡死命令，让 AI 靠真实反馈自纠，而不是靠冗长文字祈祷。
3. **避什么坑（Gotchas & Invariants）**：只写代码局部看不出的系统不变量与反直觉陷阱，并附一句原因（Explain the why），帮助 AI 正确迁移判断。
4. **边界在哪（Always / Ask First / Never）**：对可逆实现充分放权，只把高影响/不可逆决策（公开契约、持久化迁移、全局换肤/换架构、新增依赖）留给人确认。

## 适用模式与范围

- **全量初始化**：为仓库新建或重建项目基座（根 `AGENTS.md` 与确有价值的配套文档）。简单项目往往**只需一份精悍的 `AGENTS.md`**，不因模板齐全而制造冗余文件。
- **局部刷新**：用户限定特定文件或章节（例如“仅更新 `AGENTS.md`”或“只补 `DESIGN.md`”）时，只做目标范围增量更新，保留团队既有手写经验，不扩成全仓改造。
- **可复用模板**：维护供其他项目裁剪使用的模板资产与占位符，不把模板所在仓库当作业务应用。

不用于日常功能开发、单篇文档润色或缺乏仓库事实的纯选型闲聊。范围不清时优先按用户点名的文件做局部处理。

## 四条底线（轻量但刚性）

1. **赋能优先于限制**：删掉前沿模型已内化的通用常识（如“写干净代码”“注意测试”）与微观步骤管控；能交给 Linter、Typechecker 或测试兜底的规则不靠 Markdown 叮嘱。
2. **地图而非百科**：根 `AGENTS.md` 控制在 **50–120 行**（理想 <1% 上下文）；大仓或复杂专题下沉至子目录 `AGENTS.md`、`DESIGN.md`、`docs/` 或 `.agents/skills/` 单跳路由，绝不生成空壳文档或悬空链接。
3. **事实与验证诚实**：命令、路径、依赖均须来自仓库实证或用户明确选定；计划采用但尚未落地的内容简明标为“计划/待实现”；绝不把未运行的命令写成已通过；绝不读写 `.env`、密钥或个人数据。
4. **授权边界清晰**：初始化聚焦基座文档与规范连接，不擅自安装依赖、生成业务代码或强加 CI 流程（除非本轮明确授权）。

## 执行流程

1. **并行只读探测**：读取根目录结构、包管理/构建/测试/Lint/CI 配置、关键入口、近期 Git 历史（捕获真实惯例与高频踩坑）以及既有规则文件（`AGENTS.md`、`CLAUDE.md`、`.cursorrules`、`.github/copilot-instructions.md` 等）。
2. **确定最小高价值交付物**：依据 [基座蓝图与裁剪契约](references/foundation-blueprint.md) 判断是否只需根 `AGENTS.md`，还是需要拆分 `DESIGN.md`、子目录 `AGENTS.md` 或专题 `docs/`。若存在影响方向且仓库无法推断的关键缺口，附推荐默认项做简短确认。
3. **按需加载参考并生成/增量合并**：按实际技术栈只读对应领域参考，编写清晰、可复制、可执行的基座文档；刷新既有文档时采用局部增量合并，不覆写有效人工规则。需要跨工具统一入口时，可按用户授权提供单行 `CLAUDE.md`（`@AGENTS.md`）。
4. **实证核验与精简汇总**：核对文档中所有路径与链接真实可达，安全且快速的检查命令尽量实际运行验证（无法运行则注明“未验证”）；汇总改动文件、核心事实依据、已执行验证，以及真正高价值的后续建议（例如可前移到 Linter/脚本的机械约束）。

## 按需加载参考（单跳渐进披露）

按当前项目已证实的技术栈与范围按需读取，无需全量加载：

- **必读核心**：[基座蓝图与裁剪契约](references/foundation-blueprint.md) — 根 `AGENTS.md` 黄金骨架、篇幅预算、分级验证命令、Golden Samples/Gotchas 写法、分层拆分与反模式清单。
- **后端 / 全栈 / 桌面 / 游戏**：[多领域基座手册](references/domain-playbooks.md) — 覆盖 Go/Rust/Python 后端与分布式系统、TypeScript 全栈与 Monorepo、Unity/C#/Lua/Wails/Tauri 等原生与游戏客户端的高信噪比基座要素。
- **Web / 前端 UI**：[前端视觉与 UI 基座](references/frontend-design-contract.md) — 以独立 `DESIGN.md`（或已有设计文档）构建审美方向、语义 Token 真源、标杆页面（Copy the sibling）与真实父容器验收。
- **Android / Kotlin 原生**：[Android / Kotlin 原生模板](references/android-project-template.md) — Kotlin/Compose/AGP/Gradle 基座与可裁剪资产，不套用 Web 规则。
- **外部依据（按需）**：[GitHub 多领域最佳实践来源](references/github-best-practices.md) — 30+ 开源仓库与实证研究的提炼依据与取舍。
- **个人规范库（可选）**：[Tibishu 工程规范库按需检索](references/tibishu-knowledge-lookup.md) — 仅作参考增强，未配置时优雅降级。
