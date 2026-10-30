# HarmonyOS 构建与维护

标准 Flutter 与 CPF Flutter 共用根 `lib/` 和资源，各自解析依赖。
DevEco Studio 直接打开本目录；命令行通过 `flutterw.cjs` 使用 CPF Flutter。

## 构建边界

| 项目 | 标准 Flutter | CPF Flutter / HarmonyOS |
| --- | --- | --- |
| 命令工作目录 | 仓库根目录 | `ohos/.flutter-workspace/`（包装脚本准备） |
| 依赖清单 | 根 `pubspec.yaml` | `ohos/pubspec.yaml` |
| 依赖锁 | 根 `pubspec.lock` | `ohos/pubspec.lock` |
| Pub 工程状态 | 根 `.dart_tool/`、插件列表 | 工作目录内独立 `.dart_tool/`、插件列表 |
| 启动入口 | 根 `lib/main.dart` | `ohos/flutter/main.dart` → 共享根入口 |
| 原生工程 | 各平台目录 | 本目录，工作目录仅创建链接 |
| CI | 现有上游工作流 | 无专用工作流，按本文命令在本地检查与构建 |

包装入口不会修改根清单、根锁或根插件列表；显式 `pub get/upgrade/downgrade`
成功后只将工作目录的锁写回 `ohos/pubspec.lock`。构建时隐式准备依赖使用
`--enforce-lockfile`，不能默默升级锁。公共依赖、版本或资源声明发生变更时，
维护者应同步审核两份清单，分别用相应 SDK 生成锁，不手改锁记录。
包装入口会拒绝两份清单的应用版本不一致。

## 环境与入口

- 标准工程使用上游要求的 Flutter 3.44+。
- 鸿蒙使用本机配置的 CPF Flutter，已验证的版本见本文“验证”部分。
- 当前原生配置最低 API 20、目标 API 26；本机需安装对应的 DevEco SDK。
- Windows 需要开启开发者模式，以便创建文件符号链接；目录使用 junction。
  CPF 多插件仓库路径较长时，需启用 Git 的 `core.longpaths`。

SDK 路径选择顺序：`CPF_FLUTTER_ROOT` → `ohos/local.properties` 中的
`flutter.sdk` → `FLUTTER_ROOT`。包装脚本检查 SDK 是否包含 OHOS 工具，
不会默默调用 PATH 中的标准 Flutter。DevEco 与命令行共用此选择，并自动将
本地 `flutter.sdk`、版本名和版本号写入忽略入库的 `local.properties`。

标准平台仍在仓库根目录操作：

```sh
flutter pub get
flutter gen-l10n
flutter build apk --release
```

鸿蒙在仓库根目录操作（也可进入 `ohos/` 后使用 `node flutterw.cjs ...`）：

```sh
# 先将 CPF_FLUTTER_ROOT 或 local.properties 配置为本机 CPF SDK。
node ohos/flutterw.cjs precache --ohos
node ohos/flutterw.cjs pub get --no-example
node ohos/flutterw.cjs gen-l10n
node ohos/flutterw.cjs build hap --release --no-codesign
```

HAP 输出在 `ohos/.flutter-workspace/build/ohos/hap/`。DevEco Sync 调用同一包装
逻辑，准备工作目录并以 `--enforce-lockfile` 校验依赖。不要在 `ohos/` 直接
执行 `flutter pub get`，也不要在根目录直接执行 CPF 的 HAP 构建。
包装入口拒绝 `create`、`clean` 及非 HAP 构建，避免这些命令修改共享平台目录。

`hvigorw` / `hvigorw.bat` 将 CPF 的原生构建转交给已安装的 Hvigor，并将工作目录
归一为真实 `ohos/` 路径，避免 Hvigor 拒绝通过 junction 访问的模块。启动脚本从
`HVIGOR_HOME`、DevEco Node 的相邻目录或 PATH 查找 Hvigor；将 `JAVA_HOME/bin`
加入子进程 PATH，没有配置时尝试使用 DevEco 自带的 `jbr`，供 HAP 打包工具调用。

## 共享源码与平台实现

工作目录的 `lib/` 按项链接根源码；`upstream_main.dart` 链接根 `lib/main.dart`，
`ohos_bootstrap/` 链接本目录的 `flutter/`，生成的 `lib/main.dart` 只负责转调。
根目录不增加平台依赖包，也不需要复制一份业务源码。

`OhosPlatformAdapter` 在调用共享启动流程之前注入平台实现：

