---
name: nginx
description: Design, review, or safely change Nginx reverse-proxy, TLS, static-file, cache, WebSocket, and rate-limit configuration with request-flow clarity, validation, and rollback-aware operational boundaries. Use for Nginx config work.
---

# Nginx Engineering

## 使用范围

用于设计、审查或修改 Nginx 配置。开始前确认配置入口、include 关系、监听端口、上游服务、部署方式、证书来源和变更窗口；不要根据单一片段推断完整请求链路。

## 工作方式

- 先画清客户端、Nginx、上游服务和静态资源之间的请求流，再修改 `server`、`location`、重写或代理规则。location 匹配优先级和 URI 重写结果必须可解释。
- 反向代理显式处理 Host、真实客户端地址、协议和必要的转发头；只信任受控上游代理传来的客户端地址，避免把可伪造 header 作为安全判断依据。
- TLS、HTTP 跳转、HSTS、CORS、认证和安全响应头需与现有域名、应用行为和证书续期方式兼容。HSTS 或跨域策略等难回退变更，应先说明影响并取得确认。
- 为 WebSocket、SSE、大文件上传和下载配置适合的 HTTP 版本、超时、缓冲与大小限制；不要用全局超大超时掩盖上游故障。
- 缓存和限流规则必须明确缓存 key、绕过条件、隐私边界、状态码和用户影响。带认证或个性化内容默认不应被共享缓存。
- 修改后先运行配置语法测试，并在获得部署授权后才 reload。保留可回退版本，使用访问日志、错误日志或受控探针验证关键路径。

## 交付与边界

输出应说明请求流、涉及域名/路径、上游与超时、缓存或安全影响、验证和回退步骤。Kubernetes Ingress、CDN、证书自动化与平台部署命令应服从实际项目和运维流程。
