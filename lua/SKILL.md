---
name: lua
description: Build, refactor, or review Lua application and game-client code with explicit module boundaries, table semantics, coroutine ownership, error handling, and safe host-language interoperation. Use for .lua files or Lua-driven features.
---

# Lua Engineering

## 使用范围

用于 Lua 功能开发、重构、审查和性能排查。开始前确认 Lua 版本、运行宿主、模块加载方式、是否存在静态检查或测试工具；不要假设所有项目使用相同的标准库或 Lua/C# 桥接层。

## 工作方式

- 使用局部变量和显式模块导出，避免无意创建全局变量。模块初始化应可预测，并避免依赖加载顺序产生副作用。
- 明确 table 是数组、映射还是对象；不要依赖 `pairs` 的遍历顺序，也不要在遍历时随意增删同一张 table。需要稳定顺序时使用明确数组或排序。
- `nil` 会移除 table 键。设计配置、序列化和可选字段时区分“缺失”“空值”和默认值，避免把默认值悄悄写回共享配置。
- 协程必须有启动者、取消条件和错误传播路径；脚本热重载、场景卸载或对象销毁后不得继续驱动失效协程。
- 跨 Lua 与宿主语言边界时，集中处理类型转换、对象生命周期和异常。跨边界调用必须检查对象是否仍有效，且不要把宿主框架的路径、生成代码或绑定名称写成通用约定。
- 优化前先定位热点。高频路径中关注临时 table、字符串拼接、元方法和跨语言调用次数；保留清晰实现，除非性能测量证明需要优化。
- 用项目现有的测试或最小可复现脚本验证模块行为，覆盖模块加载、错误输入、协程取消和关键数据结构。

## 交付与边界

交付时说明运行时假设、模块 API、状态所有权和验证方法。xLua、ToLua、SLua、热更新框架与游戏事件系统的细节应由对应项目的 `.agents/skills/` 约束，而不是写入此通用技能。
