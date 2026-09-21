# ArkWeb 原生能力桥接

Flutter Web 通过一层适配调用鸿蒙容器提供的数据库和 HTTP 能力。Flutter 与 `ohos/` 的桥接代码均已接入。数据库使用鸿蒙关系型数据库，网络使用 RCP；当前实现面向兼容版本 API 20 及以上的项目配置。

## 接入位置

- [`main.dart`](../../lib/main.dart) 在依赖注入之前调用 `initializeArkWebSupport()`，检查桥接协议并注册 sqflite 的 Web 平台处理器。
- ArkWeb 适配层同时接管 `system_theme` 的取色调用，返回 null，让插件保留启动时预设的蓝色。当前未桥接鸿蒙系统强调色；这样可避开 `system_theme_web` 的 CSS 颜色解析异常，并覆盖启动、主题设置和预览中的取色调用。
- [`NativeViewport.ets`](../../ohos/entry/src/main/ets/bridge/NativeViewport.ets) 传递窗口安全区；Flutter 根部的 [`ArkWebSafeArea`](../../lib/widgets/common/arkweb_safe_area.dart) 将其合并到 `MediaQuery`，用于沉浸式布局。
- [`DatabaseService`](../../lib/services/database_service.dart) 在 Web 下只传数据库逻辑文件名 `bugaoshan.db`。原有 SQL、表结构升级、事务、批处理和缓存仍由现有 Dart 代码管理。
- [`platform_http_client.dart`](../../lib/services/platform_http_client.dart) 在发现原生桥接时创建 `ArkWebHttpClient`。CookieClient 的初次创建和重建、登录验证码、忘记密码及第二课堂直接请求使用这个入口。
- Cookie 隔离、SSO 手动重定向及登录状态继续由现有认证层管理。鸿蒙端只承担请求传输。
- [`NativeBridge.ets`](../../ohos/entry/src/main/ets/bridge/NativeBridge.ets) 实现协议握手与调用分发；[`Index.ets`](../../ohos/entry/src/main/ets/pages/Index.ets) 在页面脚本运行前注册代理，并限制调用来源。每次握手会清理上一轮页面的资源，页面关闭时也会取消 HTTP 请求、回滚并关闭数据库。

非 Web 平台不注册此桥接，HTTP 工厂返回原有 `http.Client()`；调用方显式注入的客户端继续生效。普通浏览器没有这座桥，也没有通过本次改动获得 Web 数据库实现。

## JavaScript 接口与消息格式

容器必须在 Flutter 启动之前向受信任的本地应用页面注入以下接口：

```ts
window.bugaoshanNative = {
  invoke(requestJson: string): Promise<string>
};
```

这是接口签名；实际对象由宿主提供。当前通过 Web 组件的 `javaScriptProxy` 注册 `NativeBridge.invoke`，方法返回 `Promise<string>`。此方法放在 `methodList` 中；`asyncMethodList` 不返回调用结果，不能用于本接口。代理必须在 Flutter 初始化之前注册。

每次调用发送一个 JSON 字符串：

```json
{"version":1,"method":"bridge.info","arguments":null}
```

Promise 返回的值也必须是 JSON 字符串。成功：

```json
{"ok":true,"result":{"version":1,"capabilities":["database","http","viewport"]}}
```

失败：

```json
{"ok":false,"error":{"code":"sqlite_error","message":"operation failed","details":null}}
```

`bridge.info` 是启动握手，必须返回协议版本 `1` 和 `database`、`http` 两项能力；Flutter 最多等待 10 秒。原生能力没有实现时不能宣告具备该能力。未知版本、方法和预期的操作失败均返回错误信封，不返回成功占位值。

`viewport` 是可选能力，新容器提供安全区查询、变化通知和系统栏颜色设置；没有此能力的旧容器沿用原有 Flutter 布局。

二进制值递归编码为只有一个键的对象 `{"$bytes":"BASE64"}`，空字节为 `{"$bytes":""}`。这个规则同时适用于 HTTP 正文、SQL BLOB 参数和查询结果。其余类型使用 JSON 的字符串、数值、布尔值、数组、对象和 null；对象键必须是字符串。不要对二进制正文做 UTF-8 解码再编码。

## 数据库：`database.invoke`

Flutter 复用 sqflite 的标准 `com.tekartik.sqflite` MethodChannel，将调用原样包进 JSON：

```json
{
  "version":1,
  "method":"database.invoke",
  "arguments":{
    "method":"openDatabase",
    "arguments":{"path":"bugaoshan.db","singleInstance":true}
  }
}
```

