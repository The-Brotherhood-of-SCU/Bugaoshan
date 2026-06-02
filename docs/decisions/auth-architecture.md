# 认证架构设计决策

## 概述

统一管理 SCU 统一认证、电费查询、体测查询、第二课堂四个后端服务的认证生命周期。核心目标：

1. 业务方一行调用，不碰认证细节
2. Session 过期自动重试（静默续期 / OCR 自动登录）
3. 刷新失败时全局提示（Snackbar + 前往登录）
4. 并发请求不会触发多次刷新

## 架构分层

```mermaid
graph TD
    subgraph Provider["Provider / Page"]
        P1["调用 service.fetchXxx()"]
        P2["管理 UI 状态（loading / loaded / error）"]
        P3["缓存数据到 SharedPreferences"]
    end

    subgraph Service["ScuApiService + Extensions"]
        S1["HTTP 请求 + HTML/JSON 解析"]
        S2["_checkSessionExpiry() 检测 302 / 空 body / 登录页"]
        S3["内部调 _authManager.scu.request()"]
        S4["通用 request() 供非标准调用方使用"]
    end

    subgraph Auth["ScuAuthService"]
        A1["login / fetchCaptcha / bindSession / logout"]
        A2["_accessToken / _cachedClient / _bindSessionFuture"]
        A3["SM2 加密 + SSO 预热 (JWT + CAS Apereo)"]
    end

    subgraph Session["AuthSession<T> 框架"]
        R1["request(fn): getClient → fn(client) → 过期重试"]
        R2["_synchronizedRefresh(): Completer 互斥，N 并发 = 1 次刷新"]
        R3["状态机：unknown → ready ↔ expired → error"]
        R4["onSessionExpired(): 刷新失败触发全局回调"]
    end

    subgraph Manager["AuthManager"]
        M1["持有 4 个 Session 实例"]
        M2["init(): scu.init() ‖ ccyl.init() 并行恢复"]
        M3["refreshAll(): scu.refresh() ‖ ccyl.refresh() 并行"]
        M4["addListener(): 代理到所有 Session"]
        M5["onSessionExpired(): 注册全局过期回调"]
    end

    subgraph Sessions["具体 Session"]
        SCU["ScuAuthSession<br/>token + 1h TTL + autoLogin"]
        PAY["PayAppAuthSession<br/>identical() 判断 + OAuth warrant"]
        FIT["FitnessAuthSession<br/>identical() 判断 + SSO redirect"]
        CCYL["CcylAuthSession<br/>独立 OAuth token"]
    end

    subgraph UI["全局错误处理"]
        U1["SessionExpiredListener"]
        U2["SnackBar + 前往登录"]
        U3["5 秒防抖"]
    end

    Provider --> Service
    Service --> Session
    Session --> Manager
    Manager --> Sessions
    Session -- "刷新失败" --> UI
    Session -->|"login/bindSession"| Auth

    SCU -. "依赖" .-> PAY
    SCU -. "依赖" .-> FIT
```

### 各层详细职责

| 层 | 关心什么 | 不关心什么 |
|---|---|---|
| **Provider / Page** | UI 状态流转（loading → loaded → error）、数据缓存、用户交互 | HTTP 细节、cookie 管理、token 过期、重试逻辑 |
| **ScuApiService** | HTTP 数据请求 + HTML/JSON 解析、过期信号检测（302/空body/登录页） | 登录态管理、UI 状态、缓存策略 |
| **ScuAuthService** | 认证：login / fetchCaptcha / bindSession / logout，SM2 加密、SSO 预热 | HTTP 业务请求、UI 状态、数据解析 |
| **AuthSession 框架** | token 过期判断、自动刷新、并发互斥、重试一次、触发过期回调 | 具体 HTTP 怎么发、数据怎么解析、UI 怎么显示 |
| **AuthManager** | 4 个 Session 的生命周期 + ScuApiService、并行初始化/刷新、全局回调注册 | 具体 token 格式、HTTP 细节、UI 状态 |
| **具体 Session** | 自己的认证方式（token/OAuth/SSO）、过期判断、refresh 策略 | 其他 Session 的存在、UI 状态、业务数据格式 |
| **SessionExpiredListener** | 全局 Snackbar 展示、防抖、导航到登录页 | 具体哪个 Session 过期、数据怎么恢复 |

