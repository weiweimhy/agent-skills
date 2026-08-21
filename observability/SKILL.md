---
name: observability
description: Design, implement, or review application observability with actionable logs, metrics, traces, health signals, privacy-aware telemetry, and incident-focused verification. Use when instrumenting services or diagnosing production behavior.
---

# Observability Engineering

## 使用范围

用于设计或改进日志、指标、链路追踪、健康检查和故障诊断。先确认系统目标、关键用户路径、现有遥测后端、采样策略和数据保留限制；不要把某个监控供应商或仪表库当作通用前提。

## 工作方式

- 从可行动的问题出发：服务是否可用、某条业务路径是否退化、失败发生在哪一层、资源是否接近瓶颈。先定义这些信号，再决定日志、指标或 trace 哪一种最合适。
- 为一次请求或任务建立可传播的关联标识，并在服务边界、队列消息和后台任务中保留上下文。字段名和状态分类要稳定，便于跨服务检索与聚合。
- 结构化日志应描述事件、结果和足以定位的上下文，而非重复记录控制流。不得记录密码、令牌、完整个人数据或未经审查的请求体；必要的标识应脱敏或最小化。
- 指标命名反映业务或系统语义，标签保持低基数。用户 ID、订单号、完整 URL、异常文本等高基数字段不应成为 metric label，应放入受控日志或 trace。
- trace 记录跨边界耗时、错误和采样语义；对高吞吐路径使用可解释的采样与错误保留策略，避免为了可观测性本身造成显著成本或性能退化。
- 健康检查区分进程存活、服务就绪和关键依赖可用性。告警应能指向用户影响和处置路径，而不只是单个瞬时阈值。
- 通过实际查询、测试流量或受控故障验证新信号能回答原问题。生产排障操作要先确认环境、查询范围和访问权限。

## 交付与边界

输出应列出观测目标、事件/指标/trace 契约、隐私处理、采样或保留影响、仪表位置和验证结果。告警阈值、供应商配置和运行手册以项目或平台实际约定为准。
