# 认证架构设计决策

## 概述

三层架构 + 响应式通知链，统一管理 SCU 统一认证、教务系统、微服务、缴费平台、体测、第二课堂六个后端服务的认证与数据访问。

核心原则：
1. **三层分离**：业务层 (L1) → 子系统 Auth (L2) → ScuAuth (L3)
2. **L1 内部分工**：Provider（有状态，管理 UI）+ API Service（无状态，HTTP 工具）
3. **响应式通知链**：L3 状态变化 → L2 监听并转发 → Provider 监听并自动获取数据
4. **异常冒泡**：`UnauthenticatedException` 从 L3 穿透到 Provider
5. **并发安全**：`_synchronizedRefresh` 确保 N 并发 = 1 次刷新

## 三层架构 + 响应式链

```mermaid
graph TD
    subgraph L1["第1层 · 业务层"]
        direction TB
        subgraph Providers["Provider（有状态）"]
            UIP["UserInfoProvider<br/>自动获取用户信息+标签"]
            GP["GradesProvider<br/>成绩查询"]
            TPP["TrainProgramProvider<br/>培养方案"]
            PCP["PlanCompletionProvider<br/>计划完成度"]
            BQP["BalanceQueryProvider<br/>电费/空调"]
            CP["CcylProvider<br/>第二课堂"]
            SAP["ScuAuthProvider<br/>认证控制器"]
        end
        subgraph API["API Service（无状态工具）"]
            ZHJW["ZhjwApiService"]
            WFW["WfwApiService"]
            PAYAPP["PayAppApiService"]
            CCYL["CcylApiService"]
        end
    end

    subgraph L2["第2层 · 子系统认证（有状态 · ChangeNotifier）"]
        ZA["ZhjwAuth"]
        WA["WfwAuth"]
        PA["PayAppAuth"]
        FA["FitnessAuth"]
        CA["CcylAuth"]
    end

    subgraph L3["第3层 · 统一认证（有状态）"]
        SCU["ScuAuth<br/>login / bindSession / token<br/>SSO 预热 / 自动续期 / 并发互斥"]
    end

    %% 响应式通知链（粗线）：L3 → L2 → Provider
    SCU ==>|"notifyListeners"| WA
    SCU ==>|"notifyListeners"| ZA
    SCU ==>|"notifyListeners"| PA
    SCU ==>|"notifyListeners"| FA
    SCU ==>|"notifyListeners"| CA
    WA ==>|"notifyListeners"| UIP
    CA ==>|"notifyListeners"| CP

    %% Provider 调用 API Service（同层，无状态工具）
    UIP -->|"fetchLabels()"| WFW
    UIP -->|"fetchUserProfile()"| WFW
    GP -->|"fetchSchemeScores()"| ZHJW
    TPP -->|"searchPrograms()"| ZHJW
    PCP -->|"fetchPlanCompletion()"| ZHJW
    BQP -->|"queryRoomInfo()"| PAYAPP
    CP -->|"searchActivities()"| CCYL

    %% API Service 调用 Auth (L1 → L2)
    WFW -->|"getClient()"| WA
    ZHJW -->|"getClient()"| ZA
    PAYAPP -->|"getClient()"| PA
    CCYL -->|"getService()"| CA

    %% Auth 调用 ScuAuth (L2 → L3)
    WA -->|"getClient()"| SCU
    ZA -->|"getClient()"| SCU
    PA -->|"getClient()"| SCU
    CA -.->|"OAuth code"| SCU

    %% ScuAuthProvider 直接操作 ScuAuth（认证控制器）
    SAP -->|"login/logout"| SCU
```

### 三层职责

| 层 | 组件 | 有状态? | 职责 |
|---|---|---|---|
| **L1 业务层** | Provider | ✅ 有状态 | UI 状态管理（loading/error/data），监听 L2 自动获取数据 |
| | API Service | ❌ 无状态 | HTTP 请求 + 解析 + 过期检测 + 重试，纯工具 |
| **L2 子系统认证** | ZhjwAuth / WfwAuth / ... | ✅ 有状态 | 子系统认证 + 监听 L3 转发通知给 L1 |
| **L3 统一认证** | ScuAuth | ✅ 有状态 | 登录 / token / SSO / 自动续期 / 并发互斥 |

### 关键设计：响应式通知链

```mermaid
sequenceDiagram
    participant User as 用户
    participant SAP as ScuAuthProvider
    participant SCU as ScuAuth (L3)
    participant WA as WfwAuth (L2)
    participant UIP as UserInfoProvider
    participant WFW as WfwApiService (L1)

    User->>SAP: login()
    SAP->>SCU: login()
    SCU->>SCU: state = ready
    SCU->>WA: notifyListeners()
    WA->>UIP: notifyListeners()
    UIP->>UIP: _onAuthChanged() → _fetchAll()
    UIP->>WFW: fetchUserProfile()
    UIP->>WFW: fetchProfileLabels()
    WFW-->>UIP: 数据
    UIP->>UIP: notifyListeners()
```

### 依赖规则

