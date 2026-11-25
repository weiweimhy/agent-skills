---
name: validation-lint
description: Check configuration syntax, schemas, cross-field meaning, and environment consistency, or verify code and DTOs against an established API contract. Use for concrete validation and audit tasks; use api-design to define or change the external API contract itself.
---

# 配置与契约校验

负责检查已有规则是否被配置和实现遵守。配置字段的语义、字段间约束及环境差异由本技能归口；
API 契约由 [api-design](../api-design/SKILL.md) 设计，本技能核对路由、DTO 和响应是否符合已确定的契约。

## 校验配置

- 按项目实际的 schema、默认值和文档检查键名、类型、必填项、取值范围及字段间依赖。
- 除语法外检查配置是否有合理含义，例如互斥选项、引用目标存在性、超时关系和环境间关键差异。只将能从项目规则、代码或用户提供的约束中证明的条件报告为错误；不把猜测写成规则。
- 报告敏感配置时避免回显密钥或个人数据。区分语法错误、语义错误、可疑差异和缺少规则无法判定的项目。

## 核对 API 契约

- 对照已批准的 API 文档或约定，检查路由、方法、字段名与类型、可选/空值语义、边界、状态码和错误结构。
- 确认兼容性变更及主要调用方影响；不要自行引入新契约或要求所有 API 采用同一种封装。
- 只在用户要求验证或代码改动确需验证时检查具体实现；不是 API 设计和一般代码审查的替代品。

## 结果格式

列出问题位置、观察到的证据、影响和建议修复。明确哪些检查通过、哪些规则未定义或无法验证；除非用户要求，不把未执行的工具检查描述为已通过。

可显式使用 `validation-lint` 执行上述配置或契约检查。一般输入校验实现应由相应的语言或后端技能处理。

## 参考资料

- [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [JSON Schema](https://json-schema.org/)
