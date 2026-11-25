---
name: lua
description: Implement, refactor, or review Lua modules and game-client features, including table semantics, coroutine lifetimes, errors, and host-language bridges. Use for Lua code paths or explicit invocation; trace the project's real loader and existing asset or host-object boundaries when relevant.
---

# Lua 工程

用于 Lua 功能开发、重构、审查和性能排查。开始前确认 Lua 版本、运行宿主、模块加载方式及可用的检查工具；从项目实际启动链、模块注册、事件绑定或宿主调用找到功能入口，不假设不同项目使用相同的标准库或桥接层。

## 工作方式

- 优先使用局部变量和显式模块导出，避免无意创建全局变量。模块初始化应可预测，不依赖加载顺序产生副作用。
- 明确 table 是数组、映射还是对象；不要依赖 `pairs` 遍历顺序，也不要在遍历中随意增删同一张 table。需要稳定顺序时使用明确数组或排序。
- `nil` 会移除 table 键。设计配置、序列化和可选字段时区分“缺失”“空值”和默认值，避免悄悄修改共享配置。
- 协程应有明确启动者、取消条件和错误传播路径。热重载、场景卸载或对象销毁后，不得继续驱动已失效的协程。
- 跨 Lua 与宿主语言边界时集中处理类型转换、对象生命周期和异常；确认绑定对象仍有效。功能若由现有配置、场景/Prefab 资源或宿主对象驱动，核对变更后的字段、注册名和调用关系仍兼容。
- 优化前先定位热点；高频路径关注临时 table、字符串拼接、元方法和跨语言调用次数。除非测量证明需要优化，否则保持实现清楚。
- 沿用项目现有测试或最小复现验证模块加载、错误输入、协程取消和关键数据结构，并检查真实入口与相关资产的衔接。

## 交付

说明 Lua 版本和宿主假设、实际入口、模块 API、协程/状态所有权、涉及的配置或资产边界及验证结果。xLua、ToLua、SLua、
热更新框架和游戏事件系统以项目 `.agents/skills/` 或本地约定为准；不将它们的路径、生成代码或绑定名写成通用规则。
