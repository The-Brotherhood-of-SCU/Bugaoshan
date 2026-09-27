# 鸿蒙维护约定

- 鸿蒙适配的持久修改限定为 `ohos/`；根工程中与鸿蒙共享的文件（如
  `lib/utils/open_file.dart` 的文件打开入口）除外。
- 原生工程只使用仓库 `ohos/`，DevEco 直接打开这里；不得复制第二个原生工程。
- 原生代码、资源与工程配置保存在 `ohos/`：`AppScope/`、`entry/`、`hvigor/`、
  `hvigorfile.ts`、`oh-package.json5`、`build-profile.json5`。
- `build-profile.json5` 的无签名基线必须受版本控制，使 DevEco 在首次 Sync 前识别工程；
  本机签名路径、证书和密码不得提交。
- 本地 CPF 源码克隆放在 `vendor/cpf/`，**不入库**；换机器需另行取得。
  构建不得自动从云端拉取或覆盖这些副本的源码。
- 根 `pubspec.yaml` 通过普通 Git 依赖声明 OH 平台实现，
  包括 `package_info_plus_ohos`、`share_plus_ohos` 和 `open_file_ohos`。
  鸿蒙沿用根 `pubspec.yaml` 与根 `pubspec.lock`，不维护独立锁文件。
- 根 `pubspec.lock` 以 main 为基线，已将 WebView 相关包同步到 `edd0663cf`，
  包含 `flutter_inappwebview_ohos 1.1.3`、安全存储 OH 实现及其余独立 OH 包。
  锁记录由 Pub 生成；兼容性待构建与真机验证，不手写锁记录。
- 第三方插件直接使用锁定的上游源码，不维护或应用插件补丁。
- 同一分支维护。鸿蒙不提供应用内下载更新包及自安装流程，
  也不接入仅服务自更新的下载通知通道。
- 当前用户负责测试、依赖解析、构建及真机调试；代理只修改代码和文档，不执行这些命令。
- 开发入口见 [README.md](README.md)。
