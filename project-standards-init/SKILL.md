---
name: project-standards-init
description: Initialize or refresh project-specific AGENTS.md and engineering documentation from repository facts and matching Tibishu standards. Use for new-project setup, onboarding, or rebuilding project conventions; not for routine feature work.
---

# 项目规范初始化

为当前仓库建立与真实技术栈一致、可执行且可维护的协作规范和工程文档。将通用知识库作为经验来源，而不是项目事实来源。

## 适用范围

- 用户要求初始化新项目、补齐或重建 `AGENTS.md`、架构文档、开发文档或项目技术规范。
- 仓库已经存在，或用户已提供足以确认技术栈、项目目标和输出位置的项目说明。

不用于日常功能修改、单篇文档润色，或尚未提供仓库与项目事实的纯技术选型讨论。

## 工作流

1. 先检查根目录、现有 `AGENTS.md`、README、目录结构、依赖与构建配置、启动入口、测试和现有文档。记录可验证的项目事实、已有有效约定和待确认信息；不要从文件名或用户预期推断技术已被采用。
2. 使用 `tibishu-note-search` 按项目类型、技术名、笔记名称和标签精确检索工程规范库。先看名称和 Blog front matter，只有无法判断时才阅读候选正文。仅选择已由仓库事实证实的规范。
3. 在任何写入前输出简短的“适用规范、项目事实、待确认项、文档计划”。
   若缺少会影响文档范围的关键事实，保留“待确认”而不编造。
   仅在无法安全继续时请求用户补充。
4. 根据已选规范和仓库事实创建或更新项目文档。保留已有有效约定，说明真实冲突。
   选择维护成本更低、与当前项目更一致的方案。
   交付物的选择条件和内容边界见 [文档契约](references/document-contract.md)。
5. 通过仓库实际提供的命令验证安装、启动、格式化、测试和构建说明。
   未知命令标记为“待补充”，不得捏造。
   对新增或修改的 Markdown 使用可用 lint 工具检查；没有工具时做人工检查并说明限制。
6. 汇总采用的知识库笔记、创建或更新的项目文件、关键架构约定、待确认事项和推荐的后续开发顺序。

## 约束

- `AGENTS.md` 必须简洁、直接可执行，并针对当前仓库改写；不得机械复制通用笔记全文。
- 仅创建实际采用的语言、框架、服务和存储的规范文件；不创建空的 ADR，也不凭空假设接口、数据库、Redis、Nginx、Tailwind、Lua 或 Wails。
- 文档必须区分项目专属事实与通用经验。除非用户明确要求且规则已证实具有普适价值，否则不修改 Tibishu 工程规范库。
- 不修改或记录 `.env`、`.evn`、令牌、密钥、个人数据和其他敏感信息。
- 不覆盖用户已有文档；需要改写时保留有价值内容，删除过时或重复内容，并说明影响。
