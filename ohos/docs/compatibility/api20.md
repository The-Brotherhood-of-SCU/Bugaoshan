# API 20 兼容性审查

日期：2026-09-16。目标是让现有 HAP 在 HarmonyOS API 20 设备上运行。
初次审查读取了配置、源码、SDK 接口声明及已有 HAP/ELF 元数据。
随后按用户要求将最低安装版本提高到 API 20，并补充两个降级路径的实际界面表现。
未执行补丁应用、构建或测试，尚未生成采用新门槛的 HAP。

## 结论

- 当前受版本控制的配置将最低安装版本设为 `6.0.0(20)`。
  已有 HAP 仍是修改前的 API 18 门槛；新构建将不再支持 API 18/19 安装。
- 已审查的应用原生代码、插件关键路径及 Flutter 嵌入层未发现必须在 API 20 调用、且没有保护的更高版本接口。
- 动态图标在 API 20 上显示不支持；当前 Flutter OH 的系统自动填充桥接在 API 20 上跳过。
  当前登录页本来就未启用该桥接，应用自己的记住密码、回填和自动登录路径继续保留。
- 初次检查的 HAP 夹带了一份 Linux/glibc 版 SQLite 动态库，当前鸿蒙数据库路径没有发现对它的加载。
  后续启动清理已从 OH 隔离依赖图排除它的来源；`entry/libs`、旧副本与旧 HAP 仍是旧生成物。
- 当前结论为“具备 API 20 兼容基础，静态审查未发现已确认的启动阻断”，尚不能标记 API 20 真机验收通过。

第五阶段通过记录来自用户此前使用的环境，不自动扩展为 API 20 实测记录。

2026-09-18 收到 API 20 x86_64 模拟器 Debug 白屏日志，包含 WebView 原生库缺失和
Dart `Stack Overflow`。后续改动及复测步骤见
[白屏排查记录](../audits/api20-debug-white-screen.md)。这项运行失败尚未关闭，
不能将前面的静态兼容基础理解为 API 20 模拟器或真机验收通过。

## 版本配置与产物

当前维护配置与修改前产物应分开记录。抽查的旧副本为
`build/workspace/run-oek1h7h2/ohos/entry/build/default/outputs/default/`，
其中 signed/unsigned HAP 的相关元数据一致：

| 项目 | 当前值 | 含义 |
| --- | --- | --- |
| 当前配置/模板的 `compatibleSdkVersion` | `6.0.0(20)` | 后续新构建最低运行 API 20 |
| 旧 HAP `minAPIVersion` | `50100018` | 修改前的 API 18 产物，未重新构建 |
| `targetSdkVersion` / HAP `targetAPIVersion` | `26.0.0` / `260000026` | 目标行为版本，不能单凭此值判定最低运行系统 |
| HAP `compileSdkVersion` | `26.0.0.105` | 当前构建所用 SDK |
| HAP 应用版本 | `2.5.1` / `20501` | 抽查的已有产物版本 |
| 设备类型 | `phone`、`tablet` | 当前应用声明的设备范围 |

依据：`ohos/build-profile.json5`、`ohos/entry/src/main/module.json5` 及旧 HAP 内的 `module.json`。
受版本控制的配置同时显式设置 `targetSdkVersion: 26.0.0`，与当前工具链保持一致。
SDK 26 的构建工具可以配合较低的最低运行版本，但实际兼容性还取决于接口调用、字节码和系统行为。

本轮不建议为了兼容 API 20 直接降低编译 SDK。现有稳定工具链在
`ohos/flutter/toolchain.lock.json` 固定为 API 26，`ohos/tool/build_ohos.py` 会校验该版本；
如果另行要求“必须使用 SDK 20 编译”，当前构建流程不满足，还需处理工具链锁及 SDK 26 接口的编译可见性。

## 关键能力

| 能力/调用 | 接口起始 API | API 20 结论 |
| --- | --- | --- |
| 当前使用的包内备用图标 `getAlternateIcons` / `setAlternateIcon` | 26 | 点击设置入口时提示“鸿蒙 7 以下不支持该功能”并停留在设置页；原生调用仍保留版本保护 |
| 卡片管理 `openFormManager` | 18 | API 20 已具备接口 |
| 卡片更新、下一次刷新 `updateForm` / `setFormNextRefreshTime` | 9 | API 20 已具备接口，刷新时间仍服从系统调度 |
| 卡片尺寸回调 `onSizeChange` | 12 | API 20 已具备卡片支持 |
| 开发者页 13 项 `deviceInfo` 常量 | 6 | 没有高于 API 20 的接口要求 |
| WebView `darkMode` / `forceDarkAccess` | 9 | 原生深浅切换接口可用 |
| WebView `overScrollMode` | 11 | 禁止边缘回弹接口可用 |
| 普通 `BuilderNode.updateConfiguration`、组件 `onWillApplyTheme` | 12 | 本项目主题补丁使用普通 BuilderNode，未使用 API 22 的 ReactiveBuilderNode |
| 系统分享 `ShareController`、`SharedData`、`show`、`dismiss` | 11 | 当前分享调用的接口版本覆盖 API 20 |

