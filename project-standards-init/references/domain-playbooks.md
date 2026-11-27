# 多领域项目基座手册

按仓库已证实的技术栈，**仅读取对应领域章节**，将其中“代码局部看不出、AI 最容易踩坑、最能帮 AI 提速”的要素提炼进项目基座。未采用的技术绝不写入。

---

## 一、后端 / 系统 / CLI / 基础设施（Go / Rust / Python / 分布式）

成熟后端与系统仓库（如 Kubernetes、Temporal、CockroachDB、TiDB、Grafana、Ruff、uv、Caddy、Prometheus、Pydantic）的共同经验：**写清验证分层、隐性系统不变量与生成物边界，比写编码风格手册重要十倍。**

### 高信噪比基座要素

1. **封装工具与验证成本分层（WIP vs Ready）**
   - 明确项目是否必须走封装入口（如 `./dev`、`make`、`just`、`uv run`、`cargo nextest`），而非裸跑底层命令。
   - 给出**单包/单测过滤命令**与必带参数（如 `-tags`、`-race -short`、排除沙盒会超时的测试集），并显式点出**极慢或本地禁跑的全量命令**，防止 AI 在小改动上耗尽轮次。
   - 若有快照测试（如 `insta`、`golden`），写明更新环境变量与待提交清理规则。
2. **只读生成产物与依赖锁边界**
   - 列出禁止手改的生成路径（`*.pb.go`、`zz_generated.*`、Wire/DI、CUE/OpenAPI、SQLC、Bazel `BUILD` 文件等）及**唯一再生命令**与触发条件。
   - 注明依赖锁定陷阱（如禁用裸 `go mod tidy`、禁止全量刷新 lockfile 而用精准更新命令）。
3. **系统级隐性不变量（安全、并发、兼容、性能）**
   - **并发与时钟**：锁选型原则、临界区外执行 I/O、共享对象/proto 拷贝边界、虚拟时钟 vs 墙钟、测试禁用 `sleep` 同步。
   - **兼容与滚动升级**：前后端/多节点异步发布时的向后兼容规则（禁止单 PR 同时破坏旧客户端/旧服务端契约、schema 仅增量扩展）。
   - **安全与脱敏**：敏感凭证/URL 脱敏入口（如防错误包装泄露原始含密 URL）、外部输入/SQL 安全边界、严禁提交本地密钥。
   - **性能与热路径**：若有性能回归门禁，给出可复现基准命令（如 `go test -count=6 -benchmem` + `benchstat`）及缓冲区/内存所有权约定。
4. **反直觉环境陷阱（Gotchas）**
   - 临时复现脚本放仓库内是否会命中根配置（如 `pyproject.toml`）、分支名字符限制、非标准测试端口、测试子进程成本守卫等真实踩坑。
5. **Bug 修复作用域纪律**
   - 先复现失败测试再修，不凭直觉顺手改动未复现的兄弟模块或共享基类。

---

## 二、全栈 / Monorepo / Web 工程（TypeScript / Node / React / Vue / Next.js）

成熟全栈与前端工程仓库（如 Next.js、Supabase、Twenty、Cal.com、Storybook、TanStack、Remotion）的共同经验：**三层渐进披露 + 本地版本文档锚点 + 10 秒级局部检验。**

### 高信噪比基座要素

1. **三层结构防膨胀**
   - 根 `AGENTS.md`：只放 workspace 边界、全局包管理器、根级命令、公共复用与子应用路由表。
   - 子应用/子包 `AGENTS.md`（如 `apps/web/AGENTS.md`、`packages/ui/AGENTS.md`）：就近承载该包特有的路由、状态、数据层与局部反直觉约定。
   - 视觉与组件审美：独立至 `DESIGN.md`（见 [前端视觉与 UI 基座](frontend-design-contract.md)），不与构建脚本混写。
2. **对抗模型过时记忆的版本锚点**
   - 明确主框架大版本及关键范式差异（如 React 19、Next.js App Router、Vue 3 Composition、TanStack Router SSR/CSR 边界）。
   - 若 `node_modules` 或 `docs/` 内存在版本匹配的本地文档，在根文件加一行指针，引导 AI 先查本地文档而非依赖训练记忆。
