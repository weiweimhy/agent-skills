---
name: typescript-review
description: TypeScript code review guidance for type safety, narrowing, public APIs, runtime validation, async behavior, and project configuration. Use when reviewing TypeScript changes, .ts or .tsx files, or complex types.
---

# TypeScript Code Review

审查类型声明与运行时行为是否相符，并以本次改动可能造成的错误为中心。遵循项目配置，不偏好某一种模块或类型声明写法。

## 触发条件

- “审查这段 TypeScript 代码”
- “这段代码的类型推导是否正确？”
- “帮我检查这个泛型函数”
- “看看这里的类型收窄是否安全”

## 审查重点

先读相关 diff、调用方和 tsconfig/package 配置，再按实际风险检查：

- 外部数据和不可信输入是否在使用前验证；类型声明、断言和运行时校验是否一致。
- 联合类型、空值和泛型边界是否可能漏掉分支或允许非法调用。
- Promise、错误处理、取消和副作用是否符合调用方预期。
- 公共类型、序列化格式和模块边界是否存在兼容性问题。
- 复杂类型是否增加真实维护或编译风险，而非仅仅写法不同。

## 输入与交付

输入可为 TypeScript 文件、diff、tsconfig 及必要的行为背景。
按 [code-review](../code-review/SKILL.md) 的风险排序格式报告可定位问题，说明触发条件、影响、证据和修复方向。
类型模型或重构示例只在修复具体发现时给出；不提供主观 Type Safety Score。

## 边界

- 不将 interface 优先于 type、ESM 优先于项目已用模块系统等偏好当作缺陷。
- 不要求删除所有 any；指出它在具体边界导致的不安全行为即可。对类型断言也按实际数据来源判断。
- 不以类型层面的安全感替代对输入验证和运行时路径的检查。

## 参考

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [TypeScript Release Notes](https://devblogs.microsoft.com/typescript/)
- [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)

## Related Skills

- [code-review](../code-review/SKILL.md)：通用审查流程。
- [api-design](../api-design/SKILL.md)：涉及 API 契约时参考。
- [backend-patterns](../backend-patterns/SKILL.md)：涉及服务端边界时参考。
