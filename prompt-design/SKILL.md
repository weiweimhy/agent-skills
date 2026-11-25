---
name: prompt-design
description: Design and improve prompts for LLM workflows, system prompts, few-shot examples, evaluation criteria, prompt safety, and injection resistance. Use when asked to write, review, or optimize prompts or agent instructions.
---

# Skill: Prompt Design

帮助设计和优化 LLM prompts，使模型产出更准确、一致且符合预期。把 prompt 改动当作行为改动评估。

## 触发条件

- “帮我设计一个 prompt”
- “优化这个 prompt”
- “写一个 system prompt”
- “这个 prompt 怎么改进”

## 工作方式

1. 明确任务、受众、输入边界、成功条件、输出格式和目标模型实际支持的配置。
2. 优先使用直接指令；只添加能解决已观察问题的上下文、约束和示例。保留用户已有的安全、隐私和授权边界。
3. 为可复用模板说明可变字段、默认值和输入来源；把不可信输入标记为数据，避免让其覆盖更高优先级的指令。
4. 对需要可靠性的 prompt 设计回归评估，避免仅凭措辞直觉判断效果。

## Prompt 回归检查

- 保存当前版本或基线行为，并挑选代表性输入：正常用例、关键边界、已知失败；仅在相关时加入格式逃逸或注入用例。
- 为每例写明要观察的行为和可接受差异，不把无关的逐字匹配当作成功标准。
- 在可比的模型与配置下运行修改前后的同一组输入，比较任务完成度、格式、约束遵循、安全行为和回归。报告实际运行的用例、结果与未测项。
- 无法运行时交付可执行的评测用例和验收条件，并明确标记为待测。高风险 prompt 上线前应由适用的自动或人工检查确认。
- prompt、模型或配置变化后保留已发现的反例，防止同一失败重新出现；不过度扩充无关用例。

## 常见模式

- **结构化指令**：按需明确角色、上下文、任务、约束和输出，不要求每个 prompt 都套用全部章节。
- **Few-shot 示例**：用与目标分布相符的少量正反例澄清歧义；示例数量由任务决定。
- **渐进披露**：先测试简单版本，只有评估显示缺口时再增加复杂度。
- **指令层级**：明确区分系统/任务要求与用户提供的数据；不可信输入不能成为新指令。

## 输入与输出

输入包括当前 prompt、目标任务、失败样例、模型能力、安全要求和评测条件。交付可直接使用的 prompt、关键设计理由、回归用例与结果、风险和未验证假设。

## 边界

- 不把未评估的 prompt 宣称为生产就绪。
- 不要求模型披露隐藏推理；需要可审查性时要求结论、依据摘要或结构化结果。
- 不为复杂而复杂，也不忽视输入注入、格式逃逸或示例偏差等适用风险。

## 参考

- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [OpenAI Prompt Engineering Guide](https://platform.openai.com/docs/guides/prompt-engineering)
- [Anthropic Prompt Design Guide](https://docs.anthropic.com/claude/docs/prompt-design)

## Related Skills

- [product-manager](../product-manager/SKILL.md)：澄清目标、受众和验收条件。
