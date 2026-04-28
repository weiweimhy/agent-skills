---
slug: skill-builder
name: Skill 生成器
description: 帮助创建新的 Skill 定义，优先复用已有能力，避免重复造轮子
category: utility
role: entrypoint
triggers:
  - 创建新 skill
  - 能力是否值得抽成 skill
  - skill 拆分与复用设计
inputs:
  - 用户目标与使用场景
  - 已有 skill 列表
  - 外部对标或参考能力
outputs:
  - skill 设计草案
  - 复用分析与索引更新建议
related_skills:
  - prompt-design
  - markdown
  - code-review
constraints:
  - 创建前必须先检索现有 skill 和可复用能力
  - 新 skill 必须职责单一并维护 SKILLS.md 索引
  - 禁止产出与现有 skill 高度重叠的万能型技能
---

# Skill: Skill Builder（技能生成器）

帮助创建新的 Skill 定义，在创建前会进行能力拆解、已有技能检索、复用策略分析。

## 🎯 Purpose

帮助把一个模糊的“想做某种能力”请求，转成边界清晰、可复用、可维护的 skill 设计。

## 🧩 Capabilities

- 拆解需求并判断是否值得抽成 skill。
- 检索已有能力并给出复用或组合方案。
- 生成符合仓库规范的 skill 模板与索引更新建议。

## 🧠 Usage

- 在准备新增或重构 skill 时使用。
- 在怀疑能力是否重复、过大或职责不清时使用。
- 在需要对齐仓库规范和索引结构时使用。

## 📥 Input

- 用户目标、场景和期望输出。
- 当前技能库中已存在的相关 skill。
- 外部对标能力或参考实现。

## 📤 Output

- 新 skill 的结构化设计草案。
- 复用分析、拆分建议和相关 skill 关系。
- 需要同步更新的索引与文档项。

## 🎯 触发条件

当用户说：

- "帮我做一个 xxx 的 skill"
- "我想要一个可以 xxx 的能力"
- "这个能力该不该单独做成 skill"

👉 自动启用本 Skill

## 🧠 工作流程

### Step 1：能力拆解

解析用户输入，提取：

- **核心目标**：这个 Skill 要解决什么问题？
- **子能力列表**：需要哪些具体能力？
- **使用场景**：什么时候会用到？
- **输入 / 输出形式**：期望的输入输出是什么？

> [!TIP]
> 将复杂能力拆分成多个原子能力，有助于后续复用判断

### Step 2：检索已有技能（必须执行）

**检索顺序**（优先本地）：

1️⃣ **本地 skills 目录**（最优先，按当前 AI 助手目录约定）

```powershell
# turbo
# 查看当前项目已有的 Skills（将 <skills-root> 替换为实际目录，如 .codex/skills）
Get-ChildItem -Path "<skills-root>" -Recurse -Filter "SKILL.md" | ForEach-Object { $_.FullName }
```

2️⃣ **antigravity-awesome-skills**
👉 <https://github.com/sickn33/antigravity-awesome-skills/tree/main>

3️⃣ **Skill Marketplace**
👉 <https://skillsmp.com/zh>

> [!TIP]
> 使用本项目自带的脚本访问网页：
>
> ```powershell
> # 使用配套脚本访问交互式网页（将 <skills-root> 替换为实际目录）
> python <skills-root>/skill-builder/scripts/web_access.py --url <URL>
> ```

**检索判断与整合**：

- 是否存在同名 Skill？
- 是否存在功能相同但命名不同的 Skill？
- 是否可以通过多个 Skill 组合实现？
- **外部能力对标**：对比外部优质 Skill（如 `antigravity-awesome-skills` 和 `Skill Marketplace`）中的功能点。
  - ✅ **必须整合**：如果外部 Skill 包含本地缺失的高价值能力（如数据库优化、安全实践等），必须将其整合进新 Skill 的设计中。
  - ❌ **严禁闭门造车**：禁止在明知有更全面的外部实现时，创建一个功能简陋的本地版本。