SDK 依据为当前安装 SDK 的 `ets/api/@ohos.bundle.bundleManager.d.ts`、
`@ohos.app.form.formProvider.d.ts`、`@ohos.deviceInfo.d.ts`、`arkui/BuilderNode.d.ts`、
`ets/component/common.d.ts`、`web.d.ts`，以及 HMS 的 `@hms.collaboration.systemShare.d.ts`。
本轮读取这些声明的 `@since` 信息，没有在 API 20 SDK 下编译。

## API 20 用户实际会看到什么

### 动态图标

设置页的“应用图标”入口仍显示。点击时通过 `supportsAlternateIcons` 查询原生
`deviceInfo.sdkApiVersion >= 26` 的结果；API 20 返回 `false`，显示 SnackBar
“鸿蒙 7 以下不支持该功能”，不进入图标选择页。API 26 及以上照常进入。
查询失败时记录日志并提示加载失败，不把通道错误误报为系统版本过低。

如果其他代码绕过入口，原生层仍在调用系统备用图标接口前返回：

| 请求 | API 20 返回结果 | 直接进入图标页或绕过入口时的行为 |
| --- | --- | --- |
| `getAvailableIcons` | 空列表 | 不展示旧版图标选项 |
| `getCurrentIconName` | `null`，按既有接口约定表示默认图标 | 默认图标显示为选中，其点击回调为空 |
| `setAlternateIconName` | `UNSUPPORTED` 错误 | 正常界面无可用切换入口；即使其他调用者尝试切换，也不会伪报成功 |

当前实现没有接入低版本替代方案。API 15 起另有 AppGallery Kit 的 `appInfoManager`
图标服务，但需应用正式上架、申请开通服务并在 AGC 上传和审核图标；不能把当前包内
备用图标的 API 26 要求概括为整个鸿蒙平台的图标切换门槛。
依据：[官方接口指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/appgallery-appinfo-use)、
[图标管理前提](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/appgallery-appinfo-manage)。

入口提示的实现位于 `ohos/entry/src/main/ets/platform/DynamicIconChannel.ets` 和 `0024` 补丁，
原有原生保护及图标页由 `0019` 和上游代码提供。此次只修改代码和补丁，未执行补丁应用、构建或测试。

### 系统填充、记住密码与自动登录

此前“系统自动填充要求 API 26”应限定为：**当前 Flutter OH 嵌入层所用的系统自动填充接口要求 API 26**。
不能据此推断 API 20 系统本身完全没有密码管理/其他形式的自动填充能力。

`TextInputPlugin.evaluateAutofillRequest()` 在 API <26 返回 `reject`；
`finishAutofillContext()` 直接返回；`OhosAutoFillHelper` 内部还有一次同样的检查。
这些判断只跳过向系统密码管家发起填充/保存请求，不会停用文本框或整个输入法。

进一步搜索当前 `lib/` 及鸿蒙源码补丁，未发现应用接入 `autofillHints`、`AutofillGroup`
或 `finishAutofillContext`。登录输入组件也没有传递自动填充提示。
因此不能将这项引擎能力描述为“API 26 已有、API 20 会失去的现成登录页功能”。

| 当前业务 | 实现路径 | API 20 的代码行为 |
| --- | --- | --- |
| 记住密码 | `ScuAuth.saveCredentials()` → `FlutterSecureStorage` | 继续保存应用自己的账号密码；没有 API 26 门槛 |
| 重新打开登录页时回填 | `_loadSaved()` → `getSavedCredentials()` → 文本框 controller | 继续读取本应用已保存的凭据并回填 |
| 自动登录 | 读取自动登录开关及凭据 → 获取验证码/OCR → 登录请求 | 原有流程继续保留，不依赖系统密码管家 |
| 会话恢复/续期 | 安全存储 token、现有认证刷新流程 | 原有路径继续保留 |

