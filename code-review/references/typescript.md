# TypeScript Code Review

先读相关 diff、调用方和 tsconfig/package 配置，再按实际风险检查：

- 外部数据和不可信输入是否在使用前验证；类型声明、断言和运行时校验是否一致。
- 联合类型、空值和泛型边界是否可能漏掉分支或允许非法调用。
- Promise、错误处理、取消和副作用是否符合调用方预期。
- 公共类型、序列化格式和模块边界是否存在兼容性问题。
- 复杂类型是否增加真实维护或编译风险，而非仅仅写法不同。

## 边界

- 不将 interface 优先于 type、ESM 优先于项目已用模块系统等偏好当作缺陷。
- 不要求删除所有 any；指出它在具体边界导致的不安全行为即可。对类型断言也按实际数据来源判断。
- 不以类型层面的安全感替代对输入验证和运行时路径的检查。

## 参考

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [TypeScript Release Notes](https://devblogs.microsoft.com/typescript/)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
