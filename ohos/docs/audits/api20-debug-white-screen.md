# API 20 x86_64 模拟器 Debug 启动白屏

日期：2026-09-18。用户确认本次环境为 DevEco x86_64 模拟器、Debug 模式。
本记录依据当日 16:56 的 HiLog 和源码静态审查；没有执行依赖解析、构建、测试或设备调试。
用户进一步要求：若为 x86 平台专属问题则不处理。因此不增加 x86_64 插件适配，
优先以 ARM64 真机启动结果判断是否还需追查。

后续 ARM64 真机的“启动失败”截图已独立符号化，定位为偏好设置数值类型转换失败，
见[对应修复记录](startup-preferences-type-mismatch.md)。该报告没有证明与本次
模拟器的 `Stack Overflow` 是同一原因。

## 已确认的证据

| 时间 | 日志 | 说明 |
| --- | --- | --- |
| 16:56:01.978 | `libinappwebview.so: No such file or directory` | 模拟器缺少可加载的 WebView 插件原生库 |
| 16:56:02.375 | `XComponent` 创建表面 | 原生窗口和 Flutter 表面已经启动 |
| 16:56:02.411–02.502 | Dart 数据库初始化、RDB schema 迁移 | 已进入 Dart，并执行了平台通道调用 |
| 16:56:02.519–02.521 | 两次 `Stack Overflow`、两行 `...`、`DiagnosticsProperty<void>` | Flutter 异常输出缺少可定位的栈帧，是白屏排查重点 |
| 16:56:03.030 | `native updateWidget completed successfully` | 异常后进程和部分异步任务仍在运行 |

这份日志没有给出新的 NativeCrash/SIGSEGV，不能沿用此前 ARM64 Release 的
平台 `.dill`/FFI 地址截断结论。`Stack Overflow` 指调用栈溢出，不能据此判断
Dart 堆内存过大，也不能由该文字直接确定是无限递归还是线程可用栈不足。

`nativeNotifyPageChanged is not supported on this API level` 是低 API 跳过路径；
输入法、GPU 和 QoS 日志目前不足以证明是此次白屏原因。

## 代码审查与改动

### WebView 原生库

锁定的 WebView 插件只声明 CMake 入口，没有配置 `abiFilters`。当前 Hvigor 的
`CmakeUtil.checkAbiFilters()` 在空配置下返回 `arm64-v8a`；现有插件的 Debug/Release
原生构建目录也只有 ARM64。只读抽查的本地 HAP 含两种架构的 Flutter/AOT 库，
但 `libinappwebview.so` 和 `libc++_shared.so` 只出现在 ARM64 目录。
该本地 HAP 是 AOT 产物，**不作为本次 Debug 已安装包的同一性证明**。

这项缺库是已确认的 x86_64 打包缺口。按用户要求不处理；没有保留新增的 ABI
配置补丁，也没有向插件缓存或 SDK 应用改动。ARM64 已有对应插件库。

插件后续仍有注册日志，Dart 也继续运行，因此不能认定缺库就是首屏白屏的唯一原因。

### Dart 栈溢出

已审查应用入口、依赖就绪等待、主题构建、首页导航缓存、课表入口和空课表布局，
尚未找到能与日志对应的明确自递归调用。Debug 首次启动默认跳过 EULA 和向导，
通常直接进入课表首页；持久化设置仍可能改变页面。首页已采用访问时挂载的策略，
没有再次改为同时创建全部隐藏页面。

原来的 `main()` try/catch 只能捕获依赖初始化与同步入口异常，捕不到后续由 Flutter
框架处理的 build/layout 错误。框架默认错误输出在 Debug 中渲染诊断树，后续错误
可能仅输出 `Another exception...`，不适合用来保留此次缺失的完整原始栈。

新增 [Debug 诊断](../../flutter/overrides/lib/utils/ohos_debug_diagnostics.dart)，
由 [OH 入口](../../flutter/overrides/lib/main.dart) 仅在 Debug 安装：

- 捕获 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`，并记录初始化失败。
- 退出当前失败回调后，以微任务先输出原始异常栈；不渲染 `FlutterErrorDetails` 诊断树，
  不调用额外信息收集器或默认栈过滤。异常文本转换失败时保留已输出的原始栈。
- 每次错误有 `BEGIN`/`END` 编号；每行保留帧号，长行分块，不主动省略重复帧。
- 先脱敏再分块，避免敏感字段在分块边界漏出。日志路径不依赖 GetIt 或通知监听器，避免报错递归。
- build 失败时使用 Flutter 的叶子错误组件显示简短提示，避免在同一深层调用栈再次格式化异常。
- 标记 `initializing-dependencies`、`dependencies-ready`、`runApp-called`。
  最后一个标记仅表示调用了 `runApp`，不表示首帧成功。

这是诊断改动，尚未修复未知的栈溢出来源。若虚拟机提供的原始栈本身只有 `...`，
应用日志无法恢复缺失的帧；需在 Dart 调试器异常断点处读取调用栈。
Release 保留原来的处理方式。没有调整堆/线程栈大小、清除用户数据或全局替换平台标识。

已添加 [诊断回归测试模板](../../tests/flutter/ohos_debug_diagnostics_test.dart.template)，
覆盖错误构建、原始栈保留、诊断收集器隔离、异常字符串化失败、日志重入及脱敏分块。
尚未运行，由用户在准备后的 OH 测试工程执行。

## 真机验证与继续排查条件

1. 在 DevEco 对原始 `ohos/` 工程执行 Sync，组装新增的 Debug 诊断文件。
   也可以在仓库根目录执行：

   ```powershell
   python ohos/tool/build_ohos.py --prepare-only
   ```

2. 用 ARM64 真机确认 Debug 和 Release 都能冷启动且首屏可交互。若要确认 API 20
   兼容性，应使用 API 20 真机；API 26 通过不能代替 API 20 的验证。
3. 真机正常时，按当前范围不继续追查模拟器白屏。无需为此新增 x86_64 原生库或调整堆大小。
4. 若真机 Debug 也出现白屏或 `Stack Overflow`，过滤 HiLog 中的 `BugaoshanDiagnostic`，
   导出第一组 `BEGIN` 到 `END` 的全部记录和启动阶段标记；保留相邻原生错误。
   同一调用链反复出现时检查递归；若为有限但过深的 build/layout 链，结合调试器实际
   线程栈信息评估。若原始栈仍缺失，在支持 Dart 的 Flutter OH 调试器中开启异常断点。

目前没有足够证据将 `Stack Overflow` 也认定为 x86 专属问题；保留的诊断代码仅帮助
真机复现时定位。未取得 API 20 真机结果前，API 20 启动兼容性仍未验收通过。
