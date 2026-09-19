# 鸿蒙构建脚本使用说明

[build_ohos.py](build_ohos.py) 准备鸿蒙独立 Flutter 工作目录，并通过仓库原有的 `ohos/`
原生工程构建 HAP。共用 Dart 和资源通过符号链接引用，不复制第二套原生工程。
以下命令均在 **仓库根目录的 PowerShell** 中执行。

## DevEco 构建与调试

在 DevEco Studio 中直接打开仓库的 **`ohos/`** 并执行 Sync。首次 Sync 会自动校验工具链、
建立源码链接、解析鸿蒙依赖、应用插件补丁、生成代码并注册原生插件。完成后选择
Debug 或 Release，再使用 DevEco 的构建、运行或调试功能。该自动准备不编译 HAP。
本机设备及调试签名在这个原生工程中配置。

首次 Sync 必须能从系统 `PATH` 找到 Python 3.10+、Git 和 Flutter OH，并能通过环境变量
或 Flutter 配置定位 HarmonyOS SDK。后续 Sync 会复用已记录的工具路径。

Flutter 工作目录是 `ohos/.flutter-workspace/`，其中没有 `ohos/` 子工程。
原生源码、原生调试改动和 DevEco 配置都直接位于仓库 `ohos/`；无需从其他工程整理回来。
原有 `ohos/build/workspace/run-*` 或 `app/` 不再使用，脚本不移动或删除旧文件。

## 命令行构建

```powershell
# 默认 Release
python ohos/tool/build_ohos.py

python ohos/tool/build_ohos.py --mode debug
python ohos/tool/build_ohos.py --mode profile
python ohos/tool/build_ohos.py --mode release
python ohos/tool/build_ohos.py --help
```

普通构建先完成与 `--prepare-only` 相同的准备，再在根 `ohos/` 调用 Hvigor Sync 和
`assembleHap`。它和 DevEco 使用同一个原生工程及 Flutter 适配入口。

Profile 和 Release 的 Flutter assemble 默认写出 Dart AOT 符号文件：

```text
ohos/.flutter-workspace/build/symbols/<profile|release>/app.ohos-<abi>.symbols
```

Hvigor 已显式传入 `-dSplitDebugInfo` 时保留其路径，不重复注入；Debug 构建不生成这组 AOT
符号。`entry/build-profile.json5` 同时要求原生打包流程不剥离可保留的符号，但它不能恢复
Flutter 预编译产物中已经删除的符号。解析 `libflutter.so` 帧仍需取得与实际 SO 的 Build ID
匹配的未剥离 OH 引擎符号；工具链锁中的上游 engine revision
`42d3d75a56efe1a2e9902f52dc8006099c45d937` 不能单独标识 OH 产物。
本次 SDK 平台缓存不一致的处理见 [Release 启动修复步骤](../docs/audits/release-aot-cache-repair.md)。

最终检查并输出的文件固定为：

```text
ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
```

脚本不再按修改时间挑选任意 HAP。版本来自根 `pubspec.yaml` 的 `version: x.y.z+N`，
通过本地 `local.properties` 注入 Hvigor 的应用配置，随后校验该 HAP 内的 `pack.info`。
准备过程不改写维护中的 `AppScope/app.json5`，也不自动增加版本号。

本次改造尚未执行构建或真机验证；历史功能验收不等于新构建入口已经通过验证。

## 环境与参数

需要 Python 3.10+、Git、正式 Flutter OH，以及配套 DevEco Studio。
在当前 PowerShell 的 `PATH` 中配置 `python`、`git`、`flutter`、`hvigorw`、`ohpm` 和 `node`。
Windows 创建符号链接需要启用开发者模式或使用管理员 PowerShell；脚本不会代为修改系统设置，
权限不足时报告错误，不退回复制共用源码。

当前基线是 Flutter OH `3.41.10-ohos-1.0.1` / Dart `3.11.5`、HarmonyOS API 26，
精确版本、来源及提交以 [工具链锁](../flutter/toolchain.lock.json) 为准。
脚本核对 SDK 正式标签、framework/engine 提交、Dart、DevEco、Hvigor、OHPM 和 Node。
同时校验锁文件中 OH engine/HAR/Dart 提交，以及普通和 product 平台 `.dill` 的 SHA-256。
首次准备和 DevEco 增量构建均执行只读检查；发现不配套缓存会在生成代码/AOT 前停止，
不会静默更新共享 SDK。版本字符串相同不能代替平台文件校验。
应用最低安装 API 20 与编译 SDK 版本不同，见 [API 20 兼容性](../docs/compatibility/api20.md)。

