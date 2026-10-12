# Android 开发与构建

状态：{{根据目标仓库事实改写；未知内容保留为待补充}}。本模板不表示依赖已安装或命令已运行。

## 工具链

| 项目 | 目标仓库值 | 依据 |
| :--- | :--- | :--- |
| Android Studio | {{版本或未确认}} | {{项目配置/CI/Android 官方兼容要求}} |
| JDK | {{版本或未确认}} | {{Gradle/AGP要求}} |
| Gradle Wrapper | {{wrapper版本或未确认}} | {{gradle-wrapper.properties}} |
| Android Gradle Plugin | {{版本或未确认}} | {{插件目录}} |
| Kotlin / Compose 编译插件 | {{版本或未确认}} | {{version catalog / plugins}} |
| compileSdk / targetSdk / minSdk | {{配置值或未确认}} | {{应用变体配置与产品需求}} |

选择时核对 Android 官方工具兼容矩阵。AGP、Gradle、JDK、Kotlin、SDK 与
Compose 编译插件需组成可构建的组合。发行渠道决定 targetSdk；产品设备支持
和依赖决定 minSdk。版本采用情况以配置为证据；构建兼容性须实际验证后才标通过。

## 首次运行

1. 安装仓库要求的 Android Studio、JDK 和 Android SDK。
2. 打开含 Gradle Wrapper 的仓库根目录，完成 Gradle Sync。
3. 按真实项目选择 app 模块、变体和设备；若需要本地服务或配置，按仓库实际说明准备。
4. 按下表中已核实存在的命令构建或启动；未运行的命令标为“未验证”。

## 仓库命令

只保留通过 Gradle tasks --all 或 IDE 配置核实存在的命令。若 Wrapper 存在，
可先用它列出任务。未运行的已知命令标为“未验证”；只有实际运行后才报告
通过。下列是待填字段，不是现成命令：

| 用途 | 实际命令 | 运行结果与环境 |
| :--- | :--- | :--- |
| 列出任务 | {{确认后的 Wrapper 命令}} | {{实际输出或待运行}} |
| 构建 | {{真实模块与变体的构建任务}} | {{实际输出或未验证}} |
| 启动/安装 | {{真实 Run 配置或任务}} | {{设备与结果或未验证}} |
| 格式化 | {{仓库已配置任务}} | {{实际结果或不适用}} |
| 静态检查 | {{仓库已配置任务}} | {{实际结果或不适用}} |

开发命令必须匹配真实模块与变体。不要照抄其他样例的 demoDebug、testDemoDebug 或截图任务名。

## 配置与排错

- 不将签名凭据、访问令牌或用户数据写入版本控制。按实际项目确认 local.properties、本地环境配置和 secret manager 的边界。
- Gradle Sync 失败时先检查 JDK、Wrapper、AGP/Kotlin/插件兼容及 SDK 安装，再检查网络仓库可用性。
- 依赖升级后核对实际采用的 Compose BOM、Material 3、导航库、符号处理器与解析版本；BOM 不解决所有插件的版本兼容性。
- 新建工程若没有对应任务、服务或设备，记录“待补充/未验证”，不要据此虚构可运行过程。

## 工具链来源

- [Android Studio releases](https://developer.android.com/studio/releases)
- [Android Gradle Plugin release notes](https://developer.android.com/build/releases/gradle-plugin)
- [Android Gradle Plugin compatibility](https://developer.android.com/build/releases/about-agp)
- [Kotlin and Android build guidance](https://developer.android.com/build/kotlin-support)
- [Compose BOM mapping](https://developer.android.com/develop/ui/compose/bom/bom-mapping)
- [Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
