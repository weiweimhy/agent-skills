# 🤖 Agent Skills

一个可复用的 AI Agent 技能库，为代码生成、规范约束与自动化决策提供标准化能力定义。

## ✨ 特性

- 📦 **模块化设计** - 每个技能独立封装，即插即用
- 🔗 **易于集成** - 通过 git submodule 轻松引入项目
- 🌐 **多语言支持** - 覆盖 Go、Python、TypeScript、C#、Lua 等
- 📚 **文档完善** - 每个技能包含详细的 SKILL.md 定义
- 🧭 **机器可读 Schema** - 统一 frontmatter，便于自动发现、路由与校验
- 🤖 **自动化索引** - `SKILLS.md` 由脚本生成，减少人工维护漂移
- ✅ **质量守门** - 本地可手动执行校验，PR 中自动检查一致性

## 📂 目录结构

```text
agent-skills/
├── SKILLS.md              # 技能索引
├── .github/workflows/     # CI 校验
├── core/                  # 核心技能
│   ├── ai/                # AI 辅助技能
│   ├── backend/           # 后端开发技能
│   ├── frontend/          # 前端开发技能
│   ├── *-review/          # 语言审查技能
│   └── ...                # 其他通用技能
├── scripts/               # 校验与索引生成脚本
└── skill-builder/         # 技能构建工具
```

## 🚀 快速开始

### 作为 Git Submodule 引入

```bash
# 添加为 submodule（示例路径，可按所用 AI 助手调整）
git submodule add <repo-url> .codex/skills

# 更新 submodule
git submodule update --remote
```

### 兼容多种 AI 助手

本库使用**相对路径**设计，可以作为 submodule 引入到任何 AI 助手的技能目录下：

| AI 助手 | 推荐引入路径 |
|---------|-------------|
| Antigravity | `.agent/skills/` |
| Claude Code | `.claude/skills/` |
| Codex | `.codex/skills/` |
| 其他 | 自定义路径 |

```bash
# 示例：引入到 Codex 项目目录
git submodule add <repo-url> .codex/skills
```

## 📋 技能清单

完整技能目录由 [SKILLS.md](SKILLS.md) 自动生成，请不要手动维护索引内容。

## 🧱 Frontmatter Schema

每个 `SKILL.md` 顶部都必须包含统一 frontmatter：

```yaml
---
slug: example-skill
name: 示例技能
description: 一句话描述这个技能
category: utility
role: specialist
triggers:
  - 触发词 1
inputs:
  - 输入类型 1
outputs:
  - 输出类型 1
related_skills:
  - another-skill
constraints:
  - 约束 1
  - 约束 2
---
```

字段说明：

- `slug`: skill 的稳定标识，使用 kebab-case。
- `category`: `workflow|backend|frontend|language|ai|utility` 之一。
- `role`: `entrypoint|workflow|specialist` 之一，用于明确职责边界。
- `triggers / inputs / outputs / related_skills / constraints`: 统一使用列表，便于索引和自动路由。

## 🛠 脚本

- `pwsh ./scripts/generate-skills-index.ps1`: 重新生成 `SKILLS.md`
- `pwsh ./scripts/validate-skills.ps1`: 校验 schema、章节、关联关系与索引一致性

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/new-skill`)
3. 使用 [skill-builder](skill-builder/SKILL.md) 创建新技能
4. 生成索引：`pwsh ./scripts/generate-skills-index.ps1`
5. 运行校验：`pwsh ./scripts/validate-skills.ps1`
6. 提交变更 (`git commit -m 'feat: add new skill'`)
7. 推送分支 (`git push origin feature/new-skill`)
8. 创建 Pull Request

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源。