| 参数 | 默认值 | 含义 |
| --- | --- | --- |
| `--flutter-sdk PATH` | 当前 `PATH` 中的 Flutter | 包含 `bin/` 的 Flutter OH SDK 根目录 |
| `--ohos-sdk PATH` | 环境变量或 Flutter 配置 | 包含 `default/openharmony/` 的 DevEco SDK 根目录 |
| `--mode debug|profile|release` | `release` | 命令行 HAP 构建模式 |
| `--prepare-only` | 关闭 | 完成依赖、代码生成及原生入口准备后退出 |
| `--update-lockfile` | 关闭 | 允许重新解析并回写鸿蒙锁文件后退出 |

后两个参数互斥；附加 `--mode` 不会使其编译 HAP。
Flutter 查找顺序为显式参数、`PATH`；HarmonyOS 查找顺序为显式参数、`OHOS_SDK_HOME`、
`HOS_SDK_HOME`、`DEVECO_SDK_HOME`、`flutter config` 的 `ohos-sdk`。
如果 PowerShell 已配置好工具链，直接执行准备或构建命令即可。

```powershell
python ohos/tool/build_ohos.py --prepare-only --flutter-sdk '<Flutter OH SDK 根目录>' --ohos-sdk '<DevEco SDK 根目录>'
```

子进程使用 `ohos/.pub-cache/`，`PUB_HOSTED_URL` 与锁文件一致为 `https://pub.flutter-io.cn`；
`FLUTTER_STORAGE_BASE_URL` 未设置时使用 `https://storage.flutter-io.cn`。
依赖解析需要访问对应 Pub 镜像和 Git 仓库。Git 元数据需要检出目录保留提交和相关标签。

准备时仅在忽略的本地运行配置中记录选中的 SDK、Python、Git 路径和必要镜像设置。
DevEco 后续构建沿用它们，不依赖从图形界面启动的 DevEco 是否继承 PowerShell 环境。
移动仓库、Python 或 SDK 后重新执行准备命令；受版本控制的文件中不保存本机路径。

## 文件归属

| 路径（相对仓库根） | 用途 |
| --- | --- |
| `lib/`、`assets/` | 共用上游源码和资源 |
| `ohos/flutter/overrides/lib/` | 鸿蒙适配后的完整 Dart 文件 |
| `ohos/flutter/l10n/` | 中英文翻译差异条目 |
| `ohos/flutter/pubspec.lock` | 维护中的鸿蒙锁文件 |
| `ohos/.flutter-workspace/lib/` | 真实目录；手写 Dart 逐文件链接，生成 Dart 和合并 ARB 为本地普通文件 |
| `ohos/.flutter-workspace/assets/` | 指向根 `assets/` 的目录链接 |
| `ohos/.flutter-workspace/test/` | 共用测试及 OH 测试模板的文件链接；课程复制和主题转场的上游测试由 `test/ohos/` 模板替代 |
| `ohos/.flutter-workspace/pubspec*.yaml`、`pubspec.lock`、`.dart_tool/` | 鸿蒙独立的 Pub 配置、解析与生成缓存 |
| `ohos/.flutter-workspace/tooling/` | 本地 Flutter framework 补丁副本、SDK Hvigor 适配和插件声明读取器 |
| `ohos/.flutter-workspace/build/` | Flutter 编译输出、补丁处理后的嵌入层 HAR |
| `ohos/.pub-cache/` | 鸿蒙 Pub 缓存及插件补丁应用位置 |
| `ohos/entry/` | 唯一原生模块，DevEco 直接使用 |
| `ohos/entry/build/`、`ohos/build/`、`ohos/.hvigor/` | 正常原生编译输出及缓存 |

`.flutter-workspace/`、`.pub-cache/`、运行配置、插件注册文件和构建输出均不提交。
仍会产生正常的 `build` 目录；取消的是复制原生工程，不是取消编译产物。

已有手写源码改动通过链接直接可见。DevEco 的 Sync/Build 配置阶段调用
[ohos_native.py](ohos_native.py)：检查依赖准备记录、上游基线，刷新增删文件及翻译，
在生成器输入或生成文件变化时执行 `build_runner` 和 `gen-l10n`，并从 OH 解析结果生成原生注册文件。
未变化的生成结果复用。运行配置缺失、路径变化，或 Pub 配置、锁文件、插件补丁变化时，
Sync 会自动重新执行完整准备。`--prepare-only` 保留为手动排查和命令行工作流入口。

不要编辑 `.flutter-workspace/lib/` 下的共享链接来做鸿蒙专用适配，也不要对整个链接目录执行格式化，
因为文件链接的写入会作用于原文件。请直接编辑 `ohos/flutter/overrides/lib/` 中对应的维护文件。
生成器输出只能写入工作目录的普通文件；脚本拒绝链接生成目录或链接已有生成文件。
脚本准备和 Flutter assemble 共享文件锁；同一原生工程仍应避免同时启动两个 Hvigor 构建。

## 原生构建接入

