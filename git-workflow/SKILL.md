---
name: git-workflow
description: Git workflow guidance for reviewing diffs, staging focused batches, and preparing Chinese Conventional Commit messages. Use when asked to summarize changes, prepare commits, write commit messages, or decide how to split a diff.
---

# Skill: git-workflow

## 触发条件

当用户要求整理 diff、拟定提交说明、拆分提交或执行已授权的提交时使用。

## 工作方式

1. 检查 `git status`、未暂存和已暂存 diff，以及未跟踪文件；确认改动目的，留意意外文件和敏感信息。
2. 按独立目的分批，仅在有助于审查和回滚时拆分；紧密耦合的改动可合并。
3. 遵循仓库已有的提交格式和用户语言偏好。无约定时，使用 `type(scope): 中文摘要`；
   保持 Conventional Commit 的 type 和可选 scope 格式规范。
4. 提交前复核最终暂存 diff，仅包含本批已审阅内容。若用户已在当前任务明确授权提交，且操作范围和内容仍一致，完成复核后直接提交，不重复询问。若用户只要求建议或生成消息，或范围扩展、加入了未审阅内容，则先取得相应授权。
5. 提交后报告提交哈希、摘要及实际执行的检查。提交授权不包含推送、发布或部署授权。

## 输入与输出

输入通常包括暂存和未暂存 diff、用户意图及仓库约定。输出改动总结、推荐消息和必要的拆分方案；
准备发版时可按 [release](../release/SKILL.md) 整理面向用户的变更说明。

## 边界

- 不修改源代码逻辑来配合提交流程。
- 不混入无关文件；不把未审阅的暂存区内容直接提交。
- 提交信息沿用项目约定；中文摘要是无其他约定时的默认格式。

## 参考

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [GitHub Flow Guide](https://docs.github.com/en/get-started/using-git/github-flow)
- [GitFlow Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)