以上同时核对了 `0009-session-recovery.patch`：会话并发保护、读写失败提示仍生效。
这些是代码路径结论；API 20 上安全存储、键盘及登录是否运行正常仍由用户真机确认。

## Flutter 嵌入层和插件

嵌入层版本来自当前固定的 `@ohos/flutter_ohos`，其 HAR 元数据声明最低 API 12。
关键较新接口已具备以下保护：

- `EmbeddingNodeController`：API 24 的 `postInputEventWithStrategy` 有版本和方法存在性判断；
  API 20 的触摸走 `postTouchEvent`，鼠标/轴事件走 API 20 的 `postInputEvent`。
- `FlutterManager`：API 22 的 `isInFreeWindowMode` 在低版本跳过。
- `OhosAutoFillHelper`、`TextInputPlugin`：系统自动填充/保存要求 API 26，API 20 提前返回。
  该能力是系统密码管家集成，不是应用使用 `FlutterSecureStorage` 保存登录凭据的路径。
- 路由通知桥接涉及 API 23；已有 `libflutter.so` 中存在低 API 跳过、符号不可用及动态加载失败的处理信息，
  且未将该新符号列为 ELF 强制导入。二进制线索不能代替该分支的运行验证。

已查看生成插件清单中的全部 13 项及其原生实现：
`file_picker_ohos`、`flutter_inappwebview_ohos`、`flutter_secure_storage_ohos`、
`image_gallery_saver_plus`、`image_picker_ohos`、`open_filex`、`os_type`、
`package_info_plus`、`path_provider_ohos`、`share_plus`、`shared_preferences_ohos`、
`sqflite_ohos`、`url_launcher_ohos`。

接口版本扫描及关键调用审查没有发现需要整体更换上述依赖的 API 20 阻塞。
其中 WebView 插件的 API 18 清缓存接口有版本保护；相册保存存在 API 18 分支；
`sqflite_ohos` 存在 API 17 分词器和 API 20 参数处理分支，均覆盖目标 API。
这项审查没有穷举所有重载、系统能力差异和运行结果，不能将“未发现”写成全部插件真机通过。

对已有 ARM64 `libflutter.so`、`libinappwebview.so` 的系统函数导入与 SDK 头文件版本声明进行了只读对照，
已匹配声明的导入中未发现要求 API >20 的接口；仍需实际验证动态加载及运行路径。

## 需要清理的打包项

`ohos/entry/libs/arm64-v8a/libsqlite3.so` 和现有 HAP 内的 SQLite 动态库均声明依赖：

```text
libc.so.6
ld-linux-aarch64.so.1
```

这是 Linux/glibc 的依赖形式，不能作为可用的 HarmonyOS 原生 SQLite 库依赖。
HAP 中的文件经过构建处理，与维护目录文件的字节摘要不同，但两者依赖一致。

上游 `main.dart` 仅在 Windows/Linux/macOS 初始化 SQLite FFI；鸿蒙通过
`sqflite_ohos` 使用 `relationalStore`。当前路径未发现会加载这份库，故不能据此断言
API 20 启动一定失败。

后续启动清理中，`0026` 补丁移除了鸿蒙副本入口里的桌面 FFI 分支及 import；
OH 隔离依赖图进一步排除了 `sqflite_common_ffi`，并从锁文件移除了其独占的
`sqlite3` native-asset 构建链。旧副本、`entry/libs` 与已有 HAP 未修改，
新产物仍待用户构建后检查。

## 后续安排

1. 已按用户要求将最低安装版本提高为 API 20，保留正式 Flutter OH 和 SDK 26 构建基线；由用户重新生成副本构建，核对最终 HAP 的最低 API。
2. 重新准备依赖并构建后，检查 `entry/libs` 和新 HAP 不再包含 Linux SQLite 动态库；继续保留低版本图标和系统自动填充的降级处理。
3. 用户在 API 20 手机上验收安装/冷启动、登录与键盘输入、安全存储恢复、课表/数据库、文件/选图/分享、卡片及环境信息。
4. 重点验收 API 20 的 WebView 触摸回退路径：点击位置、滚动、分页、主题切换、附件/验证码。
   API 26 使用另一套输入事件接口，其通过结果不能覆盖该回退路径。
5. 记录 API 20 设备型号、完整系统版本、HAP 版本及构建副本，再将 API 20 状态标为通过。

配置修改仅保存在 `ohos/`，未执行上述构建、清理或真机验证；测试由用户执行。
