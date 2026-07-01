---
name: release
description: Release workflow guidance for semantic versioning, release notes, changelogs, Git tags, package artifacts, verification, and rollback. Use when preparing a version release, GitHub Release, tag, or publish checklist.
---

# 发布版本 Skill

发布项目新版本到 GitHub 或其他发布渠道，遵循语义化版本规范。

## 🎯 触发条件

当以下情况发生时启用：

- "准备发版"
- "生成 Release Notes"
- "帮我打标签发布"
- "检查这个版本号怎么升"

👉 自动启用本 Skill

## 🎯 Purpose

指导一次可重复、可审计的发布流程，覆盖版本判断、Release Notes 生成、标签发布与发布后验证。

## 🧩 Capabilities

- 依据提交历史与兼容性判断推荐版本号。
- 生成可整理的 Release Notes 草稿。
- 提供发版前检查、打标签、验证与回滚建议。

## 🧠 Usage

- 在准备为项目打版本标签并发布时使用。
- 当需要根据提交历史整理 Release Notes 时使用。
- 当需要检查包名或模块路径、标签格式与发布后可见性时使用。

## 📥 Input

- 自上个版本以来的提交记录或 diff 范围。
- 拟发布版本号与是否包含 breaking change。
- 当前包名或模块路径与目标发布渠道（GitHub Release、包管理平台、镜像仓库等）。

## 📤 Output

- 建议的版本号与升级理由。
- 按分类整理的 Release Notes 草稿。
- 完整的发布检查清单与执行步骤。

## 🔍 Source Mapping

| 能力 | 来源 | 类型 |
| :--- | :--- | :--- |
| 语义化版本控制 | `semver-standard` | ✅ 行业标准规范 |
| Release Notes 自动化 | `github-changelog-gen` | ✅ 整合优质开发模式 |
| 分发与产物管理 | `goreleaser-patterns` | ✅ 参考 CI/CD 最佳实践 |

## 📚 参考资料 (References)