### Step 3：复用策略分析（非常重要）

对每个子能力，判断并填写来源映射表：

| 能力   | 来源                      | 复用策略                                |
| ------ | ------------------------- | --------------------------------------- |
| 能力 1 | 已有 skill 名称 或 "新建" | ✅ 直接复用 / 🔁 组合实现 / 🆕 需要新建 |

> [!IMPORTANT]
> 每个能力必须明确来源，不允许凭空创造

### Step 4：判断是否需要拆分

如果用户需求包含多个不相关的能力，应建议拆分成多个独立 Skill：

**拆分判断标准**：

- ❌ 一个 Skill 做了多件不同的事
- ❌ 能力之间没有逻辑关联
- ❌ 无法用一句话描述这个 Skill 的职责

**如需拆分**：

- 告知用户建议拆分的方案
- 分别为每个 Skill 执行本流程

### Step 5：输出 Skill 设计

如果确认需要创建新 Skill，必须输出以下结构：

```markdown
---
slug: <kebab-case-slug>
name: <中文名称>
description: <一句话描述>
category: <workflow|backend|frontend|language|ai|utility>
role: <entrypoint|workflow|specialist>
triggers:
  - <触发词 1>
  - <触发词 2>
inputs:
  - <输入 1>
  - <输入 2>
outputs:
  - <输出 1>
  - <输出 2>
related_skills:
  - <相关 skill slug>
constraints:
  - <约束 1>
  - <约束 2>
---

# Skill: <skill-name>

## 🎯 Purpose

（一句话说明这个 skill 做什么）

## 🧩 Capabilities

- 能力 1
- 能力 2
- 能力 3

## 🔍 Source Mapping

（说明每个能力来自哪个已有 skill 或是否新建）

| 能力 | 来源 |
|------|------|
| 能力 1 | 来源说明 |

## 🧠 Usage

（什么时候用它）

## 📥 Input

（期望输入）

## 📤 Output

（输出内容格式）

## 📚 References

（列出参考的外部链接、技能或文档）

- 参考项 1：<URL 或 技能名称>
- 参考项 2：<URL 或 技能名称>

## ⚠️ Constraints

（使用限制 / 不做什么）

## 🔗 Related Skills

（可配合使用的其他 skill）
```

### Step 6：更新 SKILLS 清单

运行 `pwsh ./scripts/generate-skills-index.ps1`，重新生成仓库根目录的 `SKILLS.md`。

## 📌 设计原则 Checklist

每次创建 Skill 前，必须确认以下原则：

- [ ] ❌ 不重复造轮子 —— 已检索本地和外部技能库
- [ ] ✅ 优先组合已有 skill —— 复用策略分析已完成
- [ ] ✅ 一个 skill 只做一件事 —— 职责单一，可用一句话描述
- [ ] ❌ 不写"万能型 skill" —— 没有包含多个不相关能力
- [ ] ✅ 所有能力可解释来源 —— Source Mapping 已填写

## ⚠️ 禁止事项

- ❌ 跳过检索直接创建新 Skill
- ❌ 创建功能与现有 Skill 重叠的 Skill
- ❌ 创建职责不清晰的"万能 Skill"
- ❌ 忽略本地已有 Skills 只看外部来源

## 📚 References

- [Prompt Engineering Guide](https://www.promptingguide.ai/)
- [Antigravity Awesome Skills Guide](https://github.com/sickn33/antigravity-awesome-skills)

## ⚠️ Constraints

- 创建前必须先检索本地与外部可复用能力。
- 不输出职责混杂、边界模糊的万能型 skill。
- 新 skill 必须同步维护 frontmatter 和索引信息。

## 🔗 Related Skills

- [prompt-design](../core/ai/prompt-design/SKILL.md): 可帮助优化 skill 的提示与输出结构。
- [markdown](../core/markdown/SKILL.md): 可帮助新 skill 文档符合统一文档规范。
- [code-review](../core/code-review/SKILL.md): 可用来审查新增 skill 是否清晰、可维护。
