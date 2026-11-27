# Android 项目基座（AGENTS.md 模板）

> 生成目标仓库文件前，按仓库事实替换所有 `{{占位符}}`，删除本提示行、未采用能力与未生成的文档链接。

## 项目定位与版本锚点

- **产品目标**：{{目标用户与核心任务}}
- **包名与分发范围**：{{applicationId / 设备与发行渠道}}
- **技术栈与版本锚点**：{{Kotlin / AGP / Gradle / JDK / minSdk-targetSdk / Compose 或 Views；新选定未安装项标明“计划”}}

## 常用命令与验证分层

> 只保留通过 Gradle Wrapper 或 IDE 核实存在的变体任务；未运行过标明“未实测”。

| 用途 | 命令 | 说明 |
| :--- | :--- | :--- |
| 单测（快检） | `{{./gradlew :app:testDebugUnitTest --tests ...}}` | 日常首选；定向过滤避免全量跑测 |
| 变体构建 | `{{./gradlew assembleDebug}}` | 确认编译与资源打包 |
| 静态检查 / 格式化 | `{{./gradlew lintDebug / spotlessApply}}` | 若未配置则删除本行 |
| 设备 / UI 测试 | `{{./gradlew connectedDebugAndroidTest}}` | 需要真机或模拟器 |

## 加速导航（Where to Look First）

- **核心模块与入口**：{{只列真实存在的模块/入口文件，如 app/、feature/、core/}}
- **标杆样例（Golden Samples）**：{{新增页面/ViewModel/Repository 时优先参照的 2–3 个真实文件路径}}
- **共享主题与组件**：{{真实 Theme / Design System / 共享组件入口}}
- **只读或托管产物**：{{如生成代码目录、CI 托管截图基线、version catalog 等注意事项}}

## 关键不变量与踩坑提示（Gotchas）

- **UI 与状态边界**：维持 UDF，界面发意图、状态持有者产不可变状态；禁止把 `Activity`/`Context`/`View` 存入 `ViewModel`（防内存泄漏与配置重建崩溃）。
- **生命周期与协程**：使用项目已采用的生命周期感知收集 API（如 Compose 的 `collectAsStateWithLifecycle()`）；`suspend` 函数保持主线程安全；捕获异常时不吞 `CancellationException`。
- **工具链与变体兼容**：不要盲跑裸 `./gradlew test`（Android 变体与 source set 差异易误判）；AGP/Kotlin/Compose 编译器插件版本须按官方兼容矩阵配套。
- **既有架构守恒**：既有 Views/XML 项目沿用现有视图与导航，不因使用 Kotlin 擅自迁移 Compose。

## 自主与确认边界

- **Always（直接做）**：按标杆样例实现需求、补齐针对性单测、在授权范围内做可逆细节决策、运行受影响变体的快速验证并如实汇报。
- **Ask First（先确认）**：更换全局主题/导航框架、修改持久化 Schema/迁移、调整公开数据契约、新增第三方依赖或权限、拆分新 Gradle 模块。
- **Never（硬红线）**：提交签名密钥/`local.properties` 敏感配置、伪造未执行的构建或设备验收结论、修改无关模块。

## 按需延伸阅读

<!-- 仅保留本仓库真实存在或本轮已生成的文档，删除其余行 -->

| 场景 | 文档 |
| :--- | :--- |
| Kotlin / Compose / 生命周期细节 | [Kotlin Android 规范](docs/standards/android-kotlin.md) |
| 模块边界与数据流 | [架构](docs/architecture.md) |
| 工具链、配置与排错 | [开发与构建](docs/development.md) |
| 测试层级与人工设备验收 | [测试与质量](docs/testing-and-quality.md) |
| 视觉主题、布局与动效 | [UI 设计](docs/ui-design.md) |
| 页面清单与无障碍交付 | [UI 交付](docs/ui-delivery.md) |