- [Semantic Versioning 2.0.0](https://semver.org/)
- [GitHub Release Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)

## 前置条件检查

在发布前，必须确认以下条件：

```powershell
# turbo
# 1. 确保工作目录干净（无未提交的修改）
git status

# turbo
# 2. 确保项目测试通过（替换为项目实际命令）
<TEST_COMMAND>

# turbo
# 3. 确保项目可以正常构建或打包（替换为项目实际命令）
<BUILD_COMMAND>

# turbo
# 4. 检查版本、依赖或锁文件是否已处于预期状态
git diff -- <VERSION_OR_LOCK_FILES>
```

如果依赖清单或锁文件需要整理，再单独执行对应命令，并确认改动符合预期后再继续发布。

## 版本号确定

### 查看当前版本

```powershell
# turbo
git tag --list --sort=-v:refname | Select-Object -First 5
```

### 语义化版本规则

根据 [Semantic Versioning](https://semver.org/)：

| 版本类型 | 何时使用 | 示例 |
| :--- | :--- | :--- |
| **Major** (X.0.0) | 不兼容的 API 变更 | v3.0.0 → v4.0.0 |
| **Minor** (x.Y.0) | 向后兼容的功能新增 | v3.2.0 → v3.3.0 |
| **Patch** (x.y.Z) | 向后兼容的问题修正 | v3.2.0 → v3.2.1 |

### 决定新版本号

**需要确认**：

1. 本次发布包含哪些改动？（新功能、Bug 修复、破坏性变更）
2. 建议的新版本号是什么？

## Release Notes 生成规范

为了生成高质量的 Release Notes，遵循以下分类规则。

### 提交类型映射

| 提交类型 | Release Notes 章节 | 说明 |
| :--- | :--- | :--- |
| `feat` | **🚀 Features** | 新增功能 |
| `fix` | **🐛 Bug Fixes** | 错误修复 |
| `perf` | **⚡ Performance** | 性能优化 |
| `refactor` | **🛠 Improvements** | 代码重构（对用户有感知的改进） |
| `docs` | **📝 Documentation** | 文档更新 |
| `chore`, `test`, `style` | **🧹 Others** | 其他不影响核心功能的变更 |

### Release Notes 模板

```markdown
# Release vX.Y.Z (YYYY-MM-DD)

## 🚀 Features
- [scope] 简短描述提交内容

## 🐛 Bug Fixes
- [scope] 修复了某个已知问题

## ⚡ Performance
- [scope] 优化了某个模块的执行效率

## 🛠 Improvements
- [scope] 提升了某个功能的易用性

## 📝 Documentation
- 更新了 README 关于 X 功能的说明

---
**Full Changelog**: <REPO_URL>/compare/vOLD...vNEW

## 📦 Distribution & Artifacts

- **CI/CD**: 如果项目配置了发布流水线，确认标签或 release 事件会触发对应任务。
- **二进制发布**：如果是工具类项目，确认 Release 页面或制品仓库包含目标平台产物。
- **Docker 镜像**：如果涉及服务端应用，确认版本化镜像标签与 release 版本一致。
```

## 发布流程

### 步骤 1：生成 Release Notes

#### 1. 自动化生成 (AI 驱动)

**指令**：请 AI 根据自上个版本以来的提交记录，参照上面的“Release Notes 模板”自动生成一份草稿。

```powershell
# turbo
# 获取自上个版本以来的所有提交（替换 <LAST_TAG>）
git log <LAST_TAG>..HEAD --oneline --no-decorate
```

#### 2. 手动调整

- 检查 AI 生成的分类是否准确。
- 确保主标题版本号和日期正确。
- 合并重复或过细的提交项，使其阅读体验更佳。

### 步骤 2：确认包或模块版本路径

确认包名、模块路径、版本字段和发布目标一致。对于 Go v2+ 模块，`go.mod` 中的 module 路径还应包含版本后缀：

```go
// 示例：当前 v2.x 版本应该带 /v2 后缀。
module github.com/example/project/v2
```

### 步骤 3：创建 Git 标签

```powershell
# 创建带注释的标签（替换 <VERSION> 和 <MESSAGE>）
git tag -a <VERSION> -m "<MESSAGE>"

# 示例：
# git tag -a v3.3.0 -m "feat: 添加 JWT 认证模块"
```

### 步骤 4：推送标签

```powershell
# 推送标签到远程仓库
git push origin <VERSION>
```

### 步骤 5：验证发布

```powershell
# turbo
# 确认标签已推送
git ls-remote --tags origin | Select-String "<VERSION>"
```

等待几分钟后，在对应发布渠道验证新版本是否可用，例如 GitHub Release、包管理平台、Docker Registry 或内部制品仓库。

## 发布后清理

如果发布渠道存在缓存或索引延迟，按对应生态执行刷新或验证命令。例如 Go 模块代理：

```powershell
# turbo
# Go 模块示例：请求代理更新（替换 <MODULE_PATH> 和 <VERSION>）
$env:GOPROXY="https://proxy.golang.org,direct"; go list -m <MODULE_PATH>@<VERSION>
```

## 常见问题

### 删除错误的标签

```powershell
# 删除本地标签
git tag -d <VERSION>

# 删除远程标签
git push origin --delete <VERSION>
```

### 版本号格式

- ✅ 正确：`v3.2.0`、`v3.2.1`
- ❌ 错误：`3.2.0`、`V3.2.0`、`v3.2`

## 快速发布命令汇总

```powershell
# 完整发布流程（替换变量后执行）
$VERSION = "v3.3.0"
$MESSAGE = "feat: 添加新功能描述"

git status
<TEST_COMMAND>
<BUILD_COMMAND>
git tag -a $VERSION -m $MESSAGE
git push origin $VERSION
```

如果依赖清单需要整理，应在打标签前单独执行对应命令（如 `go mod tidy`、`npm install`、`poetry lock`），并审阅产生的 diff 后再继续。

## ⚠️ Constraints

- ❌ 不把依赖整理、锁文件更新或格式化命令当成只读检查；任何会改写文件的操作都需要先审阅 diff。
- ❌ 不在工作区存在未确认改动时直接打标签发布。
- ✅ 版本号、包名或模块路径与发布渠道校验地址必须保持一致。
- ✅ 如发现 breaking change，必须在版本判断与 Release Notes 中明确标记。

## 🔗 Related Skills

- [git-workflow](../git-workflow/SKILL.md): 高质量提交历史有助于生成更准确的版本说明。
- [git-workflow](../git-workflow/SKILL.md): 可在发版前帮助整理变更与提交粒度。
- [doc-generator](../doc-generator/SKILL.md): 适合配合输出 Changelog、README 更新与发布文档。
