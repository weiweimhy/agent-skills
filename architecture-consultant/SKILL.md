---
name: architecture-consultant
description: Help decide system-level architecture, technology choices, service boundaries, scalability or reliability tradeoffs, and architecture decision records. Use when a decision has meaningful cross-system consequences; use backend-patterns or a language skill for local implementation design.
---

# 架构决策咨询

用于影响系统边界、技术栈、团队维护成本、扩展方式或可靠性的设计决策。先收集当前结构和真正约束，再围绕需要做出的决策组织分析；小范围实现问题交给相应的工程技能。

## 决策方式

- 明确目标、不可变约束、当前系统事实和未知假设。仅提出会改变推荐结论的问题；其余未知可以作为假设继续分析。
- 只比较当前可行且会影响决策的方案。围绕复杂度、团队能力、迁移成本、可靠性、性能和运营负担说明取舍，并给出有条件的推荐。
- 先评估满足目标的简单方案；不要因为流行或未经验证的未来需求而增加服务、存储或中间件。
- 需要留下可追溯决定时提供 ADR，包含背景、决策、关键备选项、理由和后果。只有图能帮助沟通边界或数据流时再绘制 Mermaid/C4 图。
- 区分事实、假设和待验证风险；不要把模式名称或未经核实的数据当作决策依据。

## 交付

按决策复杂度给出简短建议、对比表或 ADR 草稿，并标明后续验证点。
局部后端结构和运行时模式见 [backend-patterns](../backend-patterns/SKILL.md)；
需求范围与验收见 [product-manager](../product-manager/SKILL.md)。

## 参考资料

- [Architecture Decision Records](https://adr.github.io/)
- [C4 Model](https://c4model.com/)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