- 文件打开使用 `open_file_ohos`，统一返回共享 `OpenResult`。
- 云打印文件选择通过原生 `bugaoshan/file_picker` 通道打开系统文档选择器，
  支持多选；将所选 URI 复制为应用缓存中的本地文件供打印队列读取，保留原文件名。
  不同来源的同名文件使用独立目录，取消选择不向队列添加文件。
- 文件保存通过原生 `bugaoshan/file_save` 通道；图片保存使用 OHOS 相册插件。
- 课表图片导出在 OHOS 显示入口，沿用共享渲染、保存相册和分享流程。
- 开发页设备信息通过 `bugaoshan/environment_info` 读取系统版本、API 等级、
  机型和 ABI 等公开信息，不读取设备唯一标识。
- 日志与已下载附件的目录按钮在应用内显示文件列表，支持刷新、打开和分享，
  不向文件管理器传递私有目录 URI。分享使用独立缓存副本，避免日志轮转影响接收方。
- 原生开关通过 CPF `OhosView` 创建。共享 Apple 开关/滑块保持原实现；OHOS
  没有原生滑块实现时使用 Flutter 控件。
- 提醒选择 OHOS 通道及 30 条容量预算；课表卡片、动态图标和课程实况窗接入已有原生实现。
- OHOS 实况窗在恢复前台时重查权限，并遵守地点隐私设置；相关系统权益仍需真机验证。
- 日历维持打开外部应用处理 ICS 的方式，不申请日历读写权限；打开成功不代表已导入。
- 上游应用内安装更新的平台范围保持原样，不向 OHOS 加入 APK 下载或自安装通道。

共享源码不导入 OHOS 插件、不引用 `TargetPlatform.ohos`；标准分析排除 `ohos/`。
CPF 工作目录中的 `lib/ohos_bootstrap/` 则会纳入该工程的分析。
代码生成与本地化生成会写入共享源码，这是显式生成命令的预期行为；依赖锁仍独立。

## 本机签名

`build-profile.json5` 保留可入库的无签名工程基线。
本机签名使用 `.sign/sign-config.json5`（Git 忽略），结构如下：

```json
{
  "signingConfigs": [],
  "products": { "default": "本机签名配置名称" }
}
```

将 DevEco 生成的签名配置数组保存到 `signingConfigs`，产品到签名名称的映射保存在
`products`。文件采用严格 JSON 语法。`local-signing.ts` 通过 Hvigor 的公开配置 API
在内存中合并签名，CPF 的签名预检也识别这个文件；无本机文件时按无签名工程处理。
DevEco 写入工程的同名签名配置、显式产品签名选择优先于本机文件，防止重新生成
Profile 后仍被旧配置覆盖。代理提醒等开放能力申请通过后，还需在 AGC 启用能力、
重新生成带权益的 Profile 并重新签名安装；工程中的 `capabilities` 声明不能证明
最终安装包已经获得权益。排查时应检查签名 HAP 内嵌的 Profile。
若在 DevEco 的签名 UI 中重新生成配置，提交前仍需
将配置移到本机文件并恢复基线；不要提交私钥、证书、密码或签名路径。

## 验证

维护约定默认由用户负责依赖解析、测试、构建和真机调试；用户明确要求代理执行时
以该指令为准。CPF 的 release HAP 已在 Windows / API 26 上构建通过，使用
Flutter `3.44.9+ohos-0.0.1-canary1`（`744cbb4f08`）/ Dart 3.12.2。
标准 Flutter 构建及真机运行仍需单独验收。可分别执行：

```sh
# 标准 Flutter，在根目录；依赖及本地化准备后执行。
flutter test test/platform_adapter_test.dart
dart analyze --fatal-infos

# 仅检查工作目录隔离逻辑，不运行 Flutter；Windows 仍需符号链接权限。
node --test ohos/test/*.test.cjs

# CPF；先完成上面的依赖与本地化准备。
node ohos/flutterw.cjs analyze
node ohos/flutterw.cjs test test/platform_adapter_test.dart
# OHOS 适配器通道测试位于原生工程目录，需传入绝对路径。
node ohos/flutterw.cjs test /absolute/path/to/Bugaoshan/ohos/test/platform_services_test.dart
node ohos/flutterw.cjs build hap --release --no-codesign

# 两套构建后，根依赖文件应保持无差异。
git diff --exit-code -- pubspec.yaml pubspec.lock
```

仓库不提供 OHOS 专用 CI/CD 工作流；上述检查和 HAP 构建通过本地命令执行。
上游原有 CI 检查、各平台构建和发布流程保持原样。

文件选择、相册保存、分享及卡片/提醒/实况窗的系统交互还需真机验收。
提醒维持 30 条排程预算；动态图标要求 API 26+，实况窗依赖系统授权与 TIMER 场景权益。