当前 sqflite 在 Web 下保留逻辑文件名；宿主负责把它映射到应用沙箱内的数据库，不将页面传入的路径直接作为任意系统路径使用。数据库版本由 Dart 通过 `PRAGMA user_version` 读写；宿主不要另行触发表结构创建或升级。

[`NativeDatabase.ets`](../../ohos/entry/src/main/ets/bridge/NativeDatabase.ets) 将 `bugaoshan.db` 和 `/databases/bugaoshan.db` 映射到 `context.databaseDir/rdb/arkweb/bugaoshan.db`，其他数据库路径会被拒绝。禁止损坏后自动重建空库。所有数据库调用顺序执行，失败后队列仍允许后续回滚和关闭操作执行。

鸿蒙 `RdbStore.execute` 不接受事务控制 SQL。实现将 BEGIN 转换成对应模式的 `createTransaction()`，事务内的 SQL 和查询使用该 `Transaction` 对象，COMMIT/ROLLBACK 转为其原生方法；BEGIN 返回 null，继续使用 sqflite 的 Dart 事务锁。查询结果集读取完成后立即关闭。

当前应用的数据库操作需要以下 sqflite 方法。表中响应均指成功信封内的 `result`：

| 方法 | sqflite 参数 | 响应 |
|---|---|---|
| `openDatabase` | `path`、`singleInstance`，可选 `readOnly` | `{"id":1}`；id 为整数句柄 |
| `execute` | `id`、`sql`、`arguments`，可能有事务标记 | 通常为 null |
| `insert` | `id`、`sql`、`arguments`，可能有 `transactionId` | 最后插入行的整数 id；SQLite 忽略插入时可为 null |
| `update` | 同上；也用于 DELETE SQL | 受影响行数，整数 |
| `query` | 同上 | `{"columns":["name"],"rows":[["课程"]]}`；空结果的 `rows` 为 `[]` |
| `batch` | `id`、`operations`，可选 `transactionId`、`noResult`、`continueOnError` | 各操作结果数组；详见下文 |
| `closeDatabase` | `id` | null |

SQL 参数缺省时按空数组处理；SQL 中的 `?` 使用绑定参数，不能拼接字符串。返回 SQLite 原本的数值、文本、null 和 BLOB 类型，例如 `PRAGMA user_version` 必须返回整数。查询结果中的列顺序和每行值的顺序必须对应。

事务和批处理约定：

1. 一个数据库 id 始终对应同一个数据库会话，按调用顺序执行；必须支持 `BEGIN EXCLUSIVE`、`BEGIN IMMEDIATE`、`COMMIT`、`ROLLBACK` 及 `PRAGMA user_version`。不能给每条 SQL 额外包事务，也不能失败后偷偷重试写入。
2. sqflite 在事务开始时可能发送 `inTransaction:true, transactionId:null`，结束时发送 `inTransaction:false`。最小实现可以在 BEGIN 后返回 null，继续使用 sqflite 的 Dart 事务锁。如果返回 `{"transactionId":整数}`，则后续必须正确处理该 id：事务外请求排队，直到对应事务结束；`transactionId:-1` 表示强制执行恢复操作。
3. `operations` 是按顺序执行的数组，每项包含 `method`、`sql`、`arguments`。成功项返回 `{"result":值}`；失败项返回 `{"error":{"code":"sqlite_error","message":"…","data":null}}`。
4. `continueOnError` 缺省为 false，此时首次失败就终止并返回外层错误信封，由 sqflite 决定回滚；为 true 时逐项记录失败后继续。`noResult:true` 时不返回逐项数据，成功结果为 null，但不能吞掉应上抛的错误。批处理是否处在事务内由 Dart 发出的 BEGIN/COMMIT 决定。
5. 遵守 `singleInstance` 和 `readOnly`。页面销毁时释放句柄并回滚未提交事务；若选择跨页面恢复连接，必须按 sqflite 的 `recovered` / `recoveredInTransaction` 返回恢复状态。

数据库错误的外层 `code` 使用 `sqlite_error`，Flutter 会转为 `DatabaseException`。必要的 SQL 错误上下文可放在 `details`，不要把数据或凭据写入日志。

以后若调用 `getDatabasesPath`，宿主可返回逻辑目录 `/databases`，并将该前缀下的数据库名映射到同一沙箱；`databaseExists` 接收 `{"path":"…"}` 返回布尔值，`deleteDatabase` 接收相同参数并返回 null。当前服务没有依赖文件级数据库导入导出或分页游标；未知方法要明确报错，不能返回空结果冒充成功。

## 网络：`http.request` / `http.close`

请求示例：

