<div align="center">

# 🏔️ Bugaoshan

[![Flutter](https://img.shields.io/badge/Flutter-3.41.6-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Linux%20%7C%20macOS%20%7C%20Windows-blue)](https://flutter.dev)

> A modern, cross-platform Flutter application with clean architecture.

</div>

---

## ✨ Features

- 🌐 **Multi-language** — English & Chinese localization
- 🎨 **Dynamic Theming** — Light/Dark mode with customizable color schemes
- 💉 **Dependency Injection** — Clean DI setup with GetIt & Injectable
- 💾 **Local Storage** — Hive CE for fast, efficient data persistence
- 🌍 **Network Layer** — Dio with cookie management & SM cryptography
- 📱 **Cross-Platform** — Runs on Android, iOS, Web, Linux, macOS, Windows

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) >= 3.41.6
- [Dart SDK](https://dart.dev/get-dart) >= 3.11.4

### Installation

```bash
# Clone the repository
git clone git@github.com:The-Brotherhood-of-SCU/Bugaoshan.git
cd Bugaoshan

# Install dependencies
flutter pub get

# Run code generation (for DI & l10n)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## 📁 Project Structure

```
lib/
├── injection/            # Dependency injection (GetIt + Injectable)
├── l10n/                 # Internationalization (ARB files & generated locals)
├── models/               # Data models & entities
├── pages/                # Application screens/pages
├── providers/            # State management providers
├── serivces/             # Business logic & service layer
├── utils/                # Helper utilities & constants
├── widgets/              # Reusable UI components
├── app.dart              # App configuration & theme
└── main.dart             # Application entry point
```

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | [Flutter](https://flutter.dev) |
| **State Management** | Provider / ChangeNotifier |
| **Dependency Injection** | [GetIt](https://pub.dev/packages/get_it) + [Injectable](https://pub.dev/packages/injectable) |
| **Networking** | [Dio](https://pub.dev/packages/dio) + Cookie Manager |
| **Local Storage** | [Hive CE](https://pub.dev/packages/hive_ce), [SharedPreferences](https://pub.dev/packages/shared_preferences) |
| **Localization** | Flutter `flutter_localizations` |
| **Cryptography** | [dart_sm](https://pub.dev/packages/dart_sm) (SM2/SM3/SM4) |
| **Utilities** | [url_launcher](https://pub.dev/packages/url_launcher), [package_info_plus](https://pub.dev/packages/package_info_plus), [flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker) |

## 📸 Screenshots

_Add screenshots here_

## 🌍 Localization

Supported languages:

| Language | Code |
|----------|------|
| English | `en` |
| 简体中文 | `zh` |

## 📝 Scripts

| Script | Description |
|--------|-------------|
| `_build_generator.bat` | Run code generation for DI |
| `_build_l10n.bat` | Generate localization files |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the AGPL-3.0 License — see the [LICENSE](LICENSE) file for details.
