# Go Code Review

先看此次 diff、调用方、Go 版本及项目约定，再按改动涉及的风险检查：

- 错误传播、错误包装和调用方是否能区分失败；检查忽略错误或 panic 是否会造成实际故障。
- goroutine 的所有权、退出和取消路径；共享状态是否同步；channel 是否可能阻塞或造成泄漏。
- 文件、连接、锁等资源的释放，以及 API、数据格式和兼容性。
- 只有在有证据表明会影响关键路径、延迟或资源上限时，才提出性能问题。

## 边界

- 不把个人风格或可由 gofmt、goimports 自动修正的问题列为缺陷。
- 不强制引入第三方库；遵循仓库已采用的依赖和标准库能力。
- 不要求每个 goroutine 都使用同一种取消机制；按实际生命周期和所有权判断。

## 参考

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
