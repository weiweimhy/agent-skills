---
name: redis
description: Design, implement, or review Redis use for caching, sessions, queues, locks, and rate limits with key contracts, TTL behavior, atomicity, failure handling, and production-safe diagnostics. Use for Redis data or integration work.
---

# Redis Engineering

## 使用范围

用于设计、实现、审查或排查 Redis 集成。先明确 Redis 在系统中是缓存、会话、队列、限流器还是协调组件，并确认客户端、部署模式、持久化和高可用方案；不同用途不能共用含糊的可靠性假设。

## 工作方式

- 为 key 设计稳定的命名空间、实体标识、版本和数据编码，并记录读写方。不要把用户输入直接拼入无边界 key，也不要让不同业务复用相同 key 语义。
- 缓存必须明确权威数据源、失效方式、TTL、穿透/击穿/雪崩风险及 Redis 不可用时的退化策略。缓存未命中与缓存错误不能被误当成相同事件。
- 多命令更新默认不是原子操作。涉及计数、去重、库存、限流或状态迁移时，选择合适的数据结构、事务、Lua 脚本或原子命令，并说明并发语义。
- 锁必须有唯一持有者标识、合理过期时间和安全释放条件；不得用无过期的简单 key 锁替代业务幂等性。需要跨系统一致性时先评估是否应由数据库或队列承担。
- 排查生产问题时避免广泛扫描和阻塞式命令。优先使用受限采样、指标和慢日志，并先确认目标环境与读写权限。
- 为序列化、TTL 过期、并发竞争、客户端超时和 Redis 不可用建立测试或可复现验证；测试数据不得指向共享生产实例。

## 交付与边界

交付应包含 key 契约、数据生命周期、并发保证、失败行为和验证结果。Redis Cluster、Sentinel、云厂商参数、具体队列库与监控阈值属于部署或项目技能，不在此处假定。
