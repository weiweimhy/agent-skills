---
name: api-design
description: Design or revise external API contracts, including resource paths, HTTP methods, request and response schemas, pagination, errors, and compatibility. Use when callers need a new or changed API agreement; also use for checking routes, DTOs and responses against an established contract.
---

# API 契约设计

为 API 调用方和实现方定义清楚、可兼容的外部契约。这里负责契约本身；配置语义、服务内部模块和数据访问架构归 `backend-patterns`。

## 设计时关注

- 先查看项目已有路径、字段命名、认证、响应和错误约定，并确认主要调用方。延续已有约定；确需改变时说明原因。
- 用资源和 HTTP 方法表达常见读写操作。若领域动作不能自然映射为资源操作，可采用清楚的动作端点，不为形式强行套 REST。
- 约定请求字段的类型、必填性、空值语义、边界和校验失败行为；响应说明数据形状、状态码及错误信息。
- 集合接口说明排序稳定性、默认及最大页大小和结束条件。引入分页或改动响应时，检查依赖完整集合或旧字段的调用方。
- 对不兼容变更说明影响范围、迁移路径，以及是否需要版本或过渡期。

检查已有实现时，从调用方使用的契约取一个正常请求和一个边界请求，核对实际路由、DTO、状态码、错误结构及缺失字段与空值的语义。记录影响的调用方和可复查的差异。

## 交付

按任务规模提供端点与方法、请求/响应示例、错误和边界规则，以及兼容性说明。只展开会影响调用方决策的选项，遵循项目既有命名风格；不要把 snake_case、固定响应信封或全局错误码当成未经确认的普遍要求。

## 相关技能

- [backend-patterns](../backend-patterns/SKILL.md)：设计会影响服务模块边界的实现方案。
- [doc-generator](../doc-generator/SKILL.md)：将已确定的契约整理为项目文档。

## 参考资料

- [Google API Design Guide](https://cloud.google.com/apis/design)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)
