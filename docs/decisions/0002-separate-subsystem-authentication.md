# ADR-0002：拆分子系统认证并显式声明依赖

- 状态：已接受并实施
- 决策日期：2026-06-06
- 实施提交：`7ded388`
- 当前实现：[认证架构](../architecture/authentication.md)

## 背景

SCU 统一身份认证只提供根 token 和统一认证 session。教务、微服务、缴费平台、体测和第二课堂还需要各自的 SSO、cookie 或 OAuth token。

如果这些步骤都由 `ScuAuth` 按固定顺序执行，一个无关后端超时会拖慢整个登录链。例如夜间校外无法访问教务系统时，微服务仍应能够独立建立会话。另一方面，缴费平台确实依赖 WFW，不能简单把所有任务无条件并行。

## 决策

1. `ScuAuth` 只负责根登录、token/principal、`id.scu.edu.cn` session 和自动刷新。
2. 每个后端实现自己的 `SubsystemAuth`，提供稳定 `moduleId`、显式 `dependencies`、`ensureAuthenticated()` 和 `invalidate()`。
3. `AuthCoordinator` 为所有模块立即创建预热任务；每个任务只等待自己声明的依赖。
4. 模块失败只跳过依赖它的下游，不阻塞无关模块；依赖环视为配置错误。
5. 预热是尽力而为的优化。业务入口仍必须通过对应 Auth 按需认证。
6. PayApp 显式依赖 WFW；ZHJW、WFW、Fitness 和 CCYL 之间没有 L2 前置依赖。

当前依赖图：

```text
zhjw    -> none
wfw     -> none
fitness -> none
ccyl    -> none
payapp  -> wfw
```

这里的 `none` 只表示没有其他 L2 子系统依赖；所有模块仍可使用 L3 `ScuAuth`。

## 后果

正面影响：

- 登录页不等待慢子系统，独立后端可以并行恢复。
- 单点故障被限制在对应模块及其下游。
- 新增后端时，认证状态、缓存和失效逻辑有明确所有者。

代价与约束：

- 每个模块必须正确处理并发登录、根 client 变化、失效和登出竞态。
- `dependencies` 只能表达真实业务依赖，不能用来强行规定初始化顺序。
- 注册到 GetIt 只负责对象构造；加入 `AuthCoordinator` 才会参与统一预热和失效清理。
- API Service 必须保留按需认证兜底，不能假设后台预热一定成功。
