# Sentry 错误收集与问题反馈

本页描述基于 `sentry_flutter` 的错误采集、自动反馈弹窗与用户主动反馈链路。

## 配置

- DSN 通过编译参数注入，不写入代码：`--dart-define=SENTRY_DSN=https://xxx@oXXX.ingest.sentry.io/XXX`
- 未注入 `SENTRY_DSN` 时 SDK 不初始化，错误采集与自动弹窗均为禁用状态（手动打开反馈页会提示未配置）。
- CI 从 GitHub Secret `SENTRY_DSN` 注入；本地调试使用上面的 `flutter run` 参数。

## 组件

| 文件 | 职责 |
|---|---|
| `lib/services/sentry/sentry_service.dart` | `SentryFlutter.init`、异常上报、通过 `Sentry.captureFeedback` 提交用户反馈（截图 + 日志附件） |
| `lib/services/sentry/error_feedback_coordinator.dart` | 包装 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`，自动弹反馈页并做 15 秒防抖 |
| `lib/pages/feedback/feedback_page.dart` | 反馈表单：问题描述、联系方式、截图（`image_picker`）、日志附件（`file_picker`，`.log`/`.txt`）与内置认证日志开关 |
| `lib/pages/dev/feedback_test_tile.dart` | 开发者页面测试入口：手动打开反馈页 / 触发测试异常 |

DI 注册位于 `lib/injection/injector.dart`：

- `SentryService`（lazy singleton，依赖 `AuthLogger`）
- `ErrorFeedbackCoordinator`（lazy singleton，依赖 `SentryService`）

## 启动时序

`lib/main.dart`：

1. `WidgetsFlutterBinding.ensureInitialized()` + 桌面平台初始化；
2. `configureDependencies()`；
3. `SentryService.initialize()` → `ErrorFeedbackCoordinator.attach()`；
4. `ensureBasicDependencies()`（其异步异常也会进入上报链路）；
5. `runApp(MyApp())`。

启动失败时 `main` 的 catch 会直接调用 `SentryService.captureException` 后展示启动失败页（此时 UI 尚未构建，无法弹反馈表单）。

## 错误 → 反馈链路

- Flutter 框架异常：Sentry 自带的 `FlutterErrorIntegration` 已捕获，协调器保留原处理器并只负责弹窗，避免重复上报。
- Zone/异步未捕获异常：协调器先 `Sentry.captureException`，再弹窗。
- 异常发生在首帧构建前时，协调器轮询等待 `navigatorKey.currentContext` 可用后再通过 `popupOrNavigate` 弹出（手机全屏、平板/桌面为对话框）。
- 同一时间只弹一个反馈页，15 秒内连续异常不重复打扰用户。

## 反馈提交

提交时通过 `Sentry.captureFeedback` 创建 User Feedback 事件：

- 问题描述进入 `SentryFeedback.message`，联系方式若为邮箱格式进入 `contactEmail`；
- 关联最近一次由本服务捕获的异常 `associatedEventId`；
- 截图通过 `SentryAttachment.fromScreenshotData`、日志通过 `SentryAttachment.fromUint8List` 挂到 scope；
- 自动附带 `AuthLogger` 导出的应用日志，文件名格式 `yyyyMMdd-HHmmss-<版本>.log`（已脱敏）；
- 用户可额外选择 `.log` / `.txt` 文件作为附件。

## 隐私

- Sentry 选项关闭 `sendDefaultPii`；
- 只有用户主动填写联系方式才会上传该字段；
- `AuthLogger` 内容在写入缓冲前已经过 `AuthLogRedactor` 脱敏；
- 反馈页明示内容将发送至 Sentry，提醒用户勿包含密码、令牌等敏感信息。

## CI

`build-android.yml` / `build-windows.yml` 在 `flutter build` 时追加
`--dart-define=SENTRY_DSN="${{ secrets.SENTRY_DSN }}"`。`release.yml` 已 `secrets: inherit`，
无需额外传递；仓库需在 GitHub Actions Secrets 中配置 `SENTRY_DSN`。
