# 鸿蒙维护约定

- 鸿蒙适配的持久修改限定为 `ohos/`；根工程中与鸿蒙共享的文件（如
  `lib/utils/open_file.dart` 的文件打开入口）除外。
- 原生工程只使用仓库 `ohos/`，DevEco 直接打开这里；不得复制第二个原生工程。
- 原生代码、资源与工程配置保存在 `ohos/`：`AppScope/`、`entry/`、`hvigor/`、
  `hvigorfile.ts`、`oh-package.json5`、`build-profile.json5`。
- `build-profile.json5` 的无签名基线必须受版本控制，使 DevEco 在首次 Sync 前识别工程；
  本机签名放在忽略入库的 `.sign/sign-config.json5`，由 `local-signing.ts` 在内存中装配，
  CPF 的签名检查也识别此路径。签名路径、证书和密码不得提交。
- DevEco 重新生成的同名签名配置、显式产品签名选择优先于旧本机配置；
  迁回 `.sign/` 时保留工程 `capabilities` 声明。开放能力是否生效需核对最终
  签名包中的 Profile，不能仅根据工程已声明能力或 AGC 已申请推断。
- 本地 CPF 源码克隆放在 `vendor/cpf/`，**不入库**；换机器需另行取得。
  构建不得自动从云端拉取或覆盖这些副本的源码。
- `ohos/pubspec.yaml` 通过普通 Git 依赖声明 OH 平台实现，
  包括 `package_info_plus_ohos`、`share_plus_ohos` 和 `open_file_ohos`。
- 鸿蒙独立维护 `ohos/pubspec.yaml` 与 `ohos/pubspec.lock`；根清单和锁用于原版 Flutter。
- 根 `lib/platform/platform_adapter.dart` 提供标准 Flutter 默认实现，不新增上游依赖。
  `flutter/main.dart` 在业务启动前注入 `OhosPlatformAdapter`；`OhosView`、
  `open_file_ohos`、`image_gallery_saver_plus` 的导入只允许出现在 `ohos/`。
  不再维护两份同名控件包；共享源码通过适配器调用平台能力。
- 云打印文件选择与开发页设备信息通过适配器转交本应用原生通道；
  所选文档 URI 必须先复制到应用缓存后交给 Dart，不能当作普通文件路径使用。
  日历保持外部 ICS 导入，不添加日历读写权限或原生直写逻辑。
- 日志与附件的目录入口使用应用内 `AppDirectoryPage` 浏览普通文件；
  不将应用私有目录作为 `file://` URL 打开。分享先复制到独立缓存文件，
  保留副本供接收方异步读取，交由缓存清理回收。
- `ohos/flutterw.cjs` 在忽略入库的 `ohos/.flutter-workspace/` 中准备 Flutter 构建入口，
  按项链接根 `lib/`、资源及原有 `ohos/`，不复制业务源码或第二个原生工程。
  工作目录 `lib/main.dart` 是生成的启动桥；`upstream_main.dart` 链接根入口，
  `ohos_bootstrap/` 链接 `ohos/flutter/`。根入口不改写。
- DevEco Sync 和 Flutter 构建均使用该工作目录；依赖更新通过
  `node ohos/flutterw.cjs pub get --no-example` 完成，成功后将锁写回 `ohos/pubspec.lock`。
- 鸿蒙锁从现有已解析锁原样迁入，保留 WebView 提交 `edd0663cf`，
  包含 `flutter_inappwebview_ohos 1.1.3`、安全存储 OH 实现及其余独立 OH 包。
  锁记录由 Pub 生成；兼容性待构建与真机验证，不手写锁记录。
- 第三方插件直接使用锁定的上游源码，不维护或应用插件补丁。
- 不在共享代码引用 `TargetPlatform.ohos`，也不穷举 SDK 的平台枚举；
  使用 `isOhos`（由启动适配器提供），以兼容标准 Flutter 和 CPF 的枚举差异。
- 包装入口只执行 CPF SDK；本机可用 `CPF_FLUTTER_ROOT` 指定路径。
  根清单/锁不会由包装入口写入；隐式依赖准备使用 `--enforce-lockfile`。
- 同一分支维护。鸿蒙不提供应用内下载更新包及自安装流程，
  也不接入仅服务自更新的下载通知通道。
- 默认由用户负责测试、依赖解析、构建及真机调试；用户明确要求代理执行时，
  以当次指令为准，构建仍只能使用独立 CPF 工作目录，不改根清单和锁。
- 公共 CI 沿用上游原版 Flutter，不新增 OHOS 专用 CI/CD 工作流。
  CPF 检查与构建使用本地包装入口；上游构建和发布流程保持原样。
- 开发入口见 [README.md](README.md)。
