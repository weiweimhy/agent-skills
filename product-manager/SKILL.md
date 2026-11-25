---
name: product-manager
description: Turn product ideas or incomplete requirements into focused user stories, PRDs, acceptance criteria, priorities, or task breakdowns. Use when scope or success conditions need product clarification; keep technical architecture decisions with architecture-consultant or implementation skills.
---

# 需求梳理

把用户目标整理成可以讨论、实现和验收的需求。先识别会改变范围、用户流程、优先级或验收结果的未知点；可合理推断的内容标明假设后继续，不为完整问卷而提问。

## 按需组织产物

- 小改动可直接给目标、范围和验收条件；涉及多角色或流程时写 User Story；跨模块或长期项目再整理 PRD 与任务拆解。
- 验收标准描述可观察的用户行为或业务结果。采用 Given/When/Then 有助于表达场景时再使用，不强制套模板。
- 只有有依据时才标注优先级、依赖、成功指标和估时，并注明未确定的部分。
- 技术方案只记录已知约束或待决问题，不替代架构决策和代码实现设计。

常用产物可保持精简：User Story 包含角色、目标、价值和验收条件；PRD 覆盖问题与目标、用户场景、范围、功能与非功能要求、验收和依赖；任务拆解按可独立实现与验收的成果分组，标出必要依赖。

## 常用检查

从用户、目标、场景、行为、边界和成功结果中选择与当前需求相关的问题。将推断和用户已确认的事实分开；只有答案会实质影响方案或验收时才暂停并询问。

需要比较系统方案时转向 [architecture-consultant](../architecture-consultant/SKILL.md)；
需求已明确、需要制定接口契约时参考 [api-design](../api-design/SKILL.md)。
