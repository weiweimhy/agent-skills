---
name: doc-generator
description: Generate and update project documentation, including README, API docs, code comments, changelogs, ADRs, and handoff notes. Use when asked to write docs from code, refresh docs after changes, or make documentation accurate and maintainable.
---

# Skill: Doc Generator

从代码、接口契约和项目约定生成或更新文档，并核对内容与实现一致。

## 触发条件

- “帮我生成 API 文档”
- “写一下这个函数的注释”
- “生成 README”
- “更新 Changelog”
- “生成接口说明”

## 工作方式

1. 确认文档类型、读者、目标位置和格式；读取相关实现、契约、配置、测试及已有文档。
2. 以用户提供的需求和当前有效契约为准。区分已实现行为与计划行为；不从名称或示例臆造参数、默认值、权限、错误码或兼容性。
3. 沿用项目结构、术语和模板。若文档、实现与明确需求互相冲突，指出差异并说明采用的依据，不静默改写其中一方来掩盖问题。
4. 核对命令、链接、示例和版本信息。能在当前环境安全运行时验证关键示例；否则标为示意或待验证，不声称已执行。

## 文档类型

- **API 文档**：按适用情况说明认证、端点/操作、参数与校验、响应模型、错误、兼容性和示例；不要为了模板虚构不适用章节。
- **README**：按项目读者提供概述、经过核实的 Quick Start、功能、配置、运维或贡献信息。
- **代码注释**：说明非显而易见的原因、契约、限制和边界行为；避免复述代码，也不推测函数意图。
- **Changelog**：遵循项目现有版本与分类格式；若无约定，可用 Keep a Changelog。只列出从代码或提交记录证实的用户可见变化。
- **ADR**：记录背景、决策、考虑过的方案及后果，沿用已有编号和模板。
- **交接文档**：标明适用版本/提交、实际状态、已验证内容与未完成事项。

## 交付与校准

交付可继续编辑的文档，以及必要的依据、缺口和未验证项。文档有代码示例时，优先使用真实接口或配置；只有在受众受益且环境允许时才要求每个接口都有可运行示例。改动代码时同步检查受影响文档；改动文档时回到实现或测试核对事实。

## Related Skills

- [release](../release/SKILL.md)：Changelog 与发布说明。
- [api-design](../api-design/SKILL.md)：API 契约设计。
- [code-review](../code-review/SKILL.md)：审查文档与行为是否相符。
