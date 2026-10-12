# Kotlin Android 项目初始化模板

本参考用于初始化 Kotlin Android 工程规范，或设计可复用文档模板。它提供素材
和技术决策边界，不代表目标仓库已安装、采用或验证其中的技术。项目事实须来自
目标仓库或用户确认。

## 使用方式与输入

先检查目标仓库事实，再按本文档和
[文档契约](document-contract.md#前端分支与文档判定) 选择交付物。
文档契约是交付文件条件的唯一来源；本参考不增加或放宽其规则。

初始化前收集或从仓库确认以下信息：

| 输入 | 需要确认的内容 |
| :--- | :--- |
| 产品目标 | 目标用户、核心任务、产品分发渠道和主要运行设备 |
| 工程身份 | 项目名称、应用标识、实际源码包名与仓库根目录 |
| UI 范围 | 首批页面、信息优先级、品牌或已批准的设计来源、主题要求 |
| 平台约束 | 最低设备/API、目标发行渠道、手机/平板/折叠屏/桌面等范围 |
| 数据与能力 | 是否离线、远程服务、账号、持久化、后台任务、通知及权限 |
| 本地化与无障碍 | 实际支持语言、字体缩放、RTL、TalkBack 和输入设备要求 |
| 当前状态 | 已有 Gradle、Android Gradle Plugin、Kotlin、Compose、导航、测试与 CI 配置 |
| 交付授权 | 本轮允许创建或修改的文档、源码和工具边界 |

缺少品牌或产品输入时，不伪造颜色、字体、页面或视觉参考。可以记录通用平台规则和待决策项；只有用户授权并且产品与页面任务足够明确时，才为产品建立具体视觉基线。

## 默认决策与可选边界

### Kotlin 与 UI runtime

- 先检查仓库 UI runtime。新建 UI 经选择后可采用 Compose 与稳定 Material 3。
  Views/XML 项目保留现有 UI 和导航；Android 分支不代表迁移授权。
- Kotlin 2+ 使用与 Kotlin 版本匹配的 Compose compiler Gradle plugin。
  Compose BOM 管理 Compose 库，不管理 compiler plugin。
- Material 3 Expressive 是可选视觉方向。逐个核对使用 API 的 opt-in，
  不将预览 API 当成基线。

### 架构与导航

- 推荐 UDF；屏幕状态由 ViewModel 等状态持有者维护，Flow/StateFlow 向 UI
  提供状态。有业务数据时经 Repository 隔离来源；业务复杂或复用时再加 use case。
- 新 Compose 项目评估当前稳定 Navigation 3；既有 Navigation 2 可延续。
  不混用或迁移，除非需求明确。

### 构建与模块

- 使用 Gradle Wrapper 和 version catalog。AGP、Gradle、JDK、Kotlin 与插件
  按官方兼容信息配套。AGP 9 已内置 Kotlin；勿机械添加旧 Kotlin Android
  或 KAPT 配置。
- 初始使用单 app 模块并按职责组织源码。只有团队、复用、依赖方向或构建
  效率带来收益时再拆分，避免复制 Now in Android 的完整模块树。

### 条件技术与质量

- 小项目用构造注入和显式组装；依赖图复杂或测试替换成本高时再评估 Hilt。
- Room、DataStore、网络、WorkManager、通知、分析、基线配置和 KSP 均按需求
  选择；核对处理器与 Kotlin/AGP 的兼容性。
- 覆盖业务逻辑单测和关键 UI 交互。截图、设备矩阵、性能基准依风险选择；
  CI 只记录仓库实际存在的流程。

截至 2026-10-07，Navigation 3 发布页显示 1.2.0 稳定版；Material 3
发布页显示 1.4.0 稳定、1.5.0-beta01 预览。这是 2026-10-12 查询时的快照，
不是长期版本锁定。初始化时重查兼容矩阵和 release 页面；不要拼接不同时间
的样例版本，形成未经验证的组合。

Material 3 Expressive 是视觉方向。按符号和所选依赖版本判断 API 成熟度。
稳定组件仍可表达鲜明品牌层级；实验 API 要明确 opt-in、封装范围和升级检查。

## 可生成的资源

下列路径是模板资源，不是当前项目事实。按
[文档契约](document-contract.md) 判断目标项目是否需要每份文件，并删除
无关章节、占位符和条件说明。

既有 Kotlin Views/XML 工程默认只保留适用的 Kotlin、生命周期和工程规则。
Compose、Compose 导航及 Compose UI 资产仅在仓库已采用或用户明确选定后生成。
架构文档描述现有 View/导航边界，不使用 Compose 图；Android 项目身份不构成
迁移授权。

| 模板资源 | 生成文件 |
| :--- | :--- |
| [AGENTS][agents-template] | 根目录 `AGENTS.md` |
| [Kotlin 规范][kotlin-template] | `docs/standards/android-kotlin.md` |
| [架构说明][architecture-template] | `docs/architecture.md` |
| [开发说明][development-template] | `docs/development.md` |
| [测试与质量][quality-template] | `docs/testing-and-quality.md` |
| [UI 设计][design-template] | `docs/ui-design.md` |
| [UI 交付][delivery-template] | `docs/ui-delivery.md` |

生成位置依次为根目录 `AGENTS.md`、`docs/standards/android-kotlin.md`、
`docs/architecture.md`、`docs/development.md`、
`docs/testing-and-quality.md`、`docs/ui-design.md` 和
`docs/ui-delivery.md`。AGENTS 记录协作边界和文档入口；其它文件记录已确认
的 Kotlin/UI 约定、架构、工具链、质量要求、设计基线或页面验收。

`AGENTS.md` 只链接最终生成的文档，不为条件文档预留悬空链接。若仓库有
真实网络接口或本地持久化，按文档契约判断是否需 `docs/api-and-data.md`；
本资源包不提供该模板。

## 初始化步骤

1. 检查 `AGENTS.md`、README、源码、Wrapper、version catalog、模块、Manifest、
   变体、测试和 CI。区分已安装、已选未装、待决策与已验证。
2. 阅读文档契约与前端设计契约。由文档契约决定交付物；有 UI 时按输入选择
   建立基线、沿用提炼或仅审计。
3. 按产品和渠道选择 minSdk、compileSdk、targetSdk、JDK、Android Studio、
   AGP、Gradle、Kotlin 和依赖。用官方兼容信息核验，不复制整组旧示例版本。
4. 从 assets 读取适用模板并按事实重写。删除未采用工具、功能、目录、命令和
   状态；提案标为“本次决定/尚未实现”，未知标为“待确认”。
5. 更新 `AGENTS.md`，只保留真实目录和真实命令，并只链接存在或本轮确实生成的文档。不要添加应用代码、依赖、构建脚本或 CI。
6. 检查改动 diff 并对模板运行可用的 Markdown 检查。仅在核实任务且实际运行后
   才报告目标命令通过；新工程不写未经验证的构建、安装或设备测试结论。
7. 汇总生成文件、关键技术决策、实际运行的命令及结果、未完成检查、风险和按文档契约整理的初始化后修复建议。

## 模板改写边界

- 资产只能作为起稿素材，不能复制成目标项目事实；核验并替换 `{{占位符}}`，删除占位符和未适用章节。
- 技术建议不能变成依赖、代码、CI、发布目标或兼容性事实。没有明确授权时，不添加实现。
- 不从目录名、工具存在或样例仓库推断已采用库、功能、品牌、设备、主题、导航、图标或测试覆盖。
- UI 设计基线是可逆提案，不是用户已批准的品牌方案；输入不充分时按契约只审计并记录缺口。
- 命令示例不是仓库命令。先从真实 Wrapper、Gradle task、运行配置或现有文档确认。
- 验证状态只能反映实际执行过的人工步骤、设备、浏览器或命令。

## 来源与查询日期

查询日期：2026-10-12。Android 文档用于当前推荐和稳定性；官方 GitHub
用于核对样例、依赖目录和样例限制。GitHub 的 `main`、`master`、
`androidx-main` 是滚动来源，链接内容可能变化。

- [Android app architecture recommendations][android-architecture]
  Compose、UDF、ViewModel、Flow 与生命周期收集的总体建议。
- [Compose architecture][compose-architecture]
  UI state、事件和状态提升建议。
- [Material 3 for Compose][material3] 与 [Material 3 release notes][m3-releases]
  组件和 Expressive API 用法与版本状态。
- [Navigation 3 release notes][nav3-releases]
  截至 2026-10-07 显示稳定版 1.2.0。
- [Compose image and icon guidance][icons]
  2026-10-01 不再推荐旧 material-icons artifact；建议按需下载 Material
  Symbols Android XML。
- [Compose accessibility defaults][accessibility]
  最小触摸目标、本地化描述和装饰图标语义。
- [Predictive back setup][predictive-back]
  系统返回与动画；根 Activity 不应拦截返回破坏系统行为。
- [Now in Android README][nia-readme]、[架构指南][nia-architecture]、
  [模块化指南][nia-modules] 与 [version catalog][nia-catalog]
  可参考 UDF、模块边界、测试替身和依赖管理。查询时 catalog 的
  Navigation 3 为 1.0.0，AGENTS.md 仍写 Navigation 2；文档可能滞后，
  应以代码和官方发布页交叉确认。
- [Android architecture samples][architecture-samples] 与
  [Jetpack Compose samples][compose-samples]
  可借鉴界面、状态和测试；architecture-samples README 声明其用于架构讨论，
  不是模板。
- [Navigation 3 recipes migration guide][nav3-recipes]
  NavKey、back stack、entry provider 与 NavDisplay 示例。
- AndroidX 的 [Expressive opt-in 声明][expressive-optin] 与
  [Button implementation][expressive-button]
  展示实验标记和 API 用法。androidx-main 是滚动源码，不替代 release notes。
- [Google KSP][ksp]
  仅在所选库需要处理器时参考。
- [Android 协程最佳实践][coroutines] 与 [协程测试][coroutine-tests]
  调度器注入、主线程安全、取消传播、结构化并发与虚拟时间测试。
- [Compose BOM][compose-bom] 与 [AGP 内置 Kotlin][builtin-kotlin]
  编译插件与库版本边界、AGP 9 配置要求。
- [Compose 自适应布局][adaptive]
  按窗口尺寸调整导航与内容，覆盖非触摸输入和目标设备。

[android-architecture]: https://developer.android.com/topic/architecture/recommendations
[compose-architecture]: https://developer.android.com/develop/ui/compose/architecture
[material3]: https://developer.android.com/develop/ui/compose/designsystems/material3
[m3-releases]: https://developer.android.com/jetpack/androidx/releases/compose-material3
[nav3-releases]: https://developer.android.com/jetpack/androidx/releases/navigation3
[icons]: https://developer.android.com/develop/ui/compose/graphics/images/material
[accessibility]: https://developer.android.com/develop/ui/compose/accessibility/api-defaults
[predictive-back]: https://developer.android.com/develop/ui/compose/system/predictive-back-setup
[nia-readme]: https://github.com/android/nowinandroid/blob/main/README.md
[nia-architecture]: https://github.com/android/nowinandroid/blob/main/docs/ArchitectureLearningJourney.md
[nia-modules]: https://github.com/android/nowinandroid/blob/main/docs/ModularizationLearningJourney.md
[nia-catalog]: https://github.com/android/nowinandroid/blob/main/gradle/libs.versions.toml
[architecture-samples]: https://github.com/android/architecture-samples
[compose-samples]: https://github.com/android/compose-samples
[nav3-recipes]: https://github.com/android/nav3-recipes/blob/main/docs/migration-guide.md
[expressive-optin]: https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/ExperimentalMaterial3ExpressiveApi.kt
[expressive-button]: https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/Button.kt
[ksp]: https://github.com/google/ksp
[coroutines]: https://developer.android.com/kotlin/coroutines/coroutines-best-practices
[coroutine-tests]: https://developer.android.com/kotlin/coroutines/test
[compose-bom]: https://developer.android.com/develop/ui/compose/bom
[builtin-kotlin]: https://developer.android.com/build/migrate-to-built-in-kotlin
[adaptive]: https://developer.android.com/develop/ui/compose/layouts/adaptive/get-started-with-adaptive-apps
[agents-template]: ../assets/android-template/AGENTS.md
[kotlin-template]: ../assets/android-template/docs/standards/android-kotlin.md
[architecture-template]: ../assets/android-template/docs/architecture.md
[development-template]: ../assets/android-template/docs/development.md
[quality-template]: ../assets/android-template/docs/testing-and-quality.md
[design-template]: ../assets/android-template/docs/ui-design.md
[delivery-template]: ../assets/android-template/docs/ui-delivery.md
