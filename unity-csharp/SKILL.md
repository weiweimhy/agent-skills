---
name: unity-csharp
description: Implement, refactor, or review Unity C# runtime and editor code, gameplay, UI, tools, asset loading, lifecycle behavior, and performance. Use for Unity-specific code paths or explicit invocation, especially when changes touch serialized fields or existing scene and prefab assets.
---

# Unity C# 工程

用于 Unity 运行时代码、编辑器工具、UI、资源加载与性能问题。先确认 Unity 版本、目标平台、渲染管线、asmdef 和已用包，并从实际场景、
Prefab、Inspector 引用、UnityEvent 或代码调用找到功能入口。

## 工作方式

- 区分运行时代码、编辑器代码和构建时代码。编辑器 API 不进入 Player 程序集；跨程序集依赖遵循现有 asmdef 边界。
- 明确 `Awake`、`OnEnable`、`Start`、`OnDisable`、`OnDestroy` 的职责和重复调用行为。事件订阅、协程、取消令牌和临时对象应在对应生命周期释放。
- 修改序列化字段、Prefab 或 ScriptableObject 时先检查已有资产的引用和数据兼容性。避免随意重命名字段、改变枚举值或把场景状态迁入静态状态；必须迁移时提供可回退方案。
- 沿入口追踪到受影响资产，检查 Inspector 引用、UnityEvent、Prefab 变体及脚本执行顺序。代码可编译不代表旧场景和资产仍有效；按项目可用方式验证资产与运行行为，并说明未能验证的内容。
- 对 `Update`、`LateUpdate`、UI 列表和战斗循环等热点，先定位调用频率和 Profiler 证据，再处理分配、查找、装箱或多余渲染更新。
- Unity API 默认只能在主线程访问。异步操作应在场景、对象或用户动作结束时取消，并在主线程恢复后再访问场景对象。
- 优先用明确数据流和组合组件表达功能；全局单例、字符串查找和隐式执行顺序仅在项目已有约定时沿用。

## 交付

说明真实功能入口、受影响场景/Prefab/ScriptableObject、序列化兼容性、生命周期所有权和实际验证方式。Addressables、
ECS/DOTS、热更新、网络框架或 Lua 桥接细节遵从项目自身的 `AGENTS.md` 与资产规范，不把项目路径或框架约定写成通用规则。
