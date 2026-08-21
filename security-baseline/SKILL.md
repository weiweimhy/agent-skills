---
name: security-baseline
description: Review or harden application code, configuration, and delivery workflows against common security failures with explicit trust boundaries, secret protection, safe input handling, dependency awareness, and evidence-based findings. Use for security-focused work.
---

# Application Security Baseline

## 使用范围

用于安全设计、代码审查、配置加固或处理安全缺陷。先明确资产、数据敏感度、攻击面、信任边界和部署环境；本技能提供基线检查，不替代专业渗透测试、合规审计或项目特定安全要求。

## 工作方式

- 将外部请求、文件、消息队列、环境变量、第三方回调和内部服务边界视为不可信输入，按数据类型验证、限制大小与结构，并在进入危险操作前进行规范化。
- 鉴权与授权应与具体资源和动作绑定。不要把“已登录”当作有权限，也不要依赖客户端传来的角色、租户、路径或身份字段来决定服务器端访问。
- 使用参数化查询、受控文件路径、严格的 URL/主机 allowlist 和安全 API 来避免注入、路径遍历、命令执行和 SSRF。需要代理或下载外部资源时明确网络边界与超时。
- 密钥、令牌和私有配置只从受管渠道读取，日志、错误、测试 fixture、镜像和提交记录中不得出现真实值。轮换或撤销暴露凭据属于外部操作，应先取得授权。
- 依赖、锁文件、构建脚本和供应链工具的变更应检查来源、维护状态、许可和已知风险；升级需结合兼容性测试，而不是仅为消除扫描告警。
- Web 与 API 输出使用正确的编码、CORS、cookie、会话、速率限制和错误信息策略，具体值以项目的客户端与部署模型为准。不要把内部堆栈或安全判断细节返回给调用方。
- 输出发现时按可利用性、影响和证据描述，区分已证实问题、风险假设和需要进一步验证的点。不得对未授权的系统执行攻击性扫描或利用操作。

## 交付与边界

说明审查范围、信任边界、发现的证据与优先级、建议修复及验证方式。认证提供商、加密算法、合规控制和基础设施策略须遵从项目或组织的正式规范。