3. **高速校验与防阻塞/防噪声命令**
   - 区分单包/单文件快速类型检查（如 `tsc --noEmit` / `tsgo`）与全量构建；指出构建缓存工具（Nx/Turbo）何时可能返回过期缓存。
   - 明确**防挂起参数**（如 `vitest run`、`jest --watchAll=false`、禁止启动阻塞终端的 `dev` 服务器）。
   - 优先提供静默模式或封装脚本（仅失败输出），避免上千条 lint warning 挤爆上下文。
4. **复用清单与“此仓默认不同”陷阱（Defaults That Differ Here）**
   - 列出共享 `utils` / `hooks` / UI primitives 入口，阻断 AI 重复造轮子。
   - 点出与常规直觉相反的仓库约定（如禁止 barrel import、日期库/图标导入后缀约定、环境变量/时区 `TZ=UTC` 要求、SSR 安全边界）。
   - 把 `as any`、硬编码色值、死代码（knip）、警告棘轮（lint ratchet）尽量前移到自动化命令。

---

## 三、原生桌面 / 游戏客户端 / 跨端桥接（Unity C# / Lua / Wails / Tauri / Swift / Godot）

成熟原生与游戏仓库（如 Zed、Ghostty、Wails、mcp-unity、gdUnit4、SwiftAgents、Now in Android）的共同经验：**原生运行时与跨端桥接的隐性规则是 AI 最常翻车的地方，必须显式写出，同时明确反 Web 惯性。**

> 若目标项目是 **Android / Kotlin 原生应用**，直接转读 [Android / Kotlin 原生模板](android-project-template.md)。

### 高信噪比基座要素

1. **精准定向构建与无头验证命令**
   - 原生全量打包极慢，务必给出**跳过打包或按目标过滤的快速编译/单测命令**（如定向 target、headless 引擎测试命令、带 `GODOT_BIN` 或 Gradle 变体的命令）。
   - 若项目提供 IDE/运行态 MCP（如 Xcode MCP、Wails MCP），写清调用边界与已知限制（例如 DOM 快照不等于像素截图、异步 job 需轮询状态）。
2. **线程、生命周期与所有权不变量**
   - **主线程 / UI 线程边界**：哪些 API 必须在前景/主线程调用，严禁同步阻塞主线程。
   - **重载与生命周期重置**：如 Unity Domain Reload / Play Mode 切换会清空静态内存状态、任务句柄 drop 即取消、实体更新禁止重入、Lua 协程生命周期与错误传播。
   - **过时 API 纠偏**：针对演进快的原生生态（如 Swift 6 严格并发 `@Observable`/`@MainActor`、Godot 4.x、Wails v2 vs v3），用简明对照表标出“旧写法 → 本仓现代写法”。
3. **跨端 / 跨语言 / 双产物同步清单**
   - 明确 Native ↔ WebView / C# ↔ Lua / C ABI 的职责与命名契约（如跨端工具名一致性、DTO 序列化约束、C enum 哨兵值、高频跨边界调用的性能红线）。
   - 列出**双产物同步步骤**（如改 runtime 源码必须同时编译前端资产与宿主包、改 C# 接口必须同步更新 Lua 绑定/胶水层）。
4. **引擎与 IDE 托管资产边界**
   - 明确哪些文件由编辑器、引擎或 git hook 托管（如 Unity `.meta`/`.prefab`/`.unity`/`ProjectSettings`/`Library/`、Godot `.tscn` 的 `uid`、Xcode 工程文件、自动生成绑定），划清“不可随意手改/误提交”与“可安全修改”的边界。
   - 明确不套用 Web 假设（固定 px 断点、CSS 布局、无锁单线程模型）。

---

## 四、通用文档库 / 技能库 / 工具脚本仓

- **确定性校验入口**：直接写出格式、元数据、链接或行数预算校验脚本命令（如 `pwsh ./scripts/validate-*.ps1`、`markdownlint`）。
- **源仓库与部署/消费边界**：若存在源码仓与部署 clone、或模板资产与实际业务项目之分，用 2–3 行写清唯一可编辑位置与同步方式。
- **跨平台与编码约束**：Windows PowerShell 路径与 UTF-8（无 BOM）写文件要求、禁止写入个人绝对路径或敏感配置。