## 4 个 Session 的依赖关系

```mermaid
graph TD
    SCU["ScuAuthSession<br/>根 · 独立 token · 1h TTL"]
    PAY["PayAppAuthSession<br/>OAuth warrant"]
    FIT["FitnessAuthSession<br/>SSO redirect"]
    CCYL["CcylAuthSession<br/>独立 OAuth token"]

    SCU -->|"getClient()"| PAY
    SCU -->|"getClient()"| FIT
    CCYL -.->|"仅首次登录拿 OAuth code"| SCU
```

## 关键调用链

**业务调用**（Provider）：
```dart
final data = await _authProvider.service.fetchSchemeScores();
```

**展开**：
1. `_authProvider.service` → `ScuApiService`
2. `fetchSchemeScores()` 是 `extension ScuApiGrades` 的方法
3. 内部调 `_authManager.scu.request((client) => ...)`
4. `request()` 是 `AuthSession` 模板方法

**`request()` 内部**：

```mermaid
graph TD
    A["getClient()"] --> B{"isExpired?"}
    B -->|"否"| C["bindSession() → cached CookieClient"]
    B -->|"是"| D["refresh()"]
    D --> D1["Stage 1: bindSession() 续期"]
    D1 --> D1OK{"成功?"}
    D1OK -->|"是"| C
    D1OK -->|"否"| D2["Stage 2: autoLogin()<br/>OCR 验证码 + saved credentials"]
    D2 --> D2OK{"成功?"}
    D2OK -->|"是"| C
    D2OK -->|"否"| ERR["throw ScuLoginException"]

    C --> E["fn(client) — 业务 HTTP"]
    E --> F{"ScuLoginException<br/>sessionExpired?"}
    F -->|"否"| G["返回结果"]
    F -->|"是"| H["_synchronizedRefresh()<br/>Completer 互斥"]
    H --> HOK{"刷新成功?"}
    HOK -->|"是"| I["新 client 重试一次"]
    HOK -->|"否"| J["state = error<br/>onSessionExpired() → Snackbar"]
```

## 状态机

```mermaid
stateDiagram-v2
    [*] --> unknown
    unknown --> ready : init()
    ready --> expired : TTL 过期
    expired --> ready : refresh() 成功
    expired --> error : refresh() 失败
    error --> Snackbar : onSessionExpired()
    ready --> unknown : logout()
    Snackbar --> ready : 登录成功
```

## 全局错误处理

```mermaid
graph TD
    A["AuthSession.request() 失败"] --> B["state = AuthState.error"]
    B --> C["onSessionExpired?.call()"]
    C --> D["SessionExpiredListener"]
    D --> D1["SnackBar<br/>正文: 登录会话已过期"]
    D1 --> D2["Action: 前往登录"]
    D2 --> D3["跳 ScuLoginPage"]
    D3 --> D4["登录成功 → 自动返回"]
    D --> D5["5 秒防抖 → 冷却期内不重复弹出"]
```

## 关键设计决策

### 1. 为什么用 `request()` 而非手动 try/catch

**问题**：原来每个 provider 都要写：
```dart
try {
  final client = await authProvider.service.bindSession();
  final resp = await client.get(...);
  if (resp.statusCode == 302) throw ScuLoginException(sessionExpired: true);
} on ScuLoginException catch (e) {
  if (e.sessionExpired) await SessionExpiryHandler.handle(authProvider);
  // setState error...
}
```

**方案**：`request(fn)` 封装了 getClient → 执行 → 过期检测 → 互斥刷新 → 重试的完整流程。Provider 只需：
```dart
final data = await _authProvider.service.fetchSchemeScores();
```

`_checkSessionExpiry()` 抛的 `ScuLoginException(sessionExpired: true)` 会被 `request()` 自动捕获并走刷新路径。

