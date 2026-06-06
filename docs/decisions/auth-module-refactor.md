# 登录模块重构记录

## 目标

统一认证只负责 SCU 根登录和统一认证 session；子模块登录由子模块 Auth 自己负责，并显式声明依赖关系。

这样可以避免无依赖模块相互阻塞。例如微服务和教务系统没有依赖关系，统一认证成功后会并行预热；夜间教务系统校外网络不可用时，教务超时不会拖慢微服务。缴费平台依赖微服务时，则先完成微服务认证，再登录缴费平台。

## 分层

```text
ScuAuth
  只负责统一认证 token、id.scu.edu.cn session、过期刷新

SubsystemAuth
  子模块认证契约：moduleId / dependencies / ensureAuthenticated / invalidate

AuthCoordinator
  统一认证成功后后台预热子模块
  每个模块并发启动，只等待自己的依赖
  依赖失败只跳过下游

业务 API Service
  调用对应子模块 Auth 获取 client/token
```

## 当前子模块依赖

```text
zhjw    -> 无依赖，独立做教务 JWT SSO
wfw     -> 无依赖，直接使用 SCU 统一认证 session
fitness -> 无依赖，独立做体测 SSO relay
ccyl    -> 无依赖，通过 SCU OAuth code 换第二课堂 token
payapp  -> 依赖 wfw，先确保微服务认证，再做缴费平台 SSO relay
```

统一认证登录成功后，`AuthCoordinator` 会并发启动所有子模块认证任务。无依赖模块可立即执行：

```text
zhjw + wfw + fitness + ccyl
```

`payapp` 只等待 `wfw`，不会等待 `zhjw`、`fitness` 或 `ccyl`：

```text
payapp
```

后台预热失败不会阻塞登录页返回。用户进入具体功能时，对应 API Service 仍会通过 `ensureAuthenticated()` 或 `getClient()` 再兜底认证。

## 关键文件

- `lib/services/auth/scu_auth.dart`：根认证，不再预热任何子系统 SSO。
- `lib/services/auth/subsystem_auth.dart`：子模块认证契约。
- `lib/services/auth/auth_coordinator.dart`：按依赖分层调度子模块认证。
- `lib/services/auth/zhjw_auth.dart`：教务 SSO 从 `ScuAuth` 中拆出。
- `lib/services/auth/wfw_auth.dart`：微服务认证，不依赖教务。
- `lib/services/auth/sso_relay_auth.dart`：支持依赖声明的 SSO relay 基类。
- `lib/services/auth/payapp_auth.dart`：声明依赖 `WfwAuth`。
- `lib/providers/scu_auth_provider.dart`：统一认证成功后后台触发子模块预热。

## 新增子模块接入方式

1. 实现 `SubsystemAuth`，声明稳定的 `moduleId`。
2. 在 `dependencies` 中只放真实依赖，不要用调用顺序表达隐含依赖。
3. 在 `ensureAuthenticated()` 中完成自己的登录、SSO 或 token 换取。
4. 在 `invalidate()` 中清理本模块缓存的 client、token 或正在进行的登录 Future。
5. 在 `injector.dart` 注册模块，并加入 `AuthCoordinator` 的模块列表。

如果模块 A 依赖 B，声明 `dependencies: [bAuth]`。协调器会保证 B 成功后才执行 A；如果 B 失败，A 会被跳过，但其他无关模块仍继续。
