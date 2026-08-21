---
name: test-engineering
description: Design, implement, or improve software tests across Unity, Go, Python, Node.js, React, and Vue with behavior-focused coverage, isolated dependencies, deterministic async handling, and meaningful verification. Use for testing strategy or test failures.
---

# Test Engineering

## 使用范围

用于制定测试策略、补充测试、处理 flaky test 或评估测试缺口。先识别项目已有的测试框架、真实执行命令、分层约定和可用测试环境；测试应融入现有工具链，不应仅为追求覆盖率而另起体系。

## 工作方式

- 从用户可观察的行为、关键业务规则和已发生的缺陷出发，选择单元、集成或端到端测试层级。把纯逻辑留在快速单元测试，把跨进程、数据库、网络或真实渲染验证留给隔离的集成测试。
- 每个测试独立创建和清理自己的数据、时钟、随机源、文件、端口与环境变量。不要依赖执行顺序、共享全局状态、真实时间延迟或开发机已有服务。
- Mock 边界应位于网络、文件系统、时间、第三方服务或昂贵基础设施处；不要为了让测试容易通过而 mock 掉正在验证的业务规则。
- 异步测试必须等待明确完成条件、正确传播错误并设置合理超时。并发测试还应覆盖取消、重试、资源释放与竞争时的可预期结果。
- 失败信息应说明被测行为、输入和实际结果。新增回归测试要先能在修复前失败，再在修复后通过；不要只断言内部调用次数或实现细节。
- 运行与本次修改相关的实际测试命令，并区分已执行的测试与由于环境、权限或依赖未能执行的测试。需要外部服务时先隔离数据和凭据，并取得相应授权。

## 交付与边界

说明测试层级、覆盖的行为和边界、隔离策略、实际执行命令及未覆盖的风险。各语言的断言风格、Unity Test Framework、Playwright/Vitest 等具体工具以项目现有选择为准。
