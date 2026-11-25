---
name: go-review
description: Go code review guidance for idiomatic Go, concurrency safety, error handling, resource ownership, and performance risks. Use when reviewing Go changes, goroutines, APIs, or Go-specific defects.
---

# Go Code Review

审查 Go 变更时，以可复现的行为风险为主；语言惯例仅在影响正确性、维护或项目约定时提出。

## 触发条件

- “审查这段 Go 代码”
- “这段代码够不够 Idiomatic Go？”
- “帮我看看这个并发处理有没有死锁风险”
- “优化这个 Go 函数的性能”

## 审查重点

先看此次 diff、调用方、Go 版本及项目约定，再按改动涉及的风险检查：

- 错误传播、错误包装和调用方是否能区分失败；检查忽略错误或 panic 是否会造成实际故障。
- goroutine 的所有权、退出和取消路径；共享状态是否同步；channel 是否可能阻塞或造成泄漏。
- 文件、连接、锁等资源的释放，以及 API、数据格式和兼容性。
- 只有在有证据表明会影响关键路径、延迟或资源上限时，才提出性能问题。

## 输入与交付

输入可为 Go 文件、diff 和必要的行为背景。将发现放入 [code-review](../code-review/SKILL.md) 的风险排序报告；
每项指出位置、触发条件、后果、证据和可行修复。只有示例能说明某项修复时，才补充更地道的 Go 写法。没有可操作发现时，说明检查范围和相关验证缺口。

## 边界

- 不把个人风格或可由 gofmt、goimports 自动修正的问题列为缺陷。
- 不强制引入第三方库；遵循仓库已采用的依赖和标准库能力。
- 不要求每个 goroutine 都使用同一种取消机制；按实际生命周期和所有权判断。

## 参考

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)

## Related Skills

- [code-review](../code-review/SKILL.md)：通用审查流程。
- [api-design](../api-design/SKILL.md)：涉及 API 契约时参考。
- [backend-patterns](../backend-patterns/SKILL.md)：涉及后端边界或服务结构时参考。
