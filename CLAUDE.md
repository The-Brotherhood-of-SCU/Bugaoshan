# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bugaoshan (不高山上) — A campus assistant app for Sichuan University students, covering course schedules, classroom availability, and grades.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Run code generation (DI + model serialization)
dart run build_runner build --delete-conflicting-outputs

# Generate internationalization
flutter gen-l10n

# Run the app
flutter run

# Build release APK
flutter build apk --release

# Build release for other platforms
flutter build ios --release --no-codesign
flutter build windows --release
```

**GitHub Actions release**: triggers on git tags matching `v*.*.*`; builds Android, iOS, and Windows and uploads to GitHub Releases. The project also supports Linux, macOS, and Web platforms.

### Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, etc.

## Architecture

### State Management
`ValueNotifier` / `ChangeNotifier` with Flutter's built-in `ValueListenableBuilder` and `ListenableBuilder`. Providers are registered in `lib/injection/injector.dart` and initialized asynchronously via `configureDependencies()`.

Two patterns coexist by design:

- **ChangeNotifier** — Use for providers with coarse-grained state changes (auth state, load states, error states). UI consumes via `ListenableBuilder(listenable: providerInstance)`. Examples: `ScuAuthProvider`, `GradesProvider`, `TrainProgramProvider`.
- **多 ValueNotifier 字段** — Use for providers with many independent config/setting fields where widgets should only rebuild when specific fields change. UI consumes via `ListenableBuilder(listenable: Listenable.merge([field1, field2]))` or `ValueListenableBuilder`. Examples: `AppConfigProvider` (14 fields), `CourseProvider` (5 fields).
- **手动 addListener** — Use only for imperative side-effects (animations, SnackBars, triggering data loads), never for pure rebuild triggers.

**Directory convention:** All DI-registered providers live in `lib/providers/`. Page-specific non-DI utility classes may live in page directories.

### Dependency Injection
GetIt + Injectable. All Provider/Service registrations are done manually in `lib/injection/injector.dart` (not via `@injectable` annotations). `lib/injection/injector.config.dart` is auto-generated but currently only contains an empty `init()` extension. Re-run `dart run build_runner build` if `@injectable` annotations are ever added.

### Service Layer (Three-Layer Architecture)

**Layer 3 — Unified Auth:**
- **`ScuAuth`** (`lib/services/auth/scu_auth.dart`) — SCU 统一身份认证（第3层）。合并 login / fetchCaptcha / bindSession / logout / token 管理 / SSO 预热 / 自动续期。内置 `_synchronizedRefresh` mutex（Completer 互斥）。续期失败抛 `UnauthenticatedException`。

**Layer 2 — Subsystem Auth:**
- **`ZhjwAuth`** (`lib/services/auth/zhjw_auth.dart`) — 教务系统 SSO，代理 `ScuAuth.getClient()`。
- **`WfwAuth`** (`lib/services/auth/wfw_auth.dart`) — 微服务认证，共享 ScuAuth 的 CookieClient（SSO session）。
- **`PayAppAuth`** (`lib/services/auth/payapp_auth.dart`) — 缴费平台 OAuth warrant 跳转。
- **`FitnessAuth`** (`lib/services/auth/fitness_auth.dart`) — 体测 SSO 跳转。
- **`CcylAuth`** (`lib/services/auth/ccyl_auth.dart`) — 第二课堂 OAuth token 管理。
- **`CcylOauthService`** (`lib/services/auth/ccyl_oauth_service.dart`) — SCU→CCYL OAuth 桥接。

**Layer 1 — API Service:**
- **`ZhjwApiService`** (`lib/services/api/zhjw_api_service.dart`) — 教务系统数据 API（课表/成绩/教室/培养方案/计划完成度）。
- **`WfwApiService`** (`lib/services/api/wfw_api_service.dart`) — 微服务 API（用户标签）。
- **`PayAppApiService`** (`lib/services/api/payapp_api_service.dart`) — 缴费平台 API（电费/空调余额）。
- **`CcylApiService`** (`lib/services/api/ccyl_api_service.dart`) — 第二课堂 API（活动/学分）。
- **`CcylService`** (`lib/services/ccyl/ccyl_service.dart`) — 第二课堂纯数据 API（无状态静态方法）。
- **`BalanceQueryService`** (`lib/services/api/balance_query_service.dart`) — 电费/空调余额纯数据 API。
- **`DatabaseService`** (`lib/services/database_service.dart`) — SQLite-backed storage. Manages multiple schedule configs and their associated course data via `switchSchedule()`.
- **`DownloadManager`** (`lib/services/download_manager.dart`) — `ChangeNotifier` that tracks download task lifecycle (pending → downloading → done/error). Used by `showAttachmentsSheet` to reflect per-file state in the UI.
- **`IcsService`** (`lib/services/ics_service.dart`) — Exports course schedules as iCalendar (.ics) files.
- **`OcrService`** (`lib/services/ocr_service.dart`) — TFLite-based captcha recognition for SCU login.
- **`UpdateService`** (`lib/services/update_service.dart`) — Handles GitHub release checking, download, and install for Windows/Linux desktop platforms.
- **`WidgetUpdateService`** (`lib/services/widget_update_service.dart`) — Android 桌面小组件数据更新，通过 MethodChannel 与原生层通信。
- **`ExitService`** (`lib/services/exit_service.dart`) — 统一应用退出逻辑，桌面端使用 `windowManager.destroy()`，移动端使用 `exit(0)`。
- **`WindowStateService`** (`lib/services/window_state_service.dart`) — Desktop 窗口状态持久化，保存/恢复窗口位置和大小。

### Notice Pages

Three notice sources, each in its own subdirectory under `lib/pages/campus/notice/`:

**JWC Academic Affairs** (`jwc/`) — `jwc.scu.edu.cn`教务处通知。

- `campus_notice_page.dart` — thin `StatelessWidget` wrapper around `WebViewNoticePage`. Uses `jwc_notice_beautify.js` for content beautification and attachment extraction.

**Party/XGB** (`xgb/`) — `xgb.scu.edu.cn`党委学工部通知。

- `party_notice_page.dart` — thin `StatelessWidget` wrapper around `WebViewNoticePage`. Uses `party_notice_beautify.js`.

**Tuanwei** (`tuanwei/`) — `tuanwei.scu.edu.cn`团委（青春川大）通知。

- `tuanwei_notice_page.dart` — thin `StatelessWidget` wrapper around `WebViewNoticePage`. Uses `tuanwei_notice_beautify.js`. Uses `useWebViewDownload: true` for cookie-based downloads.

**Shared WebView page** (`lib/pages/campus/notice/webview_notice_page.dart`):
- `WebViewNoticePage` — shared `StatefulWidget` used by all three notice pages. Loads the notice URL in an `InAppWebView`, injects a beautify JS asset on each page load, extracts attachments via `AttachmentsChannel` JS handler, and shows a `NoticeAttachmentFab` when attachments are found.

**Shared downloads module** (`lib/pages/campus/downloads/`):
- `NoticeAttachmentFab` — draggable FAB showing attachment count, opens `showAttachmentsSheet` on tap. Shared by all notice pages.
- `attachments_sheet.dart` — `showAttachmentsSheet()` modal bottom sheet with download/share/open per attachment.
- `file_utils.dart` — `kNoticeAttachmentDir`, `kPartyAttachmentDir`, `kTuanweiAttachmentDir`, `downloadFile()`, `checkDownloadedFile()`.
- `notice_downloaded_page.dart` — tabbed management page for downloaded attachments from both sources.
- `DownloadManager` (`lib/services/download_manager.dart`) — tracks download task state (pending/downloading/done/error).

### Providers
- **`ScuAuthProvider`** — 认证控制器。管理 SCU 登录/登出/自动登录（OCR 验证码，最多 5 次重试）/凭据保存。直接持有 `ScuAuth` + `CcylAuth`。
- **`UserInfoProvider`** — 监听 `WfwAuth` 状态变化，自动获取用户信息（realname/number）和标签（图书借阅量/校园卡余额/网费余额）。登录后自动 fetch，登出自动 clear。
- **`GradesProvider`** — Holds `ZhjwApiService` field; calls `fetchSchemeScores()` / `fetchPassingScores()` directly. Session expired handling delegated to `retryOnUnauthenticated` (auto-refresh + retry + global snackbar via `SessionExpiredListener`). Caches grades to SharedPreferences.
- **`CourseProvider`** — Depends on `DatabaseService`. Provides schedule CRUD.
- **`AppConfigProvider`** — User preferences: locale, theme color, color opacity, course card font size, course grid visibility, course row height, background image, dock items, EULA acceptance, etc.
- **`SetThemeColorProvider`** — 从背景图片中提取主题色（像素采样 + `compute()` isolate），支持系统强调色预览。
- **`AppInfoProvider`** — App version info and CI build metadata (git tag, commit, build time).
- **`BalanceQueryProvider`** — 电费 & 空调余额查询状态管理，支持多房间绑定切换。
- **`CcylProvider`** — 第二课堂登录状态管理。委托 `CcylAuth` 处理 OAuth token 持久化（`FlutterSecureStorage`）。通过 `CcylApiService`（`service` getter）提供 API 访问。
- **`TrainProgramProvider`** — 培养方案查询，管理学院/年级/方案列表及详情加载状态。
- **`PlanCompletionProvider`** — 培养方案完成度，缓存到 SharedPreferences，支持速率限制处理。
- **`ExportScheduleProvider`** — 课表导出（剪贴板 JSON / .ics 文件 / 系统日历）。
- **`SecureStorageProvider`** — `FlutterSecureStorage` 单例封装，统一管理安全存储。

### Key Patterns
- **Session expiry**: `ScuAuth.getClient()` checks TTL (1-hour), calls `_synchronizedRefresh()` (Completer mutex, N concurrent = 1 refresh) on expiry. Refresh fails → `onSessionExpired` callback fires → `SessionExpiredListener` shows SnackBar with "前往登录" action (5s debounce). API Service layer uses `retryOnUnauthenticated(getClient, fn)` to catch `UnauthenticatedException` and retry once. Business providers catch `UnauthenticatedException` / `ServiceException` for UI state.
- **Multiple schedules**: Courses are stored in a single SQLite `courses` table, filtered by `schedule_id`. `DatabaseService.switchSchedule()` updates the current schedule ID and refreshes the in-memory cache.
- **Responsive dialogs**: `popupOrNavigate(context, page)` in `router_utils.dart` shows a dialog on tablets/landscape (width/2), a dialog on big portrait (2/3 width+height), or full-page navigation on phones. Automatically falls back to `Navigator.push` if already inside a popup (`PopupContext.of(context)`).
- **`logicRootContext`**: Global getter (`navigatorKey.currentContext!`) in `router_utils.dart`. Use when you need a `BuildContext` that outlives the current widget — e.g., after `Navigator.pop(context)` the local `context` is disposed, so capture `logicRootContext` beforehand. Common pattern: `final rootCtx = logicRootContext; Navigator.pop(context); popupOrNavigate(rootCtx, ...)`.
- **国密**: SM2 crypto via `dart_sm` package — used to encrypt the password before sending to SCU's auth API.
- **Dynamic navigation**: Home page uses a customizable dock system (`lib/models/campus_item_config.dart`). Users can enable/disable/reorder dock items. Pages are lazily built and cached in an `IndexedStack`.
- **Theme system**: Supports system accent color, custom color, or color derived from background image. Background image opacity is configurable.

### Storage
- **SQLite** (`sqflite`) — Course data, schedule configs (persistent). Desktop platforms use `sqflite_common_ffi`.
- **SharedPreferences** — Login timestamp, user info, grades cache, app settings (key-value)
- **FlutterSecureStorage** — Sensitive data (access token, saved credentials)

### Internationalization
ARB source files in `lib/l10n/app_*.arb`. Generated to `lib/l10n/app_localizations.dart` via `flutter gen-l10n`. No external l10n service.

**Note on `app_zh_Hans_CN.arb`**: This file exists solely to ensure correct CJK locale resolution. It should contain only the minimal entries needed for locale fallback — specifically `bugaoshan` and `selfLanguage`. Do NOT add translation entries here; put them in `app_zh.arb` instead.

## Directory Structure

```
lib/
├── injection/              # DI setup (GetIt + Injectable)
├── l10n/                   # ARB files + generated localizations
├── models/                 # Data models (Course, SchemeScore, etc.)
├── pages/
│   ├── about/             # 关于页面
│   ├── auth/              # 登录认证
│   ├── campus/            # 校园功能模块
│   │   ├── academic_calendar/ # 校历查询
│   │   ├── balance_query/ # 电费 & 空调余额查询
│   │   ├── ccyl/          # 第二课堂 (CCYL)
│   │   ├── classroom/     # 空闲教室查询
│   │   ├── downloads/     # 共享下载模块（附件 FAB、下载 Sheet、文件工具）
│   │   ├── fitness_test/  # 体测查询
│   │   ├── grades/        # 成绩查询
│   │   ├── models/        # 校园模块数据模型
│   │   ├── network_device/# 校园网设备管理
│   │   ├── notice/        # 通知公告（jwc/ 教务处 + xgb/ 学工部 + tuanwei/ 团委）
│   │   ├── plan_completion/ # 培养方案完成度
│   │   └── train_program/ # 培养方案查询
│   ├── course/            # 课表管理
│   ├── profile/           # 个人中心
│   ├── settings/          # 设置页面
│   ├── test/              # 测试/调试页面
│   ├── wizard/            # 引导页面
│   ├── campus_page.dart   # 校园功能入口
│   └── home_page.dart     # 首页
├── providers/
│   ├── environment_info/  # 环境信息 Provider
│   ├── train_program_provider.dart # 培养方案查询
│   └── plan_completion_provider.dart # 培养方案完成度
├── services/              # Business logic & network
├── utils/                 # Constants, crypto, utilities
├── widgets/               # Shared UI components
│   ├── common/            # 通用组件
│   ├── course/            # 课表相关组件
│   ├── dialog/            # 弹窗组件
│   ├── route/             # 路由工具
│   └── eula_content.dart  # 用户协议内容
├── app.dart               # MaterialApp configuration
└── main.dart              # Entry point, DI bootstrap
```

## Notable Implementation Details

- `CookieClient` (`lib/services/auth/cookie_client.dart`) — Cookie 感知的 http.Client，按域名隔离存储，发送时只带当前请求域的 cookie。`followRedirects()` 手动跟随重定向并收集每跳的 Set-Cookie。被 `ScuAuth.bindSession()` 用来执行 SSO 跳转链。
- `_request()` 模板方法（每个 API Service 都有）— 自动重试一次：`_auth.getClient()` → 业务 HTTP → 捕获 `UnauthenticatedException` → 重试一次 → 仍失败则穿透到 Provider。业务方只需 `await apiService.fetchXxx()`，不碰 token/cookie/重试细节。
- Session 过期统一由 `SessionExpiredListener` (`lib/widgets/common/session_expired_listener.dart`) 监听 `ScuAuth.onSessionExpired` 回调，全局弹 SnackBar 带「前往登录」action 按钮（5 秒防抖）。
- Grades are cached in SharedPreferences as JSON; on refresh failure with `sessionExpired`, the cached data is kept but user is logged out.
- `flutter pub run build_runner build --delete-conflicting-outputs` is run in CI before `flutter gen-l10n` — code generation must precede localization generation.
- The `DatabaseService` includes a Hive-to-SQLite migration path for users upgrading from older versions.
- Auto-login retries up to 5 times on captcha failures, using TFLite OCR to recognize captchas automatically.

### Build Metadata

CI builds inject git metadata via `--dart-define` flags: `GIT_TAG`, `GIT_COMMIT`, `GIT_COMMIT_DATE`, `BUILD_TIME`. These are extracted by `.github/scripts/git_meta.py` and consumed in the app for version display.

### Release Automation

Release workflow uses Python scripts in `.github/scripts/` for changelog extraction (`release_changelog.py`), release body generation (`release_body.py`), artifact preparation (`release_prepare.py`), and version tag resolution (`release_tags.py`). The workflow runs on git tags matching `v*.*.*` or manual dispatch.
