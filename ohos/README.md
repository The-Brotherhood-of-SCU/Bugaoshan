# HarmonyOS

本目录是 Bugaoshan 的鸿蒙平台工程，与主工程共享 `lib/` 和资源。
通用开发流程见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 环境与构建

- 安装支持 OHOS 的 CPF Flutter 和 DevEco Studio；当前最低 API 20、目标 API 26。
- SDK 路径按 `CPF_FLUTTER_ROOT` → `ohos/local.properties` 的 `flutter.sdk`
  → `FLUTTER_ROOT` 查找。包装脚本会校验是否为 CPF SDK。
- Windows 需开启开发者模式以创建符号链接；插件路径过长时启用 Git `core.longpaths`。

在仓库根目录执行：

```sh
node ohos/flutterw.cjs precache --ohos
node ohos/flutterw.cjs pub get --no-example
node ohos/flutterw.cjs gen-l10n
node ohos/flutterw.cjs build hap --release --no-codesign
```

HAP 输出到 `ohos/.flutter-workspace/build/ohos/hap/`。
DevEco 直接打开 `ohos/`，Sync 会使用同一包装入口准备 Flutter 依赖。
Hvigor 通过 `HVIGOR_HOME`、DevEco Node 的相邻目录或 PATH 查找；
Java 使用 `JAVA_HOME` 或 DevEco 自带的 `jbr`。

## 与主工程的关系

- `.flutter-workspace/` 是忽略入库的生成目录，通过链接共享源码，
  并由 `flutter/main.dart` 注入 `OhosPlatformAdapter` 后调用主入口。
- 本目录的 Pub 清单和锁仅用于 CPF；公共依赖或资源变化时需同步审核两份清单。
  显式解析依赖只更新鸿蒙锁，构建自动解析使用 `--enforce-lockfile`。
- 应用版本只维护根 `pubspec.yaml`，包装脚本自动注入构建工作目录和原生配置。
- 不直接在根目录执行 CPF 命令，也不在 `ohos/` 直接执行 `flutter pub get`。
  代码生成和本地化命令会更新共享源码；依赖解析不会改写根清单和锁。

## 本机签名

`build-profile.json5` 保留无签名基线。将 DevEco 生成的签名配置放入
被 Git 忽略的 `ohos/.sign/sign-config.json5`，使用严格 JSON：

```json
{
  "signingConfigs": [],
  "products": { "default": "本机签名配置名称" }
}
```

`local-signing.ts` 在构建时合并配置；DevEco 写入工程的同名配置和产品选择优先。
提交前将本机签名移回 `.sign/` 并恢复无签名基线，不提交私钥、证书、密码或路径。
代理提醒、实况窗等开放能力需在最终签名 Profile 中具有对应权益。

## 检查

```sh
node --test ohos/test/*.test.cjs
node ohos/flutterw.cjs analyze
node ohos/flutterw.cjs test
```

`ohos/test/platform_services_test.dart` 需另外以绝对路径传给包装入口的 `test` 命令。
文件选择、相册保存、分享、卡片、提醒和实况窗需真机验证。
提醒额度由 Dart 根据设备运行时 API 选择：API 26 及以上 64 条，否则 30 条；
读取失败保留已有排期并在后续重试。动态图标要求 API 26+。
