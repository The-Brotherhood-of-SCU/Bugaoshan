# HarmonyOS 开发指南

本目录是不高山上（Bugaoshan）的 HarmonyOS 原生工程，与其他平台在同一分支维护。
DevEco Studio 直接打开本目录。

## 目录结构

```text
ohos/
├── AppScope/          # 应用标识、版本与图标
├── entry/             # 原生入口、平台通道、课表卡片与资源
├── hvigor/            # Hvigor 配置
├── hvigorfile.ts      # 原生构建任务
├── hvigorconfig.ts     # Flutter 插件模块注入
├── oh-package.json5   # 鸿蒙工程依赖
├── build-profile.json5
└── vendor/cpf/        # 本地 CPF 源码克隆（不入库）
```

## 环境要求

| 工具 | 版本 |
| --- | --- |
| HarmonyOS SDK | API 26（编译与目标），最低安装 API 20 |
| DevEco Studio | 26.0.0.821，使用配套 Node、OHPM 和 Hvigor |
| Flutter OH | 见根 `pubspec.yaml` 的 OH 平台包来源 |

## 构建

确认 PATH 中的 `flutter` 指向 Flutter OH，并且 `ohos/local.properties` 中的
`flutter.sdk` 指向同一套 SDK。DevEco Sync 会在首次使用或依赖变更后自动执行
`flutter pub get --no-example --enforce-lockfile`，生成插件列表并安装
`flutter-hvigor-plugin`。Sync 中的 Pub 命令使用根锁指定的 `pub.flutter-io.cn` 镜像。
更新 `pubspec.yaml` 中的 Git 提交后，先按 `CONTRIBUTING.md` 设置相同的
`PUB_HOSTED_URL`，在仓库根目录运行 `flutter pub get --no-example` 生成新锁；
Sync 的 `--enforce-lockfile` 不会自动更新锁文件。

在 DevEco Studio 中打开本目录并执行 Sync，然后运行或构建 HAP：

- **Debug**：选择 `entry` 模块直接运行。
- **Release**：`Build > Build Hap(s)/APP(s)`。
- 真机部署需在 DevEco 中配置调试签名；签名路径、证书和密码不得提交。

无签名 `build-profile.json5` 基线受版本控制，使 DevEco 在首次 Sync 前即可识别本工程。

## Flutter 依赖

鸿蒙沿用根 `pubspec.yaml` 与根 `pubspec.lock`，不维护独立锁文件。
OH 平台实现通过根 `pubspec.yaml` 的普通 Git 依赖声明：

| 包 | 来源 |
| --- | --- |
| `shared_preferences_ohos` / `image_picker_ohos` / `path_provider_ohos` / `url_launcher_ohos` | CPF `flutter_packages` |
| `sqflite_ohos` | CPF `flutter_sqflite` |
| `package_info_plus_ohos` / `share_plus_ohos` | 独立 [package_info_plus_ohos](https://github.com/HuajiFruit/package_info_plus_ohos) 和 [share_plus_ohos](https://github.com/HuajiFruit/share_plus_ohos) Git 仓库；普通依赖固定提交 |

`open_file_ohos` 作为普通 Git 依赖声明。根 `lib/utils/open_file.dart` 的 `openFile(path)`
在鸿蒙调用该包，其他平台调用官方 `OpenFilex`。

> 根锁包含 WebView 提交 `edd0663cf` 与 `flutter_inappwebview_ohos 1.1.3`，
> 以及上述 OH 平台包、`open_file_ohos`、`image_gallery_saver_plus` 和安全存储 OH 实现。
> 依赖已解析；原生编译与真机功能仍待验证。

## 本地 CPF 源码

`vendor/cpf/` 保存 CPF 仓库的本地工作副本，**不入库**，只用于维护和对照源码。
根依赖不再引用其中的 `package_info_plus_ohos` 和 `share_plus_ohos` 路径。
