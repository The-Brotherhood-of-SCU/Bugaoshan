# HarmonyOS 开发指南

本目录包含不高山上（Bugaoshan）的 HarmonyOS 原生工程、Flutter OH 适配配置和开发工具。
鸿蒙端与其他平台在同一分支维护。编译工程通过文件链接共用根目录的业务代码，
有适配的路径链接 `flutter/overrides/lib/` 中的完整 Dart 文件。

上游与 Flutter OH 使用不同的 SDK 和依赖锁。构建鸿蒙版本时，请使用本目录的构建入口，
由脚本加载 `ohos/flutter/` 中的配置，保持根目录的源码、依赖锁和生成文件供上游环境使用。

## 环境要求

| 工具 | 当前要求 |
| --- | --- |
| Python | 3.10 或更新版本，构建脚本仅依赖标准库 |
| Git | 可通过 `PATH` 调用 |
| Flutter OH | `3.41.10-ohos-1.0.1` 正式版，配套 Dart `3.11.5` |
| HarmonyOS SDK | API 26，`26.0.0.105` Release |
| DevEco Studio | `26.0.0.821`，使用配套 Node、OHPM 和 Hvigor |

精确版本、Flutter 仓库来源及 framework/engine 提交见
[toolchain.lock.json](flutter/toolchain.lock.json)。构建脚本会校验这些信息，
仅支持锁定的正式工具链。

准备和 DevEco 增量构建还会核对 OH 产物提交与两份平台 `.dill` 的 SHA-256，
防止 SDK 版本相同但平台缓存不配套造成 Release 原生函数地址截断。
检查失败时按 [缓存修复步骤](docs/audits/release-aot-cache-repair.md)刷新 SDK，再重新准备和构建。

应用最低安装版本配置为 HarmonyOS API 20，编译和目标 SDK 使用 API 26。
API 20 的能力差异及验证范围见 [兼容性说明](docs/compatibility/api20.md)；
动态图标切换采用 API 26 接口，低版本点击入口时显示不支持提示。

API 20 x86_64 模拟器的 Debug 白屏排查及本次改动见
[启动白屏记录](docs/audits/api20-debug-white-screen.md)：按当前维护范围不处理 x86_64
专属缺库问题；保留原始 Dart 异常诊断，真机若同样失败再据调用栈定位。

ARM64 真机“启动失败”截图已通过匹配符号定位到课表行高的数值类型转换；
[修复与验收说明](docs/audits/startup-preferences-type-mismatch.md)记录了四项浮点设置的
兼容读取和启动报告改进。重新构建后覆盖安装即可验证，无需清空设置。

以下命令以 PowerShell 为例。在当前终端的 `PATH` 中配置 `python`、Flutter OH 的 `flutter`、
`git`，以及 DevEco 配套的 `hvigorw`、`ohpm` 和 `node`。通过 `DEVECO_SDK_HOME`，
或 `flutter config --ohos-sdk <SDK目录>` 指定 HarmonyOS SDK。
依赖解析需要能够访问配置中的 Pub 镜像和 Git 仓库。

脚本继承终端环境，也支持通过 `--flutter-sdk` 和 `--ohos-sdk` 参数指定 SDK 根目录。
本机路径和签名材料不应写入受版本控制的文件。

Windows 需要启用系统开发者模式，或由管理员 PowerShell 创建符号链接。
脚本不会修改系统设置，也不会在链接失败时退回复制共用源码。

## 构建

完整参数、执行阶段、产物与签名说明及常见问题见 [构建脚本使用说明](tool/README.md)。

全新克隆不需要复制旧目录中的 `.flutter-workspace/`、`.pub-cache/`、`local.properties`
或任何构建产物。按上述环境要求安装工具，在仓库根目录显式指定本机 SDK 完成首次准备：

```powershell
python ohos/tool/build_ohos.py --prepare-only --flutter-sdk '<Flutter OH SDK 根目录>' --ohos-sdk '<DevEco SDK 根目录>'
```

路径只记录到被忽略的本地运行配置，不写入版本库。若提示平台缓存不匹配，先使用所选的
同一套 Flutter OH SDK 执行 `flutter precache --ohos --universal --force`，再重新准备。
新克隆中的原生工程使用无签名基线，真机签名由 DevEco 在本机配置。

DevEco Studio 可以直接打开仓库中的 `ohos/` 并执行 Sync。首次 Sync 会自动完成 Flutter OH
环境准备；运行配置缺失、仓库或 SDK 路径变化、依赖声明或锁文件变化时也会自动重新准备。
需要命令行构建或排查准备过程时，仍可在仓库根目录执行：

```powershell
# 可选：手动执行与首次 DevEco Sync 相同的准备，不编译 HAP
python ohos/tool/build_ohos.py --prepare-only

# 构建 Debug HAP
python ohos/tool/build_ohos.py --mode debug

# 构建 Release HAP
python ohos/tool/build_ohos.py --mode release
```

