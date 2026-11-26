---
name: release
description: Release workflow guidance for project version conventions, release notes, tags, artifacts, consumer verification, and rollback. Use when preparing or validating a release, package publish, tag, or release checklist.
---

# 发布版本 Skill

按仓库和发布生态已有的版本、标签、构建及分发约定准备发布。语义化版本只在项目采用该约定或其消费者依赖该约定时使用。

## 触发条件

- “准备发版”
- “生成 Release Notes”
- “帮我打标签发布”
- “检查这个版本号怎么升”

## 发布流程

1. **确认发布目标。** 检查当前分支与目标提交、近期发布标签、远端、版本字段、CI 配置、已有 Changelog 和目标分发渠道。按真实项目确定上一个可比发布点和标签格式；没有明确约定时说明假设。
2. **建议版本并整理说明。** 依据项目规则及相对上一版的兼容性、用户可见变化确定版本。Release Notes 从对应标签到目标提交的实际差异生成，沿用项目格式，聚焦消费者关心的变化，不机械套用提交类型。
3. **核实发布前状态。** 从仓库脚本、CI 或项目文档确认适用的构建、测试和质量门禁，不编造命令或套用占位符。审阅打标签提交和待发布内容；存在未理解的改动时先厘清。
4. **执行已授权的发布动作。** 使用项目配置的远端、版本字段、标签格式和发布渠道。确认标签指向预期提交。用户对一个发布步骤的授权不自动扩展到其他远程或破坏性操作。
5. **验证消费者实际可用。** 除检查远端标签外，按生态验证新版本能否被目标消费者发现和获取：例如包索引能解析目标版本、制品下载及校验通过、镜像可拉取，或项目安装流程可引用该版本。发布 Node.js 包或 CLI 时，读取 [Node.js 包与 CLI 兼容性检查](references/npm-package.md)，在临时消费目录验证实际打包制品。选择与项目真实消费方式匹配的检查并记录结果；索引传播延迟时明确标记为待验证。
6. **说明回退方式。** 根据项目分发渠道和已发生的消费情况描述修复或回滚影响。不要把删除已发布标签或制品当作通用回滚步骤。

## 交付

给出版本建议及依据、面向用户的发布说明、实际使用的发布前检查、标签/制品/消费者验证结果，以及未验证项和回退影响。没有执行远程发布时，明确标为计划或清单。

## 参考

- [Semantic Versioning 2.0.0](https://semver.org/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)

## Related Skills

- [git-workflow](../git-workflow/SKILL.md)：整理待发布变更与提交历史。