`hvigorconfig.ts` 先通过不依赖已生成工作目录的 `flutter_bootstrap.ts` 完成自举，
再从独立 Flutter 包的 `.flutter-plugins-dependencies` 注入 OH 模块。
`hvigorfile.ts` 使用本地的 SDK Hvigor 适配层，分别传入 Flutter 工作目录和原生工程目录。
插件注册类从解析到的插件 `pubspec.yaml` 读取，不硬编码插件名单或类名。
动态注入模块的 `srcPath` 相对根 `ohos/` 生成并统一使用 `/`；Hvigor 要求它以 `./`、`../`
或 `/` 开头，因此 `.pub-cache/` 这类点开头目录也必须写成 `./.pub-cache/`。

[Hvigor 补丁](../flutter/patches/hvigor/README.md) 校验锁定 SDK 的原文件哈希，仅生成本地适配副本。
它保留 SDK 的任务依赖和资源/AOT 复制流程，增加显式原生路径以及 Python 参数数组执行器，
使带空格的工具路径和参数正确传递。无需修改 SDK 安装目录或安装 SDK 附带的旧 Hvigor 开发依赖。

[嵌入层补丁](../flutter/patches/embedding/README.md) 仍在模式选择后处理 SDK HAR，
放在 `.flutter-workspace/build/flutter-embedding/`，由全部原生模块引用。
SDK 本体保持原样。普通命令行构建不再使用 `flutter build hap`，
因为该命令假定原生项目位于当前 Flutter 包内部的 `ohos/`。

[Flutter framework 诊断补丁](../flutter/patches/framework/README.md) 已停用。
Pub 解析后直接使用锁定 SDK 的 `packages/flutter`，恢复原始 RootIsolateToken 路径。
旧工作区会因工具链锁变化而重新准备；仍指向诊断副本的 package_config 也会被增量入口拒绝。
平台缓存修复与构建验收见 [修复步骤](../docs/audits/release-aot-cache-repair.md)。

## 依赖更新、检查与签名

```powershell
python ohos/tool/build_ohos.py --update-lockfile
python ohos/tool/generate_ohos_dependency_inventory.py
python ohos/tool/generate_ohos_dependency_inventory.py --check
python ohos/tool/build_ohos.py --prepare-only
```

`--update-lockfile` 只回写 `ohos/flutter/pubspec.lock`，不修改根锁。
它不构建 HAP，也不完成完整 DevEco 准备；旧运行配置只保留本机工具路径，
依赖指纹会立即失效，下次 Sync 自动重建完整环境。
普通准备使用 `flutter pub get --no-example --enforce-lockfile`，不自动升级锁文件。

构建脚本不自动执行格式检查、静态分析或测试，相关入口见 [测试说明](../tests/README.md)。
双 SDK 持续检查仍在 [阶段六计划](../docs/sync-plan.md#阶段六建立持续同步检查) 中。

Release 仅表示编译模式。脚本没有签名或发布参数，最后报告 unsigned HAP。
原生 Hvigor 使用仓库中的 `ohos/build-profile.json5`，DevEco 依靠它在 Sync 之前识别工程。
本机签名设置可修改该文件，但签名路径、证书、密码及对应差异不得提交。
若本机已配置签名，原生工具可能同时生成 signed HAP；脚本不将它作为 unsigned 构建结果。
未签名包不能直接分发安装，正式签名、描述文件和覆盖升级应按渠道要求另行验收。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| 缺少 `.flutter-workspace/tooling/flutter-hvigor-plugin` 或运行配置 | 重新 Sync；若自动准备失败，查看 Sync 日志中的首个错误 |
| 依赖配置或解析结果变化 | 重新 Sync，不要在仓库根运行 OH Pub get |
| 上游源码基线不匹配 | 合并对应覆盖文件的上游变化，再更新清单哈希 |
| Windows 无权创建链接 | 启用系统开发者模式，或在管理员 PowerShell 中运行准备命令 |
| 插件 `Cannot find module` | 确认准备成功，DevEco 打开的是仓库 `ohos/`，随后执行 Sync |
| SDK/Python 移动后无法构建 | 更新系统 PATH/环境变量后重新 Sync，或手动执行准备命令 |
| 修改 `hvigorconfig.ts` 或其导入的 `tool/*.ts` 后仍重复旧错误 | Hvigor daemon 可能缓存了已导入模块；在 `ohos/` 执行 `hvigorw --stop-daemon`，或完全退出并重开 DevEco Studio，然后重新 Sync |
| 终端只有 `Schema validate failed`，没有字段详情 | 查看 `.hvigor/outputs/logs/details/details.json` 或最新的 `.hvigor/report/report-*.json`，先处理其中第一个 `instancePath`；这些文件是本地缓存，不提交 |
| HAP 已安装但启动异常 | 保留本次完整日志与构建模式，按真机日志定位；构建完成不代表启动验收通过 |
