# Android 测试与质量

状态：{{根据仓库事实改写；只记录已配置、已运行和待补充项}}。

## 测试范围

| 层级 | 适用行为 | 验证方式 |
| :--- | :--- | :--- |
| 纯 Kotlin 单测 | 业务规则、格式化、状态转换、ViewModel | 真实 Gradle test task；可控 test double |
| 数据层测试 | 实际存在的 DAO、序列化、同步和 Repository 行为 | 仅记录已配置的 JVM 或设备测试 |
| UI 测试（Compose 或 Views） | 关键用户任务、语义、控件状态和导航 | 按实际 runtime 和已配置测试工具选择任务与目标环境 |
| 人工设备验收 | 系统返回、IME、字体缩放、主题和 TalkBack | 记录真实设备/API、步骤与观察结果 |
| 截图/性能测试 | 视觉回归或已确认性能目标 | 仅在工具、基准和维护流程存在时记录 |

从可重复的业务行为开始，不以验证某次内部函数调用为目标。优先使用与生产
接口一致的 fake/test repository 替换外部依赖。Hilt 测试能力、Turbine、
Roborazzi、Robolectric 和 Macrobenchmark 只有项目已配置时才列为现有工具。

## 质量门槛

- 协程测试使用已配置的 `kotlinx-coroutines-test`；通过 `runTest` 和共享
  test scheduler 控制时间，避免真实 sleep。替换 Main dispatcher 后须恢复。
  对 `StateFlow` 验证可观察状态；按订阅策略启动收集，不假定每个中间值都会发出。
- 编译受影响模块和变体，运行该变体真实存在的单元与 UI 测试。
- 检查项目实际配置的 Kotlin/Android lint、格式化、依赖分析和资源检查。
- 重要状态包括成功、加载、无数据、失败、重试、重复操作、恢复及进程/配置变化；按功能适用范围选择，不要求每个页面伪造全部状态。
- 对权限、网络、后台作业和持久化，覆盖拒绝、超时、重启或迁移场景中的实际风险。
- 不引入未经授权的 CI、覆盖率阈值、截图存储库、发布门禁或新测试依赖。

## UI 人工检查

对实际支持的页面与设备逐项检查，并在记录中写明未覆盖项：

- 小窗口、常见手机、目标平板/折叠设备与横竖屏；检查长标题、长列表和系统栏 inset。
- 浅色/深色及动态颜色只在应用实际支持时检查；确认动态色不可用时的回退。
- 字体放大、RTL、本地化长文本、TalkBack 名称/角色/状态与最小触摸目标。
- 返回手势和 predictive back、键盘焦点、IME 显示隐藏与表单滚动。
- Expressive 实验 API 仅在实际使用时检查目标库版本、opt-in 范围与升级影响。
- 减少动态效果能力实际可用时，确认业务状态和返回流程仍清楚可用。

## 命令与状态

| 检查 | 真实命令/步骤 | 状态 |
| :--- | :--- | :--- |
| 本地单测 | {{核实任务}} | {{已运行结果或未验证}} |
| UI 测试 | {{核实任务与设备}} | {{已运行结果或未验证}} |
| lint/格式 | {{核实任务}} | {{已运行结果或不适用}} |
| 人工验收 | {{设备、版本、操作与预期}} | {{已执行结果或未验证}} |

不要用 ./gradlew test 代替确认变体；Android 工程常有不同 source set 和任务。若无法运行，写明环境限制及下一条可执行步骤。只将实际测试结果报告为通过。

## 官方与样例参考

- [Testing on Android](https://developer.android.com/training/testing)
- [Compose testing](https://developer.android.com/develop/ui/compose/testing)
- [Kotlin 协程测试](https://developer.android.com/kotlin/coroutines/test)
- [Now in Android testing notes](https://github.com/android/nowinandroid/blob/main/README.md)
- [Android architecture samples](https://github.com/android/architecture-samples)
