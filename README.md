# 🤖 Agent Skills

一个可复用的 AI Agent 技能库，为代码生成、规范约束与自动化决策提供标准化能力定义。

## ✨ 特性

- 📦 **模块化设计** - 每个技能独立封装，即插即用
- 🔗 **易于集成** - 通过 git submodule 轻松引入项目
- 🌐 **多语言支持** - 覆盖 Go、Python、TypeScript、C#、Lua 等
- 📚 **文档完善** - 每个技能包含详细的 SKILL.md 定义

## 📂 目录结构

```
agent-skills/
├── SKILLS.md              # 技能索引
├── core/                  # 核心技能
│   ├── ai/                # AI 辅助技能
│   ├── backend/           # 后端开发技能
│   ├── frontend/          # 前端开发技能
│   ├── *-review/          # 语言审查技能
│   └── ...                # 其他通用技能
└── skill-builder/         # 技能构建工具
```

## 🚀 快速开始

### 作为 Git Submodule 引入

```bash
# 添加为 submodule（推荐路径：.agent/skills）
git submodule add <repo-url> .agent/skills

# 更新 submodule
git submodule update --remote
```

### 兼容多种 AI 助手

本库使用**相对路径**设计，可以作为 submodule 引入到任何 AI 助手的技能目录下：

| AI 助手 | 推荐引入路径 |
|---------|-------------|
| Antigravity | `.agent/skills/` |
| Claude Code | `.claude/skills/` |
| 其他 | 自定义路径 |

```bash
# 示例：引入到 .agent/skills
git submodule add <repo-url> .agent/skills
```

## 📋 技能清单

### 🧠 Core Skills（通用）

| 技能 | 描述 |
|------|------|
| [git-commit](core/git-commit/SKILL.md) | 生成规范化 Git Commit Message |
| [git-workflow](core/git-workflow/SKILL.md) | 规范化 Git 提交全流程引导 |
| [release](core/release/SKILL.md) | 生成版本说明 / 更新日志 |
| [code-review](core/code-review/SKILL.md) | 通用代码审查哲学与流程 |

### 🧩 Project Skills（项目相关）

| 技能 | 描述 |
|------|------|
| [api-design](core/backend/api-design/SKILL.md) | API 命名与 RESTful 设计规范 |
| [backend-patterns](core/backend/backend-patterns/SKILL.md) | 后端架构与模块拆分 |
| [validation-lint](core/backend/validation-lint/SKILL.md) | 参数与接口校验 |
| [mongodb-master](core/backend/mongodb-master/SKILL.md) | MongoDB 专家级设计 |
| [vue](core/frontend/vue/SKILL.md) | Vue 3 / Composition API |
| [react](core/frontend/react/SKILL.md) | React 18/19 & Hooks |

### 🐹 Language Skills（语言相关）

| 技能 | 描述 |
|------|------|
| [go-review](core/go-review/SKILL.md) | Go 语言专家级代码审查 |
| [python-review](core/python-review/SKILL.md) | Python 语言专家级代码审查 |
| [typescript-review](core/typescript-review/SKILL.md) | TypeScript 专家级代码审查 |
| [csharp-review](core/csharp-review/SKILL.md) | C# 语言专家级代码审查 |
| [lua-review](core/lua-review/SKILL.md) | Lua 语言专家级代码审查 |

### 🤖 AI Skills（AI 辅助）

| 技能 | 描述 |
|------|------|
| [prompt-design](core/ai/prompt-design/SKILL.md) | Prompt 编写规范与结构设计 |
| [doc-generator](core/ai/doc-generator/SKILL.md) | API 文档 / 注释 / README 生成 |
| [product-manager](core/ai/product-manager/SKILL.md) | 人话转译与需求拆解 |
| [architecture-consultant](core/ai/architecture-consultant/SKILL.md) | 系统架构咨询与 ADR 生成 |

### 🔧 Utility Skills（工具）

| 技能 | 描述 |
|------|------|
| [markdown](core/markdown/SKILL.md) | Markdown 编写规范与 Lint |
| [skill-builder](skill-builder/SKILL.md) | 帮助创建新的 Skill 定义 |

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/new-skill`)
3. 使用 [skill-builder](skill-builder/SKILL.md) 创建新技能
4. 提交变更 (`git commit -m 'feat: add new skill'`)
5. 推送分支 (`git push origin feature/new-skill`)
6. 创建 Pull Request

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源。