```json
{
  "version":1,
  "method":"http.request",
  "arguments":{
    "clientId":"session-1",
    "url":"https://id.scu.edu.cn/example",
    "method":"POST",
    "headers":{"Content-Type":"application/json","Cookie":"sid=example"},
    "body":{"$bytes":"e30="},
    "followRedirects":false,
    "maxRedirects":5,
    "persistentConnection":true,
    "timeoutMs":15000
  }
}
```

成功响应示例：

```json
{
  "ok":true,
  "result":{
    "statusCode":302,
    "headers":{
      "location":["/next"],
      "set-cookie":["sid=example; Path=/; HttpOnly","route=one; Path=/"]
    },
    "body":{"$bytes":""},
    "isRedirect":true,
    "reasonPhrase":"Found"
  }
}
```

`statusCode`、`headers`、`body` 必须存在；头字段值一律为字符串数组，重复的 `Set-Cookie` 必须完整保留，不能按逗号切分含 `Expires` 的 Cookie。Flutter 再将各值合并成 `package:http` 的头格式，现有 CookieClient 负责解析。

原生网络实现必须遵守以下传输语义：

- 请求在 ArkTS 原生网络层执行，保留 Dart 提供的 Cookie、Origin、Referer、User-Agent 等业务头；不能转回页面 fetch/XHR。
- `followRedirects:false` 时立即返回原始 3xx、Location 和所有 Set-Cookie，不自动跟随。为 true 时遵守 `maxRedirects`，跨来源跳转不能泄露 Authorization、Cookie 等敏感头。需要逐跳收集 Cookie 的 SSO 已由 Dart 禁用自动跳转并逐跳发送。
- CookieClient 是 Cookie 状态的来源。原生侧关闭自动 Cookie 管理，不与 ArkWeb 浏览器 Cookie 仓库同步，也不在不同客户端间共享隐式 Cookie。
- HTTP 4xx/5xx 是正常传输结果，返回成功信封和原始正文，让认证/API 层判断业务错误。
- 返回 HTTP 解压后的完整正文原始字节，包括验证码图片及二进制内容。请求正文也是原始字节；multipart 的 boundary 和正文已由 `package:http` 生成，原生侧不要重新拼装。
- `clientId` 标识客户端生命周期；允许一个客户端并发发送请求。`http.close` 的参数为 `{"clientId":"…"}`，取消该客户端未完成请求并释放资源，返回 null；重复关闭或关闭尚未发请求的客户端应成功。
- `timeoutMs` 覆盖一次请求的总时限；超时后原生侧应终止请求。Flutter 侧也会在 15 秒后停止等待，但停止等待本身无法中止原生任务。

桥接错误码：

| code | Flutter 行为 |
|---|---|
| `http_transport` / `http_closed` | 转为 `http.ClientException`，CookieClient 沿用已有重试策略 |
| `http_timeout` | 转为 `TimeoutException` |
| 其他错误码（如 `http_forbidden`、`unsupported_method`） | 保留原生异常，不触发传输重试 |

不要在宿主额外重放请求；已有业务层对写操作的重试限制仍需保留。

[`NativeHttp.ets`](../../ohos/entry/src/main/ets/bridge/NativeHttp.ets) 通过 RCP Session 发送请求，关闭自动重定向、响应缓存和详细跟踪，不配置 Cookie 仓库。需要跟随跳转时逐跳发送，逐跳检查域名并移除跨来源敏感头。当前允许 `scu.edu.cn` 及其子域名的 HTTP/HTTPS 默认端口；其他目标返回 `http_forbidden`。接口支持 GET、HEAD、POST、PUT、PATCH、DELETE、OPTIONS。

超时计时覆盖整个重定向链；支持 1–120000 毫秒和 0–50 次跳转，Flutter 当前发送 15000 毫秒。超时或关闭客户端会取消原生请求并结束对应 Promise。失败日志仅记录方法、域名、请求 ID、时限或系统错误码，不记录 URL 参数、请求头和正文。关闭过的客户端 id 在当前页面会话内不能重新打开。`persistentConnection:false` 使用独立 Session，完成后释放，避免影响同客户端的并发请求。模块已声明 `ohos.permission.INTERNET`。

## 沉浸式窗口与安全区

[`EntryAbility.ets`](../../ohos/entry/src/main/ets/entryability/EntryAbility.ets) 在加载页面前启用 `setWindowLayoutFullScreen(true)` 并将系统栏背景设为透明；保留状态栏、导航栏和手势条。`Index.ets` 中的 Web 与外层容器同时扩展到系统栏和挖孔区域。Flutter 初始化后为引擎创建的 viewport 标签补上 `viewport-fit=cover`，避免 HTML 中的静态设置被引擎覆盖。