Flutter 工作目录固定在 `ohos/.flutter-workspace/`，原生工程直接使用仓库 `ohos/`。
工作目录没有第二个 `ohos/` 子工程，不创建 `run-*` 或复制共用 Dart 和资源。脚本依次完成：

1. 校验工具链和上游源码基线，建立或更新共用代码、鸿蒙覆盖文件及资源链接。
2. 在本地文件中合并翻译、准备独立依赖配置，检查代码生成路径隔离。
3. 严格解析依赖，应用插件补丁并检查 OH 插件注册。
4. 生成 Dart 代码、本地化资源和根原生工程的插件注册文件。
5. 普通构建在仓库 `ohos/` 调用 Hvigor Sync 和 `assembleHap`，并校验 HAP 版本。

DevEco Sync 会自动完成前四步；`--prepare-only` 是对应的手动入口，完成后退出且不编译 HAP。
两个入口都需要上表中的完整工具链。首次 Sync 需能从系统 `PATH` 找到 Python、Flutter OH
和 Git，并能定位 HarmonyOS SDK；成功后会复用本地记录的工具路径。
补丁上下文、依赖锁或工具链不匹配时，脚本会停止并报告原因。

应用版本来自根 `pubspec.yaml`，通过本地属性注入 Hvigor，脚本报告的 unsigned HAP 位于
`ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`；
真机部署需在 DevEco 中配置调试签名，正式发布与覆盖升级流程见 [同步计划](docs/sync-plan.md)。

仓库直接提供 [build-profile.json5](build-profile.json5)，使 DevEco 在首次 Sync 之前就能识别这是
HarmonyOS/Hvigor 工程。本机签名可由 DevEco 写入该文件，但签名路径、证书和密码不得提交；
`local.properties` 中的 Flutter 路径和应用版本由准备入口更新。

## DevEco 真机调试

1. 在 DevEco Studio 中打开仓库原有的 **`ohos/`**，执行 Sync。
2. 等待 Sync 自动准备 Flutter OH 工作目录、依赖、补丁、生成代码和插件注册。
3. 选择构建模式、配置设备与调试签名，然后使用 DevEco 的运行和调试功能。

根 `ohos/` 的 Hvigor 入口读取 `.flutter-workspace/` 中的源码和依赖，原生源码直接参与编译。
原生改动直接维护在这个工程中，无需从生成工程中迁回。

已有手写 Dart 文件和资源的修改通过链接直接可见。DevEco 的 Sync/Build 配置阶段检查上游基线、
更新链接和翻译，并在输入变化时更新生成代码。依赖声明、锁或插件补丁变化后，下次 Sync 会自动重新准备。
编辑链接文件会修改它指向的维护文件；鸿蒙适配请直接编辑 `flutter/overrides/lib/`，
不要在整个链接工程上运行 `dart format lib`，以免格式化共用源码。
准备与 Flutter 编译共享文件锁；同一原生工程不要同时启动两个 Hvigor 构建。
原有 `run-*` 工程不再更新，也不会被脚本自动删除。本次入口改造的构建与真机验收尚待执行。

