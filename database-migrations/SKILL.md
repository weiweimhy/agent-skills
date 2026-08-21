---
name: database-migrations
description: Design, review, or execute application database schema and data migrations with existing-tool fidelity, compatibility staging, lock-aware rollout, recoverability, and isolated verification. Use for schema, data backfill, or migration pipeline changes.
---

# Database Migration Engineering

## 使用范围

用于数据库 schema 变更、数据回填、迁移脚本和迁移流水线审查。先确认数据库类型与版本、迁移工具、当前 schema、数据规模、流量模式、部署顺序和备份/恢复能力；不得在不了解这些事实时选择 DDL 语法或假定事务行为。

## 工作方式

- 将迁移视为一次跨版本发布，而非单个 SQL 文件。先识别旧应用、旧 schema、新应用和新 schema 在发布窗口内如何并存，并采用适合的 expand–migrate–contract 或项目既有策略。
- 使用现有迁移工具的命名、顺序、校验和与执行模型。迁移内容保持确定、可审查且尽量小；避免把环境特定判断、临时凭据或不可控外部调用混入迁移。
- 评估 DDL 锁、索引创建、表重写、长事务和数据量对线上延迟的影响。大规模回填应分批、可观测、可暂停，并定义重复执行或中断后的恢复语义。
- 向后兼容阶段不要立即删除旧列、改写枚举含义或收紧仍被旧版本写入的约束。收缩操作须在所有读写方迁移完成、数据验证通过后独立进行。
- 回退优先考虑恢复到已知可用状态和数据完整性；并非所有变更都适合简单的 down migration。对不可逆操作说明备份、快照或补偿计划。
- 在与目标版本接近的隔离数据库上测试全新安装、升级、失败中断和必要的应用兼容性。生产执行前确认目标环境、备份状态、变更窗口和审批。

## 交付与边界

交付应包含变更目的、受影响对象、版本兼容策略、性能/锁风险、数据验证、恢复方案和实际测试结果。具体 ORM、数据库方言、云数据库操作和生产执行命令由项目技能与运维流程决定。