```
✅ Provider 持有 API Service — 同层，无状态工具
✅ Provider 监听 Auth (L2) — 感知认证变化，自动获取数据
✅ API Service 调用 Auth (L2).getClient() — 获取已认证 client
✅ Auth (L2) 监听 ScuAuth (L3) — 转发通知
✅ ScuAuthProvider 直接持有 ScuAuth — 认证控制器，管理登录/登出
❌ Provider 直接持有 ScuAuth (L3) — 除 ScuAuthProvider
❌ Auth (L2) 持有 API Service — 方向反了
❌ API Service 持有 Provider — 方向反了
```

## 子系统认证依赖关系

```mermaid
graph TD
    SCU["ScuAuth<br/>根 · 独立 token · 1h TTL"]

    ZHJW["ZhjwAuth<br/>zhjw.scu.edu.cn<br/>ChangeNotifier"]
    WFW["WfwAuth<br/>wfw.scu.edu.cn<br/>ChangeNotifier"]
    PAY["PayAppAuth<br/>payapp.scu.edu.cn<br/>ChangeNotifier"]
    FIT["FitnessAuth<br/>pead.scu.edu.cn<br/>ChangeNotifier"]
    CCYL["CcylAuth<br/>dekt.scu.edu.cn<br/>ChangeNotifier"]

    SCU -->|"getClient() 共享 CookieClient"| ZHJW
    SCU -->|"getClient() CookieClient"| WFW
    SCU -->|"getClient() + OAuth warrant"| PAY
    SCU -->|"getClient() + SSO redirect"| FIT
    CCYL -.->|"OAuth code via CcylOAuthService"| SCU
```

- **ZhjwAuth / WfwAuth**：共享 ScuAuth 的 CookieClient（SSO session）
- **PayAppAuth / FitnessAuth**：继承 `SsoRelayAuth` 基类，做 SSO 跳转
- **CcylAuth**：独立 token，通过 `CcylOAuthService(ScuAuth)` 桥接 SCU

## 异常体系

```dart
sealed class ScuException implements Exception {
  final String message;
}

class UnauthenticatedException extends ScuException  // 认证失败
class ServiceException extends ScuException           // 业务错误
class RateLimitedException extends ServiceException   // 频率限制
class ScuLoginException extends ScuException          // 登录过程错误
```

异常冒泡路径：
```
ScuAuth.getClient() 抛 UnauthenticatedException
  → Auth (L2) 穿透
    → API Service (L1) _request() catch → 重试一次
      → 仍失败 → Provider catch → UI 显示错误
```

## 关键调用链

### 自动获取（响应式）

```mermaid
graph TD
    A["ScuAuth.login()"] --> B["state = ready"]
    B --> C["WfwAuth.notifyListeners()"]
    C --> D["UserInfoProvider._onAuthChanged()"]
    D --> E["_fetchAll()"]
    E --> F["fetchUserProfile() + fetchProfileLabels()"]
    F --> G["notifyListeners() → UI 重建"]
```

### 用户触发

```mermaid
graph TD
    A["用户打开成绩页"] --> B["GradesProvider.refreshSchemeScores()"]
    B --> C["ZhjwApiService.fetchSchemeScores()"]
    C --> D["retryOnUnauthenticated(ZhjwAuth.getClient, fn)"]
    D --> E["ZhjwAuth.getClient() → ScuAuth.getClient()"]
    E --> F{"过期?"}
    F -->|"否"| G["返回 CookieClient"]
    F -->|"是"| H["_synchronizedRefresh()"]
    H --> I["重试一次"]
```

## `_synchronizedRefresh` 并发互斥

```dart
Completer<bool>? _refreshCompleter;

Future<bool> _synchronizedRefresh() async {
  if (_refreshCompleter != null) return _refreshCompleter!.future;  // 排队
  _refreshCompleter = Completer<bool>();
  try {
    final result = await _doRefresh();
    _refreshCompleter!.complete(result);
    return result;
  } finally {
    _refreshCompleter = null;
  }
}
```

N 个并发请求同时触发过期 → 只有第 1 个执行 `_doRefresh()`，其余 99 个 `await` 同一个 `Completer.future`。

## 状态机

```mermaid
stateDiagram-v2
    [*] --> unknown
    unknown --> ready : init() 恢复 token
    ready --> expired : TTL 过期（1小时）
    expired --> ready : refresh() 成功
    expired --> error : refresh() 失败
    error --> Snackbar : onSessionExpired()
    ready --> unknown : logout()
    Snackbar --> ready : 登录成功
```

## 全局错误处理

```mermaid
graph TD
    A["ScuAuth._synchronizedRefresh() 失败"] --> B["state = AuthState.error"]
    B --> C["onSessionExpired?.call()"]
    C --> D["SessionExpiredListener"]
    D --> D1["SnackBar + 前往登录"]
    D --> D2["5 秒防抖"]
```

## 文件结构

