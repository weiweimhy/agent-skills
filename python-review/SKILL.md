---
name: python-review
description: Python code review guidance for correctness, typing, async behavior, resource handling, exceptions, and project conventions. Use when reviewing Python changes, .py files, or Python-specific risks.
---

# Python Code Review

审查 Python 改动的行为和风险。PEP、格式化及惯用法是项目约定的参考，不是独立的缺陷标准。

## 触发条件

- “审查这段 Python 代码”
- “这段代码符合项目约定吗？”
- “帮我重构这段 Python 逻辑”
- “检查这段异步代码是否会阻塞”

## 审查重点

先从项目配置确认支持的 Python 版本、依赖和工具约定；不要默认要求 Python 3.10+ 或额外的格式化、类型检查工具。根据 diff 检查：

- 输入校验、业务分支、异常传播和公共接口的实际行为。
- 文件、锁、连接等资源的所有权与释放；宽泛异常捕获是否会吞掉可恢复或需要上报的错误。
- async 路径是否执行阻塞操作、取消是否能传递、并发结果是否按调用方预期处理。
- 类型标注与运行时边界是否一致；只在类型错误可能导致真实误用时提出。
- 命名、注释和格式仅在违反仓库约定、遮蔽行为或增加维护风险时提出。

## 输入与交付

输入可为 Python 文件、diff、项目配置及必要的行为背景。
将可定位的发现按 [code-review](../code-review/SKILL.md) 的风险报告格式交付。重构示例、
Ruff 或类型检查建议仅在能解决已指出的问题且符合项目工具链时提供；不输出主观 Pythonic 评分或纯格式意见。

## 边界

- 不将某种推导式、f-string、命名或 docstring 格式写成普遍强制要求。
- 不因项目未采用某项 lint 或类型工具而建议将其加入；如需核实，先按现有配置选择对应命令。
- 只依据项目实际支持版本评价语法和标准库 API。

## 参考

- [The Zen of Python (PEP 20)](https://peps.python.org/pep-0020/)
- [PEP 8](https://peps.python.org/pep-0008/)
- [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
- [Ruff](https://docs.astral.sh/ruff/)

## Related Skills

- [code-review](../code-review/SKILL.md)：通用审查流程。