修改 `hvigorconfig.ts` 或它导入的 `tool/*.ts` 后，已运行的 Hvigor daemon 可能继续使用内存中的旧模块。
如果 Sync 仍重复修改前的配置错误，请在 `ohos/` 中执行 `hvigorw --stop-daemon`，或完全退出并重开
DevEco Studio，再重新 Sync。终端只显示 `Schema validate failed` 时，可在忽略的本地目录
`.hvigor/outputs/logs/details/details.json` 或最新的 `.hvigor/report/report-*.json` 中查看完整的
`instancePath` 和校验规则。更多排查项见 [构建脚本使用说明](tool/README.md#常见问题)。

## 目录结构

```text
ohos/
├── README.md                          # 开发入口
├── AGENTS.md                          # 自动化编码工具的维护约定
├── AppScope/                          # 应用标识、版本与图标
├── entry/src/main/                    # 原生入口、平台通道、课表卡片与资源
├── entry/src/ohosTest/                 # DevEco 原生测试
├── hvigor/                            # Hvigor 配置
├── hvigorfile.ts                      # 原生构建任务
├── hvigorconfig.ts                    # Flutter 原生模块注入
├── oh-package.json5                   # 鸿蒙工程依赖
├── build-profile.json5                # DevEco 工程识别与基础构建配置
├── flutter/
│   ├── pubspec_dependencies.json      # 鸿蒙依赖增减配置
│   ├── pubspec_overrides.yaml         # 鸿蒙依赖覆盖
│   ├── pubspec.lock                   # 鸿蒙独立依赖锁
│   ├── toolchain.lock.json            # 正式工具链版本与提交
│   ├── overrides/lib/                # 适配后的完整 Dart 文件
│   ├── l10n/                         # 鸿蒙新增或覆盖的翻译条目
│   ├── source-manifest.json          # 文件覆盖及上游基线
│   └── patches/
│       ├── plugins/                   # 第三方插件补丁与版本约束
│       ├── embedding/                 # Flutter OH HAR 补丁与源码哈希
│       └── hvigor/                    # 显式原生工程路径适配与 SDK 源码哈希
├── tool/                              # 构建、源码组装、插件补丁与依赖清单脚本
├── tests/
│   ├── python/                        # 构建与补丁脚本测试
│   └── flutter/                       # OH 专项测试模板
├── docs/
│   ├── sync-plan.md                   # 同步计划与验证进度
│   ├── flutter-adaptation.md          # 适配机制
│   ├── dependencies/                 # 依赖说明、完整锁表与替代矩阵
│   ├── compatibility/                # 系统版本兼容性
│   ├── audits/                       # 代码审查与问题排查记录
│   └── phases/                       # 各阶段实现与验收说明
├── .flutter-workspace/                # 本地 Flutter 包，不含原生工程，不提交
│   ├── lib/、assets/、test/            # 共用文件链接及独立生成代码
│   ├── .dart_tool/                    # 鸿蒙解析与生成缓存
│   ├── tooling/                       # 本地 Hvigor 适配和注册工具
│   └── build/                         # Flutter 编译结果与嵌入层 HAR
├── .pub-cache/                        # 鸿蒙专用 Pub 缓存，不提交
└── build/                             # 正常原生构建输出，不提交
```

DevEco 缓存、`oh_modules/`、`node_modules/`、模块构建目录及本机配置由 `.gitignore` 管理。
链接清单只管理 Flutter 工作目录中的文件；不会复制原生工程。仍会产生正常的编译输出。

## 测试与验证

在仓库根目录运行 Python 脚本测试：

```powershell
python -m unittest discover -s ohos/tests/python -p "test_*.py"
```

OH 专项 Flutter 测试以 `*.dart.template` 维护，准备工程时会链接为 `test/ohos/*.dart`。
在准备完成的 `ohos/.flutter-workspace/` 中，使用同一 Flutter OH SDK 运行：

```powershell
dart analyze lib
flutter test --no-pub test/ohos/platform_adapters_test.dart test/webview_notice_handlers_test.dart
flutter test --no-pub test/ohos/course_duplicate_test.dart test/ohos/course_copy_mode_test.dart test/ohos/theme_page_transitions_test.dart
```

测试范围及原生测试入口见 [测试说明](tests/README.md)。平台通道测试使用模拟实现；
插件、WebView、数据库或认证存储发生变化时，还需要在对应系统版本的真机上回归。
提交变更时请记录源码提交、SDK 版本、检查命令和结果，并注明未验证的项目。

双 SDK 持续检查入口仍在计划中，当前命令不代表完整的跨平台验收；进度见
[持续同步检查](docs/sync-plan.md#阶段六建立持续同步检查)。

## 贡献与上游同步

鸿蒙适配的修改集中在 `ohos/`：原生功能修改对应 ArkTS 源码和资源，共享 Dart 适配保存为
[完整覆盖文件](flutter/overrides/README.md)，翻译保存为 [ARB 条目](flutter/l10n/README.md)。
构建入口按 [源码清单](flutter/source-manifest.json) 检查上游基线，再选择链接和合并翻译；
上游对应文件变化时先合并适配，再更新基线。Flutter 工作目录不作为维护源码提交。

源码同步检查可独立执行，无需 Flutter 或原生工具链：

```powershell
python ohos/tool/ohos_sources.py --check
```

调整插件版本时，更新鸿蒙依赖配置，并显式重新生成鸿蒙锁文件：

```powershell
python ohos/tool/build_ohos.py --update-lockfile
python ohos/tool/generate_ohos_dependency_inventory.py
```

审查锁文件、Git 提交和补丁差异，随后重新执行 `--prepare-only` 和相关检查。
依赖清单输出到 `ohos/docs/dependencies/lock-inventory.md`，应由脚本生成。
普通构建严格使用现有锁文件，不自动升级依赖。

## 参考文档

- [Flutter 适配机制](docs/flutter-adaptation.md)：源码覆盖、翻译合并、插件和嵌入层补丁的工作方式。
- [依赖替代矩阵](docs/dependencies/replacements.md)与[完整依赖对照](docs/dependencies/lock-inventory.md)。
- [API 20 兼容性说明](docs/compatibility/api20.md)。
- [通知页与 WebView 排查记录](docs/audits/notice-webview.md)。
- [Release 启动 SIGSEGV 修复步骤](docs/audits/release-aot-cache-repair.md)：平台缓存 ABI 错位、哈希校验、重建与真机验收。
- [课表卡片、动态图标和设备信息](docs/phases/phase5.md)。
- [同步计划](docs/sync-plan.md)：阶段进度、验证记录和发布安排。
