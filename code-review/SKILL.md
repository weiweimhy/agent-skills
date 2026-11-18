---
name: code-review
description: Cross-language code review workflow focused on correctness, maintainability, security, performance, tests, and actionable findings. Use when asked to review code, inspect diffs, organize PR feedback, or assess implementation risk.
---

# 代码审查

从需求、diff 和调用方确认预期行为，追踪本次改动可能影响的输入、失败路径、并发状态和兼容性。用相关测试或可定位的代码证据核实发现。

在同一次审查中按问题读取专项规则。例如，Go 的 goroutine 退出、错误传播或资源释放可参考 [Go 审查](../go-review/SKILL.md)，Python 的异步取消或上下文管理可参考 [Python 审查](../python-review/SKILL.md)。简单的文案和机械性改动只检查实际影响。

交付一份按影响排序的发现清单。每项给出文件位置、触发条件、实际后果和建议修正；同一根因合并报告。区分已证实的问题与需要确认的假设。未发现可操作问题时直接说明，并注明与此次变更有关的验证缺口。