`window.getMetrics` 接受空 `arguments`，返回以下结构（数字仅为示例）：

```json
{"padding":{"top":136,"right":0,"bottom":98,"left":0},"keyboardVisible":false}
```

`padding` 采用窗口物理像素，合并状态栏、挖孔、底部手势条的各边遮挡深度；重叠区域取最大值。Flutter 按 `MediaQuery.devicePixelRatio` 换算，更新 `viewPadding` 与 `padding`，不在整页外层增加实体空白。已有的 AppBar、SafeArea 和 NavigationBar 根据这些尺寸避让，页面与底部导航栏背景仍绘制到系统栏下方。

原生监听 `avoidAreaChange` 和 `windowSizeChange`，通过 `window.bugaoshanViewportChanged(metricsJson)` 通知 Flutter，支持旋转、分屏和系统栏变化。Flutter 先注册回调再查询初始值；页面重新加载时再次查询，页面销毁时原生移除监听。事件只向本地应用来源投递。

键盘保持 `WebKeyboardAvoidMode.RESIZE_CONTENT`，不扩展到键盘区域。原生额外通知键盘可见状态；Flutter 保留引擎计算的 `viewInsets`，键盘弹出时取消底部手势条的额外 padding，避免双重避让。

`window.setSystemBarStyle` 接受 `{"dark":true}` 或 `{"dark":false}`，按 Flutter 当前明暗主题设置状态栏及三键导航栏文字颜色，背景保持透明。手势指示条由系统管理。本次适配需要同时重新构建 Flutter Web 并打包鸿蒙容器。

## 本地中文字体

`web/fonts/` 提供完整的 Noto Sans SC 常规（400）、中等（500）、半粗（600）和粗体（700）WOFF2 文件及 OFL 许可证。该目录随 Flutter Web 构建复制到 `build/web/fonts/`，无需修改 `pubspec.yaml`，Android、Windows 等原生构建也不会因此打包字体。

[`arkweb_fonts.dart`](../../lib/services/arkweb/arkweb_fonts.dart) 仅在存在 ArkWeb 原生桥时执行。它通过浏览器 HTTP 客户端读取相对页面 `base href` 的 `fonts/` 资源，由现有鸿蒙请求拦截从 `rawfile/web/fonts/` 返回；不用原生校园网 HTTP 代理，也不读取设备系统字体。初始化等待四个字重通过 `FontLoader` 注册完成后才调用 `runApp`，避免主界面先显示缺字方框。

加载成功后，主题固定使用 `BugaoshanNotoSansSC` 字体族，并跳过 Google Fonts 的运行时主题加载。其他平台和普通浏览器保留原有字体设置。字体设置入口在 ArkWeb 中隐藏。字体文件缺失或请求失败会记录日志并进入已有启动错误页面，不会静默改为在线下载。特殊字符或本字体未覆盖的语言仍可能触发 Flutter 引擎的备用字体机制。

字体来源、原始文件指纹及压缩方式见 [`web/fonts/README.md`](../../web/fonts/README.md)。修改后需要重新构建 Web、将完整产物复制到鸿蒙 `rawfile/web/`，再打包安装。

## 边界

验证码 OCR 使用随 Web 产物打包的 `scu_ocr_lite` 模型，不需要联网识别。Flutter Web 调用同步 `recognize()`，避免依赖库的 `recognizeAsync()` 调用 Web 不支持的 `Isolate.run`；其他平台继续使用异步识别。Web 识别在页面线程执行。

桥接只向 `https://app.bugaoshan.invalid` 的受信任应用页面开放，宿主负责限制可访问的网络目标和数据库，外部网页不能获得相同代理。业务端点包括 HTTP 的教务系统，不能把协议限制误写为仅 HTTPS；每次原生自动重定向也需要遵守宿主的访问限制。

当前适配面向数据库及认证/API 请求，HTTP 请求和响应会完整缓冲，再经 Base64 传输，尚未提供大文件流式下载或单请求主动取消接口。其他独立网络入口、文件操作、通知 WebView 和平台插件仍需要各自的平台支持。这份接口不等同于整个应用已经完成鸿蒙移植。

Flutter 源码变动后，需要重新生成 Web 产物并复制到 `ohos/entry/src/main/resources/rawfile/web/`。[构建模板](../../web/flutter_bootstrap.js) 使用相对页面 base href 的本地 CanvasKit 地址，并且不传入 `serviceWorkerSettings`，因此后续构建会自动保留这两项配置。产物中的 `flutter_service_worker.js` 文件本身不会启用 Service Worker，是否注册取决于启动脚本。
