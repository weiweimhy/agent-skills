---
name: backend-patterns
description: Design or refactor backend structure and runtime behavior, including module boundaries, service and repository layers, transactions, caching, retries, observability, and security controls. Use for implementation architecture across backend stacks; use this skill for runtime configuration validation and api-design for external contracts.
---

# 后端架构模式

用于后端代码组织、服务边界和运行时机制的实现设计。先查看现有目录、依赖、框架和数据访问方式，再提出与项目规模匹配的改动。

## 工作重点

- 明确模块职责和依赖方向，使领域逻辑不依赖具体数据库或传输框架；重构时沿用项目已有的模块边界和命名。
- 数据访问关注查询次数、需要的字段、索引和事务范围。批量读取常能避免 N+1，但应以真实访问路径为依据；避免无依据的性能规则。
- 设计缓存时说明缓存键、TTL、失效与并发更新行为，以及缓存不可用时的退化路径。
- 设计重试时限定可重试错误、次数、退避、抖动和取消条件，避免重复执行非幂等操作。
- 为异步任务、队列和跨模块调用明确错误传播、超时、幂等性及状态所有权。
- 安全与观测应落到实际边界：鉴权与权限检查、敏感数据处理、结构化日志和可关联的请求标识。

## 配置生效验证

沿启动入口读取默认值、环境覆盖顺序和实际生效值。用项目已有解析器或 schema 验证格式，再核对跨字段约束。
例如，若重试预算要求单次超时小于总时限，用一份可解析但违反该约束的配置验证启动或运行行为。
比较环境差异时引用配置键、预期约束和可复现的后果，隐去密钥值。

## 交付

针对涉及的边界描述推荐结构、关键数据流和主要取舍。避免为尚未出现的规模设计微服务、缓存、重试层或抽象；只在能解决当前约束时引入。API 调用方可见的路径、
字段、状态码和兼容策略归 [api-design](../api-design/SKILL.md)。

## 相关技能

- [architecture-consultant](../architecture-consultant/SKILL.md)：需要比较系统级方案或记录架构决策时使用。
- [api-design](../api-design/SKILL.md)：定义对外 API 契约。
