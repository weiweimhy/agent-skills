---
name: code-review
description: Cross-language code review workflow focused on correctness, maintainability, security, performance, tests, and actionable findings. Use when asked to review code, inspect diffs, organize PR feedback, or assess implementation risk, including Go concurrency, Python async behavior, and TypeScript runtime type boundaries.
---

# 代码审查

围绕用户目标和本次变更，找出有证据支持、会造成实际影响且可采取行动的问题。审查深度随风险调整；不要把风格偏好或无关重构混入发现。

## 工作方式

1. 确认预期行为和审查范围；读取 diff、相关调用方、配置、数据/API 契约及项目约定。
2. 沿着高风险路径检查改动：权限与信任边界、输入、失败和恢复、并发状态、资源、兼容性、持久化和部署影响。只检查本次变更实际涉及的维度。
3. 用代码路径、现有测试或适用的项目命令核实关键发现。无法验证时说明证据缺口，不把假设写成已证实问题。
4. 先报告影响大且容易触发的问题，合并同一根因，避免重复项。

按变更涉及的风险读取专项参考：

- [Go](references/go.md)：goroutine 退出、channel 阻塞、资源释放和错误传播。
- [Python](references/python.md)：事件循环阻塞、取消传递、异常处理和资源所有权。
- [TypeScript](references/typescript.md)：外部输入与运行时校验、类型收窄，以及公共类型兼容性。

## 输出

按风险从高到低列出可操作发现。每项包含：

- 文件位置；
- 触发条件；
- 实际后果及支持结论的证据；
- 可执行的修复方向。

严重度标签遵循仓库或用户约定；没有约定时，仅在有助于排序时标注高、中、低。说明运行过的检查和结果，以及未覆盖的重要风险。若没有可操作发现，直接说明审查范围和验证缺口。

## 边界

- 只把本次变更引入或扩大、且有实际后果的问题列为发现；仅在与改动交互时扩展到邻近代码。
- 不报告纯主观偏好、无影响的重构建议、自动格式化问题或未核实的猜测。
- 不把计划执行的测试、工具或检查描述成已运行。
