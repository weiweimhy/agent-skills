---
name: git-workflow
description: Git workflow guidance for reviewing diffs, staging focused batches, and preparing Chinese Conventional Commit messages. Use when asked to summarize changes, prepare commits, write commit messages, or decide how to split a diff.
---

# Skill: git-workflow

## 🎯 触发条件

当以下情况发生时启用：

- "开始提交流程"
- "帮我总结一下这些改动"
- "分析一下我的 diff 并生成提交信息"
- "这个大改动该怎么拆分提交？"

👉 自动启用本 Skill

## 🎯 Purpose

提供从代码变更分析到生成符合 Conventional Commit 规范的提交信息的全流程引导。

## 🧩 Capabilities

- **总结变更**：分析代码 diff 并总结本次改动内容。
- **提交前审查**：在暂存和提交前分别检查工作区与暂存区差异，确认改动完整、相关且不含意外文件。
- **判断类型**：识别变更类型（feat / fix / refactor / docs / chore 等）。
- **生成消息**：生成符合规范的中文 Commit Message；提交类型和范围保持 Conventional Commit 格式。
- **拆分建议**：按独立目的和可审查性尽可能拆分为原子提交，并给出每批的文件或改动归属。

## 🔍 能力溯源 (Source Mapping)

| 能力 | 来源 | 说明 |
| :--- | :--- | :--- |
| 变更总结 | `codex-review` | 用于深入分析代码语义并生成 CHANGELOG 风格的总结 |
| 类型判断 | `conventional-commits` | 遵循约定式提交类型规范 |
| 消息生成 | `git-workflow` | 根据 diff、scope 和用户意图生成提交信息 |
| 流程自动化 | `git-pushing` | 用于暂存、提交及推送的原子操作执行 |
| 任务安排 | `github-workflow-automation` | 用于 PR 关联及整体流程编排 |
| 拆分提示 | **新建** | 检查 diff 行数及文件分布，若过大则提示拆分 |

## 📚 参考资料 (References)

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [GitHub Flow Guide](https://docs.github.com/en/get-started/using-git/github-flow)
- [GitFlow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)

## 🧠 Usage

- 在准备提交本地变更前。
- 当开发者面对大量杂乱改动不知道如何写提交信息时。
- 在创建 Pull Request 前整理提交历史时。

## 📥 Input

- **代码变更 (diff)**：当前暂存或未暂存的文件差异。
- **意图描述**：开发者对本次改动的简短口头说明。

## 📤 Output

- **改动总结**：清晰的变更列表。
- **推荐 Message**：符合规范的提交信息建议。
- **拆分说明**：如果建议拆分，给出拆分方案。
- **Release Notes**：在发版环节，基于 Commit History 生成分类清晰的变更日志。

## 🧭 提交流程

1. **先审查再暂存**：检查 `git status`、未暂存 diff 和已暂存 diff；识别无关、意外或敏感文件，并确认每项改动的目的。
2. **尽可能分批**：按单一目的、可独立审查和可回滚的原则划分提交；使用指定文件或分块暂存。不要为了拆分而拆分紧密耦合、无法独立工作的改动。
3. **使用中文日志**：提交标题使用 `type(scope): 中文摘要`。仅 Conventional Commit 的 `type` 和可选 `scope` 保持规范形式；摘要、正文和脚注均使用中文，且准确说明当前这一批改动。
4. **提交前复核**：对每一批再次审查暂存 diff，确认其只包含对应目的的改动，再请求用户确认并提交。

## ⚠️ Constraints

- 提交前必须审查改动；未审查的工作区或暂存区差异不能直接提交。
- 除提交类型和范围外，Commit Message 使用中文。
- 有可独立审查的改动时，尽可能拆分为多次原子提交；不混入无关文件。
- 不在未经用户确认的情况下直接执行 `git commit`。
- 不修改源代码逻辑。

## 🔗 Related Skills

- [release](../release/SKILL.md)
- [codex-review](https://github.com/sickn33/antigravity-awesome-skills/tree/main/skills/codex-review)
