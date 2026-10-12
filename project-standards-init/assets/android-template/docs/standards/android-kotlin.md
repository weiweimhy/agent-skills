# Kotlin Android 开发规范

适用范围：{{真实 Kotlin Android 模块与代码路径}}。状态：{{已采用 / 本次选定
尚未实现 / 待确认}}。生成时按源码、Gradle 配置和用户决定改写。

## Kotlin 与依赖

- 按仓库已配置的 Kotlin 版本、语言特性、编译目标和格式规则编写；不要因当前样例版本复制旧插件组合。
- 以 Gradle Wrapper 和 version catalog 管理工具与库版本。升级前核对
  JDK、Gradle、AGP、Kotlin、Compose 插件和处理器兼容性。
- Kotlin 2+ 项目按 Kotlin 版本应用 Compose compiler Gradle plugin。
  Compose BOM 管理 Compose 库，不替代 compiler plugin 的版本管理。
- AGP 9 项目按当前 Android Gradle Plugin 文档核对内置 Kotlin 行为；
  不机械叠加旧版 kotlin-android 或 kapt 设置。
- 仅当仓库使用的库需要代码生成时配置 KSP 等处理器；记录实际支持的处理器与版本组合。

## UI runtime 与状态

若仓库使用 Views/XML，遵循现有 View、Fragment、导航和测试模式。Android/Kotlin
分支不表示选用 Compose 或授权迁移；未采用 Compose 时删除其专属规则。

仅当项目已采用或本次选择 Compose 时，保留以下 Compose 规则：

- Compose 函数以输入参数表达显示内容，以回调表达用户操作；避免在组合函数中直接执行网络、数据库或不可重复副作用。
- 对共享状态采用 state hoisting；可复用组件接收 Modifier 并以无状态形式优先。
- 屏幕级状态归属实际的 ViewModel 或仓库已有状态持有者。对持续状态优先提供不可变 UI state，并由 UI 生命周期感知地收集。
- Compose 中使用 `collectAsStateWithLifecycle()` 收集 Flow 状态；
  业务事实进入 `UiState`，短暂局部交互按需要使用 `remember`。
- 选择稳定 API。需要 Material 3 Expressive 实验 API 时，仅对具体 API 明确 opt-in，并限制封装与升级影响。
- 使用语义标签、角色和状态。描述应本地化；纯装饰图标设
  `contentDescription = null`，避免重复朗读。

## Android 生命周期与异步

- 在 ViewModel 生命周期内启动屏幕状态工作；Activity、Context、View、Resources 不作为 ViewModel 字段保存。
- Flow 的收集采用当前项目使用的生命周期感知 API。普通短暂状态不要为了统一而增加不需要的流或全局单例。
- 根据实际状态恢复与进程重建需求选择 rememberSaveable、SavedStateHandle 或持久化仓库；不要把临时 UI 状态当业务数据。
- 所有权限请求和系统能力应由实际 UI/平台入口触发，并处理拒绝、不可用和返回前台的情况。
- `suspend` 函数须能安全地从主线程调用；执行阻塞工作的一层负责切换调度器。
  需控制执行环境的类注入 dispatcher，便于测试替换，不要求无阻塞的 API 重复切线程。
- 使用结构化并发和有明确所有者的 scope，不以 `GlobalScope` 绕过生命周期。
  更长生命周期的工作明确其所有者；持久后台任务再按需求选择 WorkManager。
- 处理已知错误并更新可恢复状态；捕获通用异常或使用 `runCatching` 时，
  不吞掉 `CancellationException`。取消须继续传播，资源须释放。

## 可访问性与可维护性

- 为控件提供清楚的可访问名称、适当角色与状态；触摸目标按平台建议至少 48dp。
- 验证字体缩放、长文本、RTL、TalkBack、键盘焦点以及 edge-to-edge 和 IME inset 的真实页面行为。
- 图标使用按需加入的 Material Symbols Android vector XML 或仓库已有资源。
  不默认依赖旧 material-icons artifact 或整包扩展图标。
- 复用现有主题与组件。新全局 token 或公共组件应先确认归属和调用边界，避免页面内散落相互冲突的样式值。

## 参考

- [Android 协程最佳实践](https://developer.android.com/kotlin/coroutines/coroutines-best-practices)
- [Compose 状态](https://developer.android.com/develop/ui/compose/state)