### 2. 为什么 `request()` 在 Service 层而非 Provider 层

**方案 A（旧）**：Provider 包 `request()`，传 client 给 service
```dart
final data = await authManager.scu.request(
  (client) => service.fetchSchemeScores(client: client),
);
```

**方案 B（当前）**：Service 内部包 `request()`，Provider 直接调用
```dart
final data = await service.fetchSchemeScores();
```

选择方案 B 的原因：
- Provider 层完全不碰认证细节，职责更清晰
- `fetchXxx` 方法签名更干净，不需要 `{CookieClient? client}` 参数
- `request()` 的位置集中在 service 层，改起来只动一处
- Provider 只依赖 `ScuAuthProvider`，不需要直接依赖 `AuthManager`

### 3. 为什么用 `extension` + `part` 拆分 Service

`ScuApiService`（数据层）只有 `bindAuthManager` + `request` + `_checkSessionExpiry` + 三个业务域的 fetch 方法。

用 `extension on ScuApiService` + `part of` 拆分：
- `part` 文件共享库作用域，可以访问 `_authManager`、`_checkSessionExpiry()` 等私有成员
- 每个业务域独立一个文件，便于定位和维护
- 静态配置（`requestHeaders`）放在 `ScuAuthService` 中，通过公开 getter 暴露给 extension

### 4. 为什么 Auth 和 API 拆成两个 Service

`ScuApiService` 原本同时承担认证（login/bindSession）和数据请求（fetchXxx）两种完全不同的职责——认证是"一次性的开关"，数据请求是"每次业务都要用"。混在一起导致：
- 类名误导（先后叫 `ScuAuthService` 和 `ScuApiService` 都不准确）
- 出现循环依赖的 `bindAuthManager(this)` 延迟绑定 hack
- `ScuApiService` 无法独立单测（必须 mock AuthManager）

拆分后：
- `ScuAuthService` —— 仅认证，无任何依赖，可独立单测
- `ScuApiService` —— 仅数据，依赖 AuthManager 用于 `request()` 转发
- 单向依赖链：`ScuApiService → AuthManager → ScuAuthSession → ScuAuthService`

`ScuApiService` 仍保留 `bindAuthManager(this)` 是因为它需要转发到 `_authManager.scu.request()`。这是 `request()` 模式的固有限制（数据层不知道如何拿已认证 client，必须由框架注入）。`ScuAuthService` 彻底摆脱了这个 hack。

```dart
// ScuApiService
late AuthManager _authManager;
void bindAuthManager(AuthManager mgr) => _authManager = mgr;

// AuthManager 构造函数
AuthManager(SharedPreferences prefs) {
  scu = ScuAuthSession(prefs);
  scu.service.bindAuthManager(this);  // 构造完成后绑定
  ...
}
```

### 5. 为什么用 `identical()` 判断 client 是否更换

SCU refresh 后 `bindSession()` 返回新的 `CookieClient` 实例（cookie 已重置）。PayApp/Fitness 需要知道是否要重新走 OAuth/SSO。

用 `identical(client, _cachedClient)`（引用相等）而非值比较：
- `CookieClient` 没有实现 `==`，引用相等是唯一可靠的判断方式
- 比 cookie 内容比较更高效
- 语义明确："是不是同一个 client 实例"

### 6. 为什么用 `Completer` 做并发互斥

100 个并发请求同时触发过期，不应该执行 100 次 `refresh()`。

```dart
Completer<bool>? _refreshCompleter;

Future<bool> _synchronizedRefresh() async {
  if (_refreshCompleter != null) return _refreshCompleter!.future;  // 排队等结果
  _refreshCompleter = Completer<bool>();
  try {
    final result = await refresh();
    _refreshCompleter!.complete(result);
    return result;
  } finally {
    _refreshCompleter = null;
  }
}
```

第 1 个请求创建 `Completer` 并执行 `refresh()`。其余 99 个 `await` 同一个 `Completer.future`，共享结果。`finally` 清空 `Completer`，下一个过期周期可以重新开始。

