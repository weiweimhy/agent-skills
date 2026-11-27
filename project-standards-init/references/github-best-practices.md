# GitHub 多领域项目基座最佳实践来源与取舍

本文件记录 `project-standards-init` 升级为“赋能型项目基座”所依据的实证研究与开源仓库一手样本（多领域检索核实日期：2026-11-27；前端设计方法参考核实日期：2026-09-20）。这些仓库是方法论来源，**不是目标项目已采用的依赖或默认栈**。

## 一、核心实证与 Harness Engineering 共识

| 来源 | 核心洞察 | 在本技能中的转化 |
| :--- | :--- | :--- |
| [ETH Zurich: Evaluating AGENTS.md (arXiv:2602.11988)](https://arxiv.org/abs/2602.11988) | 自动生成的百科式上下文文件使任务成功率平均降 ~3%，Token 成本增 >20%（过度顺从与注意力稀释） | 根 `AGENTS.md` 严控 50–120 行；删除显而易见的目录树与通用工程废话 |
| OpenAI Harness Engineering & `agentsmd/agents.md` | `Agent = Model + Harness`；根文件做 ~100 行“地图”而非手册，文档会腐烂但 Linter/架构测试不会 | 强调“地图而非百科”，把风格与机械规则推向 Linter/脚本而非 Markdown |
| HumanLayer (`humanlayer/humanlayer`) & Anthropic Context Engineering | 指令预算约 150–200 条；用静默包装命令防 warning 淹没上下文；Just-in-Time 按需检索 | 推崇静默/局部快速校验命令、单跳渐进披露与精简根文件 |
| Vercel (`AGENTS.md` vs Skills Evals) & `getsentry/sentry` / `cloudflare/agents` | 纯靠模型自觉触发隐藏文档漏触率高；根文件保留轻量被动路由索引 + 单一事实源（`CLAUDE.md` 仅 `@AGENTS.md`）+ 子目录嵌套 `AGENTS.md` | 根文件保留 `Before you... → Read ...` 路由表，大仓拆子目录 `AGENTS.md`，跨宿主用 `@AGENTS.md` 统一 |
| `anthropics/claude-code`、`stripe/stripe-cli`、`vercel/next.js` | 高信号 `CLAUDE.md`/`AGENTS.md` 聚焦安全红线、生成物 `DO NOT EDIT`、快慢命令区分与真实踩坑 | 将命令分层、只读生成物与 Gotchas 作为核心必备模块 |

## 二、后端与系统工程样本

- **`astral-sh/ruff` & `astral-sh/uv`**：精确 `cargo nextest` 过滤（排除沙盒超时项）、快照工作流、`cargo update --precise`、生产路径类型约束与临时脚本路径陷阱。
- **`temporalio/temporal`、`cockroachdb/cockroach`、`pingcap/tidb`、`grafana/grafana`**：封装 CLI（`./dev`）、WIP vs Ready 验证分层、分布式滚动升级双向兼容（`pkg/storage/unified/AGENTS.md`）、并发锁/虚拟时钟/锁外 I/O、URL 凭证脱敏与防止 `pnpm test` 默认 `--watch` 卡死。
- **`kubernetes/kubernetes`、`caddyserver/caddy`、`prometheus/prometheus`、`pydantic/pydantic-ai`**：极简高密度红线（~45 行）、生成物清单、基准测试契约（`benchstat`）、Bug 先复现再修的作用域纪律与禁止本地盲跑全量慢检查。

## 三、全栈、前端与设计系统样本

- **`twentyhq/twenty`**：`AGENTS.md` 与 `DESIGN.md` 物理正交；代码是数值真源、新规范优先旧页；`Copy the sibling`（标杆页面）、`Need → Use → Instead of` 组件选用表、`Verify in the real parent` 真实父容器验收与 `no-hardcoded-colors` ESLint 兜底。
- **`supabase/supabase`、`calcom/cal.com`、`remotion-dev/remotion`、`storybookjs/storybook`、`shadcn-ui/ui`、`TanStack/router`**：三层渐进披露（根 → 子应用 → 任务参考）、本地版本文档指针（`node_modules/next/dist/docs/`）、`Defaults that differ here`、Always/Ask First/Never 三栏自主边界、Storybook `play` / 静态渲染校验与自动化棘轮门禁。
- **视觉与动效方法参考（2026-09-20 固定版本核实）**：
  - [Anthropic frontend-design](https://github.com/anthropics/skills/blob/34040c9c568585f6929bedeaad110ad08f079624/skills/frontend-design/SKILL.md)：从产品题材与受众确立视觉身份，不做通用模板套用。
  - [Impeccable animate](https://github.com/pbakaus/impeccable/blob/f2c7051853848826aac2f4646581d62a732155ad/.agents/skills/impeccable/reference/animate.md) 与 [Emil animate](https://github.com/emilkowalski/skill/blob/85e8e2363b713506e1d5b6e07a0eb2da66be1bc3/skills/animate/SKILL.md)：动效服务反馈与状态，重视可中断性、退出与 `prefers-reduced-motion`。
  - [Taste Skill](https://github.com/Leonxlnx/taste-skill/blob/e79ca9ec7e071eb3a3b623c4fb752e853fc3ed58/skills/taste-skill/SKILL.md)：从 brief 推导风格并沿用真实设计系统（注意其偏向落地页/作品集，不套用到工具后台）。

## 四、原生移动、桌面与游戏客户端样本

- **`android/nowinandroid` & `twostraws/SwiftAgents`**：精确变体构建/单测命令、版本锚点与反过时 API 纠偏表、CI 托管截图基线、原生 MCP 协作边界。
- **`zed-industries/zed` & `ghostty-org/ghostty`**：Rules Hygiene（只写非显而易见的高频坑，不写易过时代码地图）、前景/后台线程与实体防重入不变量、定向快编参数（`-Demit-macos-app=false`）与 C ABI 兼容哨兵。
- **`wailsapp/wails`、`CoderGamester/mcp-unity`、`godot-gdunit-labs/gdUnit4`**：多代代码隔离（`v2/` vs `v3/`）、双产物同步清单、Unity 主线程与 Domain Reload 内存重置、跨端命名与安全边界、引擎托管资产（`.tscn` uid / `.meta` / `Library/`）与无头引擎测试入口。

## 五、开源初始化技能设计样本

- **`anthropics/skills` (`skill-creator`) & `obra/superpowers` (`writing-skills`)**：Explain the why 胜过僵硬 ALWAYS/NEVER；按失败形态选表达形式（格式问题用正向填空骨架而非反面禁令）。
- **`netresearch/agent-rules-skill`、`zencoderai/skills`、`github/awesome-copilot`、`openai/skills`**：Golden Samples + Utilities + Gotchas 主动加速三件套、增量合并保留人工规则、零空壳文档原则。

## 取舍原则

- **吸收共性基座，拒绝照搬偶发仪式**：不把特定仓库的人格指令、单一云环境路径、强绑定某个第三方工具链的私有流程带进通用初始化技能。
- **用户意图与项目事实始终高于外部参考**：任何外部最佳实践只提供“该写什么类型的高信号信息”，不预设具体框架、配色、组件库或目录结构。
