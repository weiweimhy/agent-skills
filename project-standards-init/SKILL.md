---
name: project-standards-init
description: Initialize or refresh project-specific AGENTS.md and engineering documentation, or maintain reusable standards templates. Ground project docs in repository facts, including native Android Kotlin/Compose templates and scoped UI contracts. Use for setup or standards work, not routine feature work.
---

# 项目规范初始化

为仓库建立与真实技术栈一致、可执行、低维护成本的协作规范与工程文档。通用经验与知识库只作参考，**仓库事实与用户明确授权才是唯一依据**。

## 适用范围与任务模式

- **全量初始化**：建立或重建项目 `AGENTS.md` 与必要的 `docs/` 文档。
- **局部刷新**：用户限定了特定文件或章节（例如仅更新 `AGENTS.md`）时，只检查与修改目标范围，不顺带做全仓审计或额外新建文档。
- **可复用模板**：维护供其他项目使用的模板资产与占位符，不把存放模板的仓库当作已采用该技术的业务应用。

不用于日常功能开发、单篇文档润色或缺乏仓库事实的纯技术选型闲聊。范围不清时，按用户点名的文件做局部处理。

## 核心铁律（五条不变量）

1. **事实优先**：仅从代码、依赖清单、配置、脚本、CI、现有文档和用户确认中提取事实；不得从目录名、已安装 Skill/MCP、知识库笔记或组件库存在推断某项技术、图标系统、设计方向或验收工具已被采用。
2. **计划与实现分离**：空仓库或新规划中已选定但未落地的技术/设计/命令，必须明确标为“已选定／尚未实现”或“未验证”，绝不虚构脚本、入口或验收能力。
3. **授权边界守恒**：初始化只制定与连接规范，不自动安装依赖、生成业务页面、新增项目 Skill 或 CI 工作流（除非用户本轮明确授权实现）。
4. **保真不覆写**：保留既有有效约定，说明真实冲突；`AGENTS.md` 保持简洁可执行，详细设计链接至 `docs/`，不机械复制通用文档全文。
5. **敏感信息零写入**：不读取或记录 `.env`、令牌、密钥和个人数据。

## 按需加载参考契约

按当前项目已证实的技术栈与任务范围读取对应参考，不要无条件全量读取：

- **基础文档与前端判定（必读）**：[文档契约](references/document-contract.md) — 决定文档生成条件、前端模式分支及按需修复建议规则。
- **Web/前端 UI 范围**：进入 UI 范围后读取 [前端设计契约](references/frontend-design-contract.md)；需追溯外部参考取舍时读取 [GitHub 来源与取舍](references/frontend-sources.md)。按真实产品任务推导页面形态，不预设固定后台布局或特定 UI 组件库。
- **Android / Kotlin 原生项目**：仓库证实使用 Android/Kotlin 或用户指定 Android 模板时，读取 [Android 初始化模板](references/android-project-template.md)，只裁剪并改写适用资产，不套用 Web 断点或 CSS 规则。
- **可选：个人工程规范库增强**：需要参考 Tibishu 工程规范库时，读取 [规范库按需检索与降级契约](references/tibishu-knowledge-lookup.md)；未配置或不可读时优雅降级，不阻塞初始化。

## 执行流程

1. **按模式盘点事实**：全量初始化盘点根目录、依赖/构建配置、启动入口、测试与现有文档；局部刷新仅读目标文件及相关证据；模板任务仅核对模板资产与占位符。
2. **按契约确定交付物**：依据 [文档契约](references/document-contract.md) 选择本次授权范围内确有价值的文档，未决定的技术仅列待决策，不生成空模板或悬空链接。
3. **写入并验证**：创建或更新目标文档；核实文档所述命令、内部链接与 Markdown 格式（有 lint 工具则运行，无工具则人工核对并注明限制）。
4. **相称汇总**：简明列出改动文档、关键事实依据、已执行验证及影响交付的真实缺口；仅在有充分证据且值得后续处理时给出修复建议，不为填表凑数。
