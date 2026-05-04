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

**GitHub Actions release**: triggers on git tags matching `v*.*.*`; builds all 3 platforms and uploads to GitHub Releases.

**HarmonyOS build**: separate workflow dispatches to `TEMP-HOMO` repo for HarmonyOS APK builds.

### Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, etc.

## Architecture

### State Management
Provider + ChangeNotifier. Providers are registered in `lib/injection/injector.dart` and initialized asynchronously via `configureDependencies()`.

### Dependency Injection
GetIt + Injectable. `lib/injection/injector.config.dart` is auto-generated. Re-run `dart run build_runner build` after modifying `@injectable` annotations.

### Service Layer
- **`ScuAuthService`** (`lib/services/scu_auth_service.dart`) — Stateful service holding the SCU access token. Handles SM2 password encryption, cookie-based session management, and all SCU API calls (login, schedule, grades).
- **`ScuMicroserviceAuthService`** (`lib/services/scu_microservice_auth_service.dart`) — Handles auth for SCU microservice-based APIs (电费, 空调余额, 校园网设备).
- **`CcylService`** (`lib/services/ccyl_service.dart`) — 第二课堂 (CCYL) API client. OAuth-based login via `CcylService.login(oauthCode)`. Activities, reservations, and成绩单.
- **`CcylOauthService`** (`lib/services/ccyl_oauth_service.dart`) — OAuth flow helper for CCYL login.
- **`BalanceQueryService`** (`lib/services/balance_query_service.dart`) — Queries电费 and 空调余额 via `payapp.scu.edu.cn`.
- **`DatabaseService`** (`lib/services/database_service.dart`) — SQLite-backed storage. Manages multiple schedule configs and their associated course data via `switchSchedule()`.
- **`IcsService`** (`lib/services/ics_service.dart`) — Exports course schedules as iCalendar (.ics) files.
- **`OcrService`** (`lib/services/ocr_service.dart`) — TFLite-based captcha recognition for SCU login.
- **`UpdateService`** (`lib/services/update_service.dart`) — Handles GitHub release checking, download, and install for Windows/Linux desktop platforms.
- **`WidgetUpdateService`** (`lib/services/widget_update_service.dart`) — Android 桌面小组件数据更新，通过 MethodChannel 与原生层通信。
- **`WindowStateService`** (`lib/services/window_state_service.dart`) — Desktop 窗口状态持久化，保存/恢复窗口位置和大小。

### Providers
- **`ScuAuthProvider`** — Persists SCU token via SharedPreferences. Wraps `ScuAuthService`.
- **`GradesProvider`** — Handles `ScuLoginException.sessionExpired` by auto-calling `logout()`.
- **`CourseProvider`** — Depends on `DatabaseService`. Provides schedule CRUD.
- **`AppConfigProvider`** — User preferences: locale, theme color.
- **`AppInfoProvider`** — App version info and CI build metadata (git tag, commit, build time).
- **`BalanceQueryProvider`** — 电费 & 空调余额查询状态管理，支持多房间绑定切换。
- **`CcylProvider`** — 第二课堂登录状态持久化，管理 OAuth token。
- **`ExportScheduleProvider`** — 课表导出（剪贴板 JSON / .ics 文件 / 系统日历）。
- **`SecureStorageProvider`** — `FlutterSecureStorage` 单例封装，统一管理安全存储。

### Key Patterns
- **Session expiry**: `ScuLoginException` carries `sessionExpired: bool`. Providers catch it and call `logout()` on auth provider.
- **Multiple schedules**: Courses are stored in a single SQLite `courses` table, filtered by `schedule_id`. `DatabaseService.switchSchedule()` updates the current schedule ID and refreshes the in-memory cache.
- **Responsive dialogs**: `popupOrNavigate()` in `router_utils.dart` shows a bottom sheet dialog on tablets/landscape, full-page navigation on phones.
- **国密**: SM2 crypto via `dart_sm` package — used to encrypt the password before sending to SCU's auth API.

### Storage
- **SQLite** (`sqflite`) — Course data, schedule configs (persistent). Desktop platforms use `sqflite_common_ffi`.
- **SharedPreferences** — Auth token, grades cache, app settings (key-value)

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
│   │   ├── grades/        # 成绩查询
│   │   ├── models/        # 校园模块数据模型
│   │   ├── network_device/# 校园网设备管理
│   │   ├── plan_completion/ # 培养方案完成度
│   │   ├── profile/       # 个人中心
│   │   └── train_program/ # 培养方案查询
│   ├── course/            # 课表管理
│   ├── settings/          # 设置页面
│   └── wizard/            # 引导页面
├── providers/
│   └── environment_info/  # 环境信息 Provider
├── services/              # Business logic & network
├── utils/                 # Constants, crypto, utilities
├── widgets/               # Shared UI components
│   ├── common/            # 通用组件
│   ├── course/            # 课表相关组件
│   ├── dialog/            # 弹窗组件
│   └── route/             # 路由工具
├── app.dart               # MaterialApp configuration
└── main.dart              # Entry point, DI bootstrap
```

## Notable Implementation Details

- The `ScuAuthService._CookieClient` manually follows HTTP redirects to collect cookies across SSO redirect chains.
- Grades are cached in SharedPreferences as JSON; on refresh failure with `sessionExpired`, the cached data is kept but user is logged out.
- `flutter pub run build_runner build --delete-conflicting-outputs` is run in CI before `flutter gen-l10n` — code generation must precede localization generation.

### Build Metadata

CI builds inject git metadata via `--dart-define` flags: `GIT_TAG`, `GIT_COMMIT`, `GIT_COMMIT_DATE`, `BUILD_TIME`. These are extracted by `.github/scripts/git_meta.py` and consumed in the app for version display.

### Release Automation

Release workflow uses Python scripts in `.github/scripts/` for changelog extraction (`release_changelog.py`), release body generation (`release_body.py`), and artifact preparation (`release_prepare.py`). The workflow runs on git tags matching `v*.*.*` or manual dispatch.
