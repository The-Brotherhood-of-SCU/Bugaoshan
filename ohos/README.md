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

在 DevEco Studio 中打开本目录并执行 Sync，然后运行或构建 HAP：

- **Debug**：选择 `entry` 模块直接运行。
- **Release**：`Build > Build Hap(s)/APP(s)`。
- 真机部署需在 DevEco 中配置调试签名；签名路径、证书和密码不得提交。

无签名 `build-profile.json5` 基线受版本控制，使 DevEco 在首次 Sync 前即可识别本工程。

## Flutter 依赖

鸿蒙沿用根 `pubspec.yaml` 与根 `pubspec.lock`，不维护独立锁文件。
OH 平台实现通过根 `pubspec.yaml` 的 `dependency_overrides` 声明：

| 包 | 来源 |
| --- | --- |
| `shared_preferences_ohos` / `image_picker_ohos` / `path_provider_ohos` / `url_launcher_ohos` | CPF `flutter_packages` |
| `sqflite_ohos` | CPF `flutter_sqflite` |
| `package_info_plus_ohos` / `share_plus_ohos` | `vendor/cpf/` 本地工作副本 |

`open_file_ohos` 作为普通 Git 依赖声明。根 `lib/utils/open_file.dart` 的 `openFile(path)`
在鸿蒙调用该包，其他平台调用官方 `OpenFilex`。

> 根锁已在 main 基线上将 WebView 相关包同步到 `a3880161e`，
> 包含 `flutter_inappwebview_ohos 1.1.3`。上述 OH 包及 `image_gallery_saver_plus`
> 仍未解析进根锁，严格校验会失败；兼容性待后续处理。

## 本地 CPF 源码

`vendor/cpf/` 保存三个 CPF 仓库工作副本（`open_filex`、
`package_info_plus`、`share_plus`），**不入库**，换机器需另行取得。
其中 `package_info_plus`、`share_plus` 两个独立包被根 `pubspec.yaml` 以 path 引用。
