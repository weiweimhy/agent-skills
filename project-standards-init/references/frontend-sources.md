# GitHub 前端设计参考与取舍

用于维护前端初始化契约，或按页面任务选择配套技能。检索与阅读日期：2026-09-20。
以下链接固定到本次实际读取的提交；是设计方法参考，不是目标项目已采用的依赖。
本库归纳可迁移的原则，不复制整套第三方技能，不要求初始化时联网或安装全部技能。

## 已核实的来源

| 来源与固定版本 | 借鉴内容 | 使用边界 |
| --- | --- | --- |
| [Anthropic frontend-design](https://github.com/anthropics/skills/blob/34040c9c568585f6929bedeaad110ad08f079624/skills/frontend-design/SKILL.md) | 从产品题材与受众确定视觉身份；先定义色彩、排版和布局；设计后自检 | 不将某种字体、配色或营销页结构当作通用禁令或默认 |
| [Impeccable animate](https://github.com/pbakaus/impeccable/blob/f2c7051853848826aac2f4646581d62a732155ad/.agents/skills/impeccable/reference/animate.md) | 动效解释反馈、状态与关系；区分操作界面与展示场景；检查中断、退出和减少动态效果 | 不因追求表现力增加无意义动画或昂贵依赖 |
| [Taste Skill](https://github.com/Leonxlnx/taste-skill/blob/e79ca9ec7e071eb3a3b623c4fb752e853fc3ed58/skills/taste-skill/SKILL.md) | 从 brief 推导风格，沿用真实设计系统，保持颜色、形状与图标语言一致 | 该版本明确面向落地页、作品集与改版；不把营销页限制套到后台、数据表或多步骤任务 |
| [Emil animate](https://github.com/emilkowalski/skill/blob/85e8e2363b713506e1d5b6e07a0eb2da66be1bc3/skills/animate/SKILL.md) | 先判断动效目的与频率，再选择工具、属性、时长、退出和打断；复用 motion token | 不照搬键盘操作一律不动画、特定曲线唯一正确等绝对规则；性能需在实际运行时验证 |

GitHub 元数据报告 Impeccable 为 Apache-2.0，Taste Skill 与 Emil skill 为 MIT。
Anthropic 仓库 API 未提供统一许可证标识，技能正文指向其 `LICENSE.txt`。
这些信息不替代逐文件许可检查；后续若复制代码、素材或完整技能，需读取对应版本许可并保留必要声明。

## 如何转化为本项目规则

- **风格**：记录适合目标产品的选择及理由，落成语义 token 和布局规则；不只保存审美形容词。
- **一致性**：一个权威设计文档、一个 token 实现入口、共享组件与状态矩阵。
  初始化文档将路径与状态写清，后续页面先复用再扩展。
- **图标**：以项目实际来源或本次明确选择为准；一个主家族、语义映射、统一尺寸与描边，
  品牌标志作为注明来源的例外。技能列出的图标库不是当前项目的安装事实。
- **动效**：优先为操作反馈与状态过渡服务。按频率与距离选取一致的时长和缓动，
  处理退出、中断、焦点、触屏与减少动态效果；CSS 能完成时不引入额外库。
- **验收**：通过代表页面检查设计在真实内容与多个状态下是否一致；静态截图只证明静态外观，
  动效必须实际触发。区分设计要求、已实现和已验证。

## 配套技能与冲突处理

已安装时可按需使用 Impeccable 做产品 UI 设计与检查，Taste Skill 做落地页或作品集风格探索，
Emil animate 做专项动效实现，React/Vue/Tailwind 技能处理对应技术栈。
它们缺失时直接依据 [前端设计契约](frontend-design-contract.md) 完成初始化，不阻塞工作。
不要仅为初始化安装新技能、组件库或动效库。

用户当前要求优先，其次是项目有效的品牌与视觉规范；外部技能提供方法，不能覆盖这些决定。
当外部偏好与产品冲突时采用适合本项目的规则，记录有实际影响的取舍即可。
