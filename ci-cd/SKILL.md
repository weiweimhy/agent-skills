---
name: ci-cd
description: Design, review, or improve CI/CD pipelines with deterministic build and test gates, scoped credentials, artifacts, release traceability, environment controls, and rollback-aware delivery. Use for pipeline, workflow, or release automation work.
---

# CI/CD Engineering

## 使用范围

用于构建、测试、发布或部署流水线的设计与维护。先检查现有平台、触发条件、分支策略、权限模型、密钥来源、制品仓库和环境边界；不要把 GitHub Actions、GitLab CI 或某个云平台的写法当作通用实现。

## 工作方式

- 将快速反馈、质量验证、制品构建、发布和部署区分为可追溯阶段。每个阶段明确输入、输出、失败条件和谁可以重新执行或批准。
- 构建和测试使用锁定的依赖与明确运行时版本。缓存 key 应由锁文件、平台和工具版本决定，缓存只加速流程，不能绕过依赖解析、测试或安全检查。
- 制品必须可识别其源提交、版本和构建来源；同一已验证制品应在后续环境复用，而不是在每个环境重新从分支构建。
- 凭据按任务和环境最小授权，并通过平台受管密钥或短期身份提供。不要把凭据回显到日志、传入不可信 fork，或以宽泛 token 方便自动化。
- 部署前检查迁移、配置兼容性、健康验证和回退路径。高风险环境变更需要现有审批与变更窗口；流水线的成功状态不等于业务已成功。
- 处理失败时保留日志、制品和关联提交，以便定位。只在已知状态下重试；禁止把失败步骤改成忽略错误来获得“绿色”流水线。

## 交付与边界

交付应描述触发规则、阶段与门禁、缓存与制品、凭据范围、环境策略、验证与回退方案。平台专有 YAML、部署命令和审批规则应遵从仓库现有配置与组织政策。
