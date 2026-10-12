# Android UI 设计规范

状态：本资源是可裁剪建议，不是用户已批准的品牌系统。生成目标文档时记录来源、实现和验证状态，并依据实际产品、页面、UI runtime 与用户决定改写。

## 产品与范围

- 产品与目标用户：{{仓库事实或用户确认}}
- 核心任务及首批页面：{{已确认页面；未知时标记待确认}}
- UI runtime：{{既有 Compose / Views XML / 本次为新项目选定 Compose}}
- 设计来源：{{已有系统 / 本次可逆决定 / 待用户输入}}
- 实现入口：{{真实 theme、组件、资源和页面路径}}
- 验证状态：未验，除非已记录实际页面、设备与检查结果。

受众或核心页面未知时，只记录平台基线和缺口，不编造产品事实或外部参考。
产品输入充分且获授权时，没有既有设计稿也可建立可逆基线，注明“本次决定”。
既有 Views/XML 项目沿用现有主题、控件和导航，不因使用 Kotlin 而切换 Compose。

## 视觉与主题

新建 Compose 项目可优先使用 Material 3 稳定组件、语义色、字级和形状。
既有项目沿用当前 UI 技术与主题；全局换肤或 View 到 Compose 迁移需单独授权。

| 维度 | 建议基线 | 目标项目记录 |
| :--- | :--- | :--- |
| 颜色 | 使用 Material 语义角色；状态不只靠颜色 | {{色板入口与对比检查}} |
| 字体 | 使用 Material typography 角色与系统字体缩放；长文本允许换行增长 | {{实际主题入口、语言回退和验证}} |
| 形状 | 使用 Material shapes 角色；按控件重要度与容器关系保持层次 | {{实际 shape token 与例外}} |
| 密度 | 可从 4、8、12、16、24、32dp 间距刻度起步 | {{已实现 token 或本次建议；不得误写为既有配置}} |
| 触控 | 常用交互目标至少 48dp；按设备密度用 dp 布局 | {{代表控件路径与设备检查}} |

选定 Compose/Material 3 后，可按以下角色形成单一主题映射，状态为
“模板建议／待实现／未验”；已有主题优先。生成时填入真实源码入口：

- 内容面：`colorScheme.surface` / `onSurface`；辅助文字：`onSurfaceVariant`。
- 主要操作：`primary` / `onPrimary`；次要容器：`secondaryContainer` /
  `onSecondaryContainer`；错误提示：`error` / `onError`。
- 页面标题：`typography.headlineSmall`；正文：`bodyLarge`；按钮标签：`labelLarge`。
- 容器形状从 `MaterialTheme.shapes` 的角色读取，组件不另建一套圆角值。
- 布局使用 `dp`，文字使用 `sp` 并保留系统字体缩放；不移植 Web 的 px 断点。

上述色彩、字体和形状均取自 `MaterialTheme`；实际数值以选定库及项目主题为准。
检查必要文字和控件边界的实际相邻色对比，而非仅核对 token 名称。

浅色/深色、动态颜色和品牌覆盖是可选支持范围。只有仓库或用户决定支持时才记为项目事实，并为动态色不可用时记录回退方案。不要用固定十六进制值冒充产品品牌决定。

## 布局与适配

- 按实际窗口尺寸和内容关系布局；手机、平板、折叠设备和桌面仅在目标范围内记录。
- 新界面评估 Window Size Class 与 Material 3 adaptive；先核对目标库和版本，
  不能从 Compose 依赖推断已采用。
- 在每个目标尺寸检查导航呈现、内容列数、滚动、长文本、系统栏与手势区域。
- 尊重 edge-to-edge、状态栏/导航栏 insets 和 IME。表单在键盘出现时保持字段、错误和提交操作可达。
- 支持 RTL 时检查布局镜像与图标方向，不只检查翻译文本。

## 组件与状态

只保留产品中实际存在或已批准规划的组件与状态。共用组件引用实际入口；设计基线中的计划组件要标为待实现。

| 组件 | 适用规则 |
| :--- | :--- |
| Button / IconButton | 使用 Material 语义变体；说明主要、次要、危险操作，禁用与加载状态 |
| 输入控件 | 标签、说明、错误关联清楚；支持键盘类型、IME action 与可恢复错误 |
| 列表/卡片 | 内容层级、点击区域和读屏顺序明确；列表项不强制嵌套卡片 |
| 对话框/底部面板 | 只在任务需要时采用；定义取消、系统返回、焦点和提交中状态 |
| 导航 | 沿用实际导航实现与平台返回行为；新 Compose app 的 Navigation 3 选择单独核实 |

Material 3 的组件选择可从主要操作 `Button`、次要操作 `FilledTonalButton`、
低强调操作 `TextButton` 起步；危险操作同时用明确文本、错误色角色和适用的确认流程。
这是候选变体映射，须按真实任务裁剪，不能只把危险按钮染红。

只验证适用于页面的成功、加载、空、错误、禁用、权限和恢复状态。无对应流程的状态删除，不为模板填满矩阵。

## 图标

- 图标系统只记录已采用或本次授权决定。候选是按需下载的 Material Symbols
  Android vector XML；核对来源、许可与资源入口。
- 不把旧 material-icons artifact 或 material-icons-extended 视为默认依赖；不要为少量图标引入整包资源。
- 有语义的图标按钮提供本地化可访问名称。纯装饰图标设
  `contentDescription = null`，避免重复读出相邻文本。
- 仅当图标含义不明显时提供提示；提示不能代替可访问名称，触摸场景仍需明确操作文本或上下文。

## 动效与系统行为

Material 组件默认动效优先。自定义动效只记录实际或已批准规划的触发、属性、时长、结束状态、可中断性与实现入口；没有产品任务依据时不为页面添加装饰动画。

如获授权规划自定义动效，可从局部透明度反馈 120ms、内容状态切换 200ms、
容器过渡 300ms 起步。这些数值是模板建议，不覆盖库内 spring 或组件默认值；
生成时写入共享 motion token，并记录属性、插值或 spring 参数、结束状态及取消行为。
未选择的动效不生成规则。系统关闭动画时直接到达目标状态，仍须测试快速重复操作；
记录实际读取系统设置的机制，未知时标为待实现，不能假定所有自定义动画自动遵循。

- 不延迟输入响应或业务完成；加载、成功和失败状态始终有可读文本或语义。
- 遵循系统减少动态效果设置，确认缩放或关闭动画后状态和返回流程仍清楚。
- 导航返回交由平台与当前 Navigation 实现协作，检查 predictive back 预览。不要在根 Activity 拦截返回而破坏系统动画。
- Material 3 Expressive 可由排版、留白、形状和稳定组件表达。使用实验组件
  前，按解析版本核对 release notes 和 opt-in 注解，并记录封装边界。

## 参考

- [Material 3 for Compose](https://developer.android.com/develop/ui/compose/designsystems/material3)
- [Material Symbols for Compose](https://developer.android.com/develop/ui/compose/graphics/images/material)
- [Compose accessibility defaults](https://developer.android.com/develop/ui/compose/accessibility/api-defaults)
- [Predictive back setup](https://developer.android.com/develop/ui/compose/system/predictive-back-setup)
- [Now in Android design and UI notes](https://github.com/android/nowinandroid/blob/main/README.md)
- [Jetpack Compose samples](https://github.com/android/compose-samples)
