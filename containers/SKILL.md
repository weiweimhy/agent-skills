---
name: containers
description: Build, review, or troubleshoot Dockerfiles and Compose-based environments with reproducible builds, small runtime images, safe configuration, dependency readiness, and deployment-aware verification. Use for container or local service environments.
---

# Container Engineering

## 使用范围

用于 Dockerfile、Docker Compose 和容器化本地环境的设计、修改或故障排查。先确认目标是开发、测试、CI 还是生产，检查运行时版本、构建上下文、现有镜像策略和部署平台；同一套容器配置不应在未验证时假定适用于所有环境。

## 工作方式

- 使用锁文件和明确的基础镜像版本来获得可复现构建，并让构建缓存与源代码变化边界对应。构建上下文保持最小，`.dockerignore` 排除依赖目录、密钥、测试产物和无关文件。
- 将编译依赖与运行时依赖分开。多阶段构建、最小运行时镜像和非 root 用户应在兼容应用的前提下采用；不要为了镜像体积破坏调试、证书或必要系统库。
- 配置和凭据通过运行时环境、受控挂载或平台密钥注入；不得烘焙进镜像层、Compose 文件、构建参数历史或日志。开发默认值不能悄悄成为生产默认值。
- Compose 服务应明确端口、网络、volume、启动依赖和健康语义。`depends_on` 不等于依赖已可用；应用自身仍要处理依赖未就绪和短暂重连。
- 对外暴露端口、写入挂载路径和用户权限应最小化。数据卷、数据库和缓存默认隔离于本次测试，避免误连共享或生产资源。
- 变更后运行与目标相符的 build、启动或测试，并检查镜像、日志和健康结果。停止、清理、推送或部署会影响外部状态，必须在得到相应授权后执行。

## 交付与边界

说明目标环境、镜像与运行时版本、配置来源、端口/volume、依赖就绪策略和已执行验证。Kubernetes、云镜像仓库、编排平台和发布审批规则由项目级流程决定。