```
lib/providers/                     # 第1层 · Provider（有状态）
├── scu_auth_provider.dart         # 认证控制器（直接持有 ScuAuth）
├── user_info_provider.dart        # 监听 WfwAuth，自动获取用户信息+标签
├── grades_provider.dart           # 持有 ZhjwApiService
├── train_program_provider.dart    # 持有 ZhjwApiService
├── plan_completion_provider.dart  # 持有 ZhjwApiService
├── balance_query_provider.dart    # 持有 PayAppApiService
├── ccyl_provider.dart             # 监听 CcylAuth，持有 CcylApiService
├── course_provider.dart           # 纯本地数据
├── app_config_provider.dart       # 纯本地配置
└── app_info_provider.dart         # 版本信息

lib/services/api/                  # 第1层 · API Service（无状态）
├── api_request.dart               # retryOnUnauthenticated()
├── zhjw_api_service.dart          # 教务数据 API
├── wfw_api_service.dart           # 微服务数据 API
├── payapp_api_service.dart        # 缴费平台数据 API
├── balance_query_service.dart     # 电费纯数据 API
└── ccyl_api_service.dart          # 第二课堂数据 API

lib/services/auth/                 # 第2+3层 · 认证（有状态）
├── auth_state.dart                # AuthState 枚举
├── cookie_client.dart             # 按域隔离 cookie
├── scu_exceptions.dart            # 异常体系
├── scu_auth.dart                  # 第3层 · 统一认证（ChangeNotifier）
├── sso_relay_auth.dart            # SSO 中继基类（ChangeNotifier）
├── zhjw_auth.dart                 # 第2层 · 教务 SSO（ChangeNotifier）
├── wfw_auth.dart                  # 第2层 · 微服务（ChangeNotifier）
├── payapp_auth.dart               # 第2层 · 缴费平台（ChangeNotifier）
├── fitness_auth.dart              # 第2层 · 体测（ChangeNotifier）
├── ccyl_auth.dart                 # 第2层 · 第二课堂（ChangeNotifier）
└── ccyl_oauth_service.dart        # SCU→CCYL OAuth 桥接

lib/services/ccyl/
└── ccyl_service.dart              # 第二课堂纯数据 API（无状态静态方法）

lib/utils/
└── secure_storage.dart            # FlutterSecureStorage 单例
```

## 依赖注入顺序

```mermaid
graph TD
    SP["SharedPreferences"] --> SCU["ScuAuth.init()"]
    SCU --> ZA["ZhjwAuth"]
    SCU --> WA["WfwAuth"]
    SCU --> PA["PayAppAuth"]
    SCU --> FA["FitnessAuth"]
    SCU --> CA["CcylAuth.init()"]
    ZA --> ZHJW["ZhjwApiService"]
    WA --> WFW["WfwApiService"]
    PA --> PAYAPP["PayAppApiService"]
    CA --> CCYL["CcylApiService"]
    SCU --> SAP["ScuAuthProvider"]
    CA --> SAP
    SCU --> UIP["UserInfoProvider"]
    WA --> UIP
    WFW --> UIP
    ZHJW --> GP["GradesProvider"]
    ZHJW --> TPP["TrainProgramProvider"]
    ZHJW --> PCP["PlanCompletionProvider"]
    CCYL --> CP["CcylProvider"]
    PAYAPP --> BQP["BalanceQueryProvider"]
```

## 关键设计决策

### 1. 为什么 L2 Auth 是 ChangeNotifier

ScuAuth (L3) 状态变化时，Provider 需要自动感知。L2 Auth 作为中间层：
- 监听 ScuAuth 的 `notifyListeners`
- 转发给自己的 `notifyListeners`
- Provider 通过 `addListener` 感知变化

这形成了响应式通知链：`ScuAuth → Auth(L2) → Provider`。

### 2. 为什么 Provider 和 API Service 在同一层

Provider（有状态）和 API Service（无状态）都属于"业务层"（L1），共同服务于 UI：
- **Provider** 管理 UI 状态（loading/error/data），监听 L2 Auth 自动获取数据
- **API Service** 是 Provider 使用的无状态 HTTP 工具

两者是协作关系，不是上下层关系。Provider 持有 API Service 就像持有工具一样。

### 3. 为什么 API Service 无状态

API Service 只是 HTTP 工具（发请求 + 解析 + 重试），不持有认证状态。这使得：
- 同一个 API Service 可以被多个 Provider 共享
- API Service 不参与通知链，职责清晰
- 测试时只需 mock Auth 层

### 4. 为什么 ScuAuthProvider 直接持有 ScuAuth

ScuAuthProvider 是"认证控制器"，负责：
- login / logout / autoLogin / captcha / credential 管理
- 这些操作需要直接调用 ScuAuth 方法

它不是普通的业务 Provider，而是认证层的 UI 入口。

### 5. 为什么用 `_synchronizedRefresh` 而非简单重试

100 个并发请求同时触发过期，不应执行 100 次 refresh。`Completer` 互斥确保 N 并发 = 1 次刷新。

### 6. 为什么 PayAppAuth/FitnessAuth 继承 SsoRelayAuth

两个类逻辑完全相同：获取 SCU CookieClient → SSO 跳转 → 缓存。唯一差异是 URL。基类消除重复。

### 7. 为什么 CCYL 独立于 SCU

CCYL 有自己的 OAuth token 体系。通过 SCU 的 CAS SSO 获取 OAuth code，然后用 code 换 token。后续请求完全独立。