### 7. 为什么用 Snackbar 而非 Dialog

旧方案用 `SessionExpiryHandler` 弹 `AlertDialog`（阻塞式，用户必须点击才能继续）。

新方案用 `SnackBar`（非阻塞式）：
- 不打断用户当前操作
- 5 秒自动消失
- 带"前往登录"action 按钮
- 全局单例（`SessionExpiredListener`），5 秒防抖避免重复弹出

`SessionExpiryHandler` 已删除，所有 session 过期统一走 Snackbar。

### 8. 为什么 `_checkSessionExpiry()` 放在 Service 层

教务系统不会返回标准的 401 状态码。Session 过期的信号是：
- HTTP 302 重定向到登录页
- 响应 body 为空
- 响应 body 是 HTML 登录页面（`<` 开头且包含 `login`）

这些启发式检测是教务系统的特定行为，放在 Service 层最合理。检测到过期后抛 `ScuLoginException(sessionExpired: true)`，`request()` 的 catch 块自动接管。

### 9. 为什么 PayApp/Fitness 依赖 ScuAuthSession 而非独立

电费和体测系统没有独立的登录入口，它们通过 SCU 统一认证的 cookie 体系访问：
- PayApp 需要 SCU cookie + OAuth warrant 跳转
- Fitness 需要 SCU cookie + SSO 跳转

如果 SCU 的 token 过期，这两个系统也无法使用。所以它们的 `refresh()` 委托给 `_scuSession.refresh()`，不独立维护登录态。

### 10. 为什么 CCYL 独立于 SCU

第二课堂（CCYL）有自己的 OAuth token 体系，通过 SCU 的 CAS SSO 获取 OAuth code，然后用 code 换 token。一旦 token 获取成功，后续请求完全独立于 SCU。

所以 `CcylAuthSession` 有独立的 token 存储（`FlutterSecureStorage`）和独立的 `refresh()`（重新跑 OAuth 流程）。

## 文件结构

```mermaid
graph LR
    subgraph auth["lib/services/auth/"]
        A1["auth_session.dart<br/>抽象基类"]
        A2["auth_state.dart<br/>AuthState 枚举"]
        A3["auth_manager.dart<br/>4 个 Session + ScuApiService"]
        A4["scu_auth_session.dart<br/>SCU 主认证"]
        A5["payapp_auth_session.dart<br/>电费"]
        A6["fitness_auth_session.dart<br/>体测"]
        A7["ccyl_auth_session.dart<br/>二课"]
    end

    subgraph scu_auth["lib/services/scu_auth/"]
        SA1["scu_auth_service.dart<br/>认证: login / fetchCaptcha / bindSession / logout<br/>+ ScuLoginException / CaptchaResult"]
    end

    subgraph scu_api["lib/services/scu_api/"]
        S1["scu_api_service.dart<br/>主类: request() + bindAuthManager()"]
        S2["scu_api_schedule.dart<br/>extension: 课表/学期"]
        S3["scu_api_grades.dart<br/>extension: 成绩"]
        S4["scu_api_classroom.dart<br/>extension: 教室"]
        S6["cookie_client.dart<br/>按域隔离 cookie"]
    end

    subgraph widgets["lib/widgets/common/"]
        W1["session_expired_listener.dart<br/>全局 Snackbar"]
    end
```

## 依赖注入顺序

```mermaid
graph TD
    SP["SharedPreferences"] --> AM["AuthManager.init()"]
    AM --> SAP["ScuAuthProvider.init()"]
    SAP --> GP["GradesProvider"]
    SAP --> TPP["TrainProgramProvider"]
    SAP --> PCP["PlanCompletionProvider"]
    SAP --> CP["CcylProvider"]
    SAP -->|"暴露 isLoggedIn / service"| UI["UI 层"]
```

`AuthManager` 是认证层的根。`ScuAuthProvider` 是 UI 层的入口（暴露 `isLoggedIn`、`service` getter）。业务 Provider 只依赖 `ScuAuthProvider`，不直接依赖 `AuthManager`。
