---
name: ci-cd
description: Design, review, or improve CI/CD pipelines with deterministic build and test gates, scoped credentials, artifacts, release traceability, environment controls, and rollback-aware delivery. Use for pipeline, workflow, or release automation work.
---

# CI/CD Engineering

## 使用范围

用于构建、测试、发布或部署流水线的设计与维护。先检查现有平台、触发条件、分支策略、权限模型、密钥来源、制品仓库和环境边界；遵循仓库实际配置，不把某个平台的写法当作通用实现。

## 工作方式

- 将反馈、质量验证、制品构建、发布和部署设计为可追溯阶段，说明输入、输出、失败条件及重跑或批准权限。
- 构建和测试使用锁定依赖及明确的运行时版本。缓存只加速流程，不绕过依赖解析、测试或安全检查。
- 制品关联源提交、版本和构建来源；后续环境复用已验证制品。
- 凭据按任务和环境最小授权，使用平台受管密钥或短期身份；避免回显凭据或将其传给不可信 fork。
- 部署前检查迁移、配置兼容性、健康验证和回退路径。流水线通过不等于业务已成功。
- 诊断失败时保留首次失败的日志、制品和关联提交，区分代码或测试回归、流水线配置、运行器/基础设施、外部依赖及间歇性故障。依据仓库所有权和实际证据指定负责方与下一步；无法归因时说明未知，不猜测责任团队。
- 仅在有瞬态故障证据时重跑，并记录原因和原始失败。不要用忽略错误、无期限禁用门禁或隐藏红灯来恢复绿色状态。

## 交付与边界

交付应说明触发规则、阶段与门禁、缓存和制品、凭据范围、环境策略、失败归属、验证与回退方案。平台专有 YAML、命令及审批策略遵从仓库现有配置和组织政策。
