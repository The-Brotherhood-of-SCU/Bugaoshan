# HarmonyOS

遵循根目录 [AGENTS.md](../AGENTS.md)，本文件仅补充鸿蒙工程约定。

- `ohos/` 是唯一原生工程；DevEco 直接打开本目录。
- CPF 命令通过 `flutterw.cjs` 使用生成的 `.flutter-workspace/`，
  共享根源码和资源，不在根目录用 CPF 解析依赖或构建。
- 鸿蒙依赖使用本目录的 `pubspec.yaml` / `pubspec.lock`，不覆盖根依赖文件。
  应用版本只维护根 `pubspec.yaml`，由包装脚本注入构建配置。
- OHOS 插件导入和 `OhosView` 留在 `flutter/`；共享代码通过
  `PlatformAdapter` / `isOhos` 调用，不引用 `TargetPlatform.ohos`。
- `build-profile.json5` 保留无签名基线；本机签名放在被忽略的
  `.sign/sign-config.json5`，不提交证书、私钥、密码或本机签名路径。
- 第三方插件使用锁定的上游源码，不在本地维护插件补丁。
- 构建、签名和检查命令见 [README.md](README.md)。
