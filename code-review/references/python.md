# Python Code Review

先从项目配置确认支持的 Python 版本、依赖和工具约定；不要默认要求 Python 3.10+ 或额外的格式化、类型检查工具。根据 diff 检查：

- 输入校验、业务分支、异常传播和公共接口的实际行为。
- 文件、锁、连接等资源的所有权与释放；宽泛异常捕获是否会吞掉可恢复或需要上报的错误。
- async 路径是否执行阻塞操作、取消是否能传递、并发结果是否按调用方预期处理。
- 类型标注与运行时边界是否一致；只在类型错误可能导致真实误用时提出。
- 命名、注释和格式仅在违反仓库约定、遮蔽行为或增加维护风险时提出。

## 边界

- 不将某种推导式、f-string、命名或 docstring 格式写成普遍强制要求。
- 不因项目未采用某项 lint 或类型工具而建议将其加入；如需核实，先按现有配置选择对应命令。
- 只依据项目实际支持版本评价语法和标准库 API。

## 参考

- [The Zen of Python (PEP 20)](https://peps.python.org/pep-0020/)
- [PEP 8](https://peps.python.org/pep-0008/)
- [Google Python Style Guide](https://google.github.io/styleguide/pyguide.html)
- [Ruff](https://docs.astral.sh/ruff/)
