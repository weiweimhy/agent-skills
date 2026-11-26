---
name: retro-to-guardrail
description: Route a human correction, recurring bug, or workflow lesson to the lowest-cost durable guardrail—automated test, project AGENTS.md, shared skill, or agent-evals regression case—without bloating global skills. Use when asked to capture a lesson learned or prevent an agent mistake from recurring.
---

# 人工纠正沉淀路由

在用户纠正了 Agent 错误、排完一次典型故障或发现反复出现的协作摩擦后，把经验落到**成本最低、约束最硬**的层级，同时防止全局技能库再次膨胀。

## 四层沉淀优先级（由高到低，优先落在最靠前的一层）

1. **自动化测试 / 脚本 / Linter（首选）**
   - 凡是能用确定性断言判定的行为（例如旧存档兼容、API 边界、构建脚本规则、front matter 校验），一律优先补回归测试或校验脚本，不写进自然语言文档。
2. **项目级 `AGENTS.md` 或项目 `.agents/skills/`**
   - 仅属于当前仓库的架构约定、特定框架/工具链约束、目录职责、测试入口或业务术语，落到该项目自己的文档或项目技能，绝不放进全局公共库。
3. **全局共享 Skill（严格准入）**
   - 只有同时满足以下条件，才提议修改或新增全局 Skill：
     - 跨 2 个及以上项目重复出现；
     - 属于前沿强模型依然高频犯错的反直觉盲区、强个人工作流契约，或能附带确定性脚本；
     - **不是**通用教科书常识（如常规安全/容器/接口/排障原则）。
   - 优先向已有技能的按需 `references/` 增量补充 1~3 条高信号检查项，而非新建顶层技能。
4. **`agent-evals` 回归案例**
   - 若该问题属于“模型升级或改 Skill 后可能退化的路由/行为能力”，按 [agent-evals](../agent-evals/SKILL.md) 规范提炼最小可复现的 `natural_task` 案例与行为判定标准，并保持答案键隔离。

## 执行步骤

1. 用 2~3 句话提炼本次纠正的**根因与触发条件**（到底错在哪一步、为什么模型没靠常识避开）。
2. 按上述四层优先级判定唯一主落点，并简述为什么不放在更重/更泛的层级。
3. 明确告知拟修改的文件范围；涉及跨仓库修改（如从业务项目回写个人公共技能源仓库）时，先说明改动草案并取得用户确认，遵循源仓库的校验与同步规则。
