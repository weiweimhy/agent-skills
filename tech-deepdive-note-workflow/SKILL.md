---
name: tech-deepdive-note-workflow
description: End-to-end workflow for writing, refactoring, and multi-track auditing deep technical principle note series (such as OS internals, reverse engineering, or runtime source analysis) with dark-mode animated SVGs and automated QA checks. Use when planning, authoring, reviewing, or finalizing a multi-lesson technical note repository, or adapting the workflow for a new series like Lua source code analysis.
---

# Tech Deepdive Note Workflow

用于长周期深度原理/源码解析/逆向工程系列笔记的**写作规范、分阶段 Review、自动化工程体检与封版判定**工作流，同时支持单会话顺序审查与 `/swarm` 三路只读并行总审阅。

## 核心护栏

- **严禁写偏与触碰隔离区**：写任何文件前锁定唯一目标笔记库路径与历史只读隔离区（例如旧稿备份）；所有本地临时编译、复跑验证一律在 `$env:TEMP` 新建子目录完成并在汇报前彻底删除。
- **严守实测边界**：先盘点本机“可用工具与版本”vs“缺失工具”；严禁脑补或伪造缺失工具的输出；未亲手实拍截图的 GUI 步骤必须显式注明。
- **反“伪闭环”底线**：严禁写硬编码耦合样本特定编译器字节序列的脚本、未真机运行却当作实操的跨工具脚本，或标题越级但核心逻辑缺失的“玩具闭环”。

## 四阶段工作流

### 1. 立项侦察与目录规划

1. **工具链与版本锚定**：在本机实测编译器、调试器、解析工具及源码版本（记录精确版本号、发布校验和或文件行号），划分可实测主线与仅作参考的边界。
2. **认知斜坡设计**：按“可触摸静态底座 → 启动/运行链 → 工具分诊图（一案多刀法）→ 80/20 高频原语 → 跨层方法与专题深水区”组织章节；小模块（3–4 篇）可顺延重命名并全库扫旧链，大模块（8+ 篇）不动物理文件名而在总路线与模块 `README.md` 导航层重组。

### 2. 单章写作与 SVG 制图门禁（7 条）

每新增或重构一章，按以下 7 条自检，详细标准见 [Review 检查表与判定准则](references/review-checklist-and-rubric.md)：

1. **钩子检验**：开篇反直觉破冰、中段预期落空反转、章末留真悬念；禁止开篇甩大段字段表或机械八股。
2. **同题异角防重**：相邻章节遇到同一机制时显式切换视角与观察层次，并用旧课靶标互链呼应。
3. **实测红利与隔离**：用真实编译器折叠/异常行为反哺教学；`$env:TEMP` 独立复编复跑，实验源码目录零构建残留。
4. **深色 SVG 动图规范**：复杂布局/映射/状态演化优先配自制深色 SVG 动图，遵守 [深色 SVG 动图规范卡](references/svg-dark-theme-spec.md)（静态帧完整 + W3C `<animateMotion>` 写法 A/B 防双重偏移）；单图设计、静态质检与本地 PNG 实渲看图可配合全局 `svg-craft` 技能，全库批量巡检由下方 QA 脚本执行。
5. **交互四要素与 GUI 声明**：写清“停在哪里 → 动作前看什么 → 动作后哪值变了 → 回答什么问题”，未实拍 GUI 显式注明。
6. **正常场景防误判边界**：攻防、异常或优化/源码状态专题必须写清正常程序/合法编译器也会出现的相似表现及静态线索 vs 动态现场边界。
7. **元数据与 0 断链**：标准 Frontmatter（含 `title == # H1`）与全库相对链接/锚点 0 断链。

### 3. 自动化只读 QA 脚本

全库改动或审阅收尾前，运行内置 PowerShell 7 只读体检脚本（默认只读扫描，不修改任何文件）：

```powershell
pwsh "<skill-dir>/scripts/Invoke-DeepdiveNoteQA.ps1" -Root "<NOTES_ROOT>" `
  -ExcludeDirRegex '\\(archive|legacy)\\' `
  -ForbiddenTerms @('OLD_TERM') `
  -AllowedArtifactPaths @('module/sample.exe')
```

脚本按 `[xml]` DOM 校验全部 `.svg` 与 `<animateMotion>` 锚点/双重偏移、扫描全库 `.md` 相对链接与 `#anchor` 断链、核对 Frontmatter 与 `# H1`、检查禁用词/隐私路径泄露以及实验目录编译产物残留。

### 4. 终极三路只读总审阅与封版判定

全系列主体完成后，发起**三路只读终审**（单会话按序推进，或在宿主支持 `/swarm` 时并行派发 3 个只读审阅员），具体 Prompt 模板、**Blocker / Major / Minor** 分级口径与**“最佳封版点”停笔判定表**见 [Review 检查表与判定准则](references/review-checklist-and-rubric.md)：

1. **深度 / 能力树与伪闭环审计**：逐模块核查是否真正打穿，揪出玩具补丁、过拟合脚本或未实跑的跨工具脚本；判定是否达到教材“最佳封版点”。
2. **跨章连贯 / 同题异角 / 术语一致性审计**：通查总路线、模块导航双向闭环、“同题异角”视角切割、语法术语与防误判边界。
3. **真机复编复跑 + SVG 动静态双检 + 全库自动化 QA**：在 `$env:TEMP` 独立复编复跑代表性源码并清理，结合 `Invoke-DeepdiveNoteQA.ps1` 完成全库零漏网校验。

## 领域即插即用档案

- **《Lua 源码解析》系列专版适配档案**（工具链侦察、版本/行号锁定纪律、五大核心数据结构 SVG 动图范式、源码解析防伪闭环红线及 QA 脚本示范命令）：见 [Lua 源码解析适配档案](references/lua-source-profile.md)。
