---
name: unity-csharp
description: Build, refactor, or review Unity C# runtime and editor code with lifecycle safety, serialization compatibility, performance evidence, and testable scene boundaries. Use for Unity gameplay, UI, tools, or performance work.
---

# Unity C# Engineering

## 使用范围

用于编写、重构或审查 Unity C# 的运行时代码、编辑器工具、UI、资源加载和性能问题。先确认 Unity 版本、目标平台、渲染管线、程序集定义和已使用的包；这些事实优先于通用建议。

## 工作方式

- 区分运行时代码、编辑器代码和构建时代码。编辑器 API 不进入 player assembly；跨程序集依赖应保持单向并与现有 asmdef 边界一致。
- 把 `Awake`、`OnEnable`、`Start`、`OnDisable`、`OnDestroy` 的职责和可重复调用性说清楚。订阅事件、协程、取消令牌和临时对象应在匹配的生命周期中释放。
- 修改已序列化字段、Prefab 或 ScriptableObject 数据时优先保持兼容性。不得随意重命名字段、改变枚举值或把场景数据迁入静态状态；如必须迁移，给出可回退的数据迁移方案。
- 对 `Update`、`LateUpdate`、UI 列表和战斗循环等热点，先识别调用频率和 profiler 证据，再处理分配、查找、装箱、闭包或不必要的渲染更新。不要为猜测的性能问题牺牲可读性。
- Unity API 默认只能在主线程访问。异步任务完成后恢复到主线程再触碰场景对象，并让异步操作随场景、对象或用户动作取消。
- 优先用明确的数据流和组合组件表达功能；全局单例、字符串查找和隐式执行顺序只有在项目已有约定时才沿用。
- 使用 Unity Test Framework 或项目现有测试方式验证核心行为。测试应避免依赖机器帧率、场景残留状态、执行顺序或真实网络。

## 交付与边界

说明受影响的场景/Prefab、序列化兼容性、生命周期所有权和验证方法。涉及 Addressables、ECS、DOTS、热更新、网络框架或具体 Lua 桥接时，遵从项目内 `AGENTS.md` 或项目技能；不要将某个项目的资源路径和框架约定当作全局规则。
