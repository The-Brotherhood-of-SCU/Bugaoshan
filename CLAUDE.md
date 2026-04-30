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

## Architecture

### State Management
Provider + ChangeNotifier. Providers are registered in `lib/injection/injector.dart` and initialized asynchronously via `configureDependencies()`.

### Dependency Injection
GetIt + Injectable. `lib/injection/injector.config.dart` is auto-generated. Re-run `dart run build_runner build` after modifying `@injectable` annotations.

### Service Layer
- **`ScuAuthService`** (`lib/services/scu_auth_service.dart`) — Stateful service holding the SCU access token. Handles SM2 password encryption, cookie-based session management, and all SCU API calls (login, schedule, grades).
- **`CirApiService`** (`lib/services/cir_api_service.dart`) — Fetches real-time classroom availability from `cir.scu.edu.cn`.
- **`DatabaseService`** (`lib/services/database_service.dart`) — SQLite-backed storage. Manages multiple schedule configs and their associated course data via `switchSchedule()`.
- **`UpdateService`** (`lib/services/update_service.dart`) — Handles GitHub release checking, download, and install for Windows/Linux desktop platforms.

### Providers
- **`ScuAuthProvider`** — Persists SCU token via SharedPreferences. Wraps `ScuAuthService`.
- **`GradesProvider`** — Handles `ScuLoginException.sessionExpired` by auto-calling `logout()`.
- **`CourseProvider`** — Depends on `DatabaseService`. Provides schedule CRUD.
- **`AppConfigProvider`** — User preferences: locale, theme color.

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
├── injection/     # DI setup (GetIt + Injectable)
├── l10n/           # ARB files + generated localizations
├── models/         # Data models (Course, SchemeScore, etc.)
├── pages/          # Screen widgets
│   └── campus/    # Campus feature module (grades, classroom)
├── providers/      # ChangeNotifier state classes
├── services/       # Business logic & network
├── utils/          # Constants, crypto, utilities
├── widgets/        # Shared UI components
├── app.dart        # MaterialApp configuration
└── main.dart       # Entry point, DI bootstrap
```

## Notable Implementation Details

- The `ScuAuthService._CookieClient` manually follows HTTP redirects to collect cookies across SSO redirect chains.
- Grades are cached in SharedPreferences as JSON; on refresh failure with `sessionExpired`, the cached data is kept but user is logged out.
- `flutter pub run build_runner build --delete-conflicting-outputs` is run in CI before `flutter gen-l10n` — code generation must precede localization generation.
