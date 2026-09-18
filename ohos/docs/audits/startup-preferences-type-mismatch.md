# ARM64 启动读取浮点设置失败

日期：2026-09-18。用户的真机截图显示应用自己的“Bugaoshan 启动失败”页面，
栈头为 `os: ohos arch: arm64`、`sim: no`。这份报告与 x86_64 模拟器白屏分开处理。

## 符号化证据

截图、当前 ARM64 `libapp.so` 和 Release 符号文件的 Build ID 均为：

```text
e0344fe1972c8391de22cf26609f9cfc
```

使用匹配的 `ohos/.flutter-workspace/build/symbols/release/app.ohos-arm64.symbols`
只读解析截图中的 `virt` 地址，结果如下。行号指修复前版本。

| 帧 | 虚拟地址 | 函数 | 源码位置 |
| --- | --- | --- | --- |
| 00 | `0x552abf` | `SharedPreferences.getDouble` | `shared_preferences_legacy.dart:125` |
| 01 | `0x9f39eb` | `AppConfigProvider._loadPreferences` | `app_config_provider.dart:127` |
| 02 | `0xa70eff` | `AppConfigProvider.init` | `app_config_provider.dart:52` |
| 03 | `0xa70eb3` | `_configureAsyncDependencies` 的注册回调 | `injector.dart:84` |
| 04 | `0x9aa460` | GetIt 注册回调 | `get_it_impl.dart:2187` |
| 05 | `0x38facc` | `FutureGroup.add` 回调 | `future_group.dart:79` |

失败点为 `getDouble('courseRowHeight')`。该 getter 直接执行缓存值的
`as double?` 强转，`?? 72.0` 只能处理 null，不能处理强转异常。
异常沿依赖初始化传播到 `main()` 的 catch，于是显示启动失败页。
此前页面只显示 `stackTrace`，没有把 `error` 的原因文字传入界面。

## 类型不兼容的来源

当前锁定的 `shared_preferences_ohos` 在 ArkTS 端将 `setDouble` 的值保存为
`number`，`getAll` 原样返回该数值。嵌入层 `StandardMessageCodec.writeValue()`
对 `Number.isInteger(value)` 成立的值使用整数编码，Dart 解码后得到 `int`。
例如原本的 `72.0` 可以在下一次启动时读成 `72`；保存后的同进程 Dart 缓存仍是
double，所以修改设置当时正常，冷启动读取时才失败。截图没有显示具体保存的值。

这属于配置读取的类型兼容问题，没有证据要求调整堆大小或再次刷新 SDK 缓存。

## 修复

[AppConfigProvider](../../flutter/overrides/lib/providers/app_config_provider.dart)
中的四项浮点设置统一从 `SharedPreferences.get()` 读取原始值：

- `courseRowHeight`：课表行高；
- `courseCardFontSize`：课表字号；
- `colorOpacity`：卡片透明度；
- `backgroundImageOpacity`：背景透明度。

通过项目既有 `safeDouble` 将 int/double 转成 double，同时兼容可解析的数值字符串。
不存在的值沿用原来的默认值；错误类型、不可解析字符串、NaN 或 Infinity 只让对应字段
回退默认值，并记录不含原始值的警告。其他偏好设置不变，不清空或批量重写存储。

保持原有 `setDouble` 保存方式；下一次读取始终经过兼容转换。仅把旧值重新保存为 double
不能根治问题，因为原生通道再次返回时仍可能使用整数编码。当前 OH 启动配置之外没有
其他 `getDouble` 调用：上游桌面窗口设置在鸿蒙已有空实现，不进入该路径。

[启动入口](../../flutter/overrides/lib/main.dart) 现在将异常类型、原因和原始栈一并
传入错误页，Release 日志也复用同一份脱敏报告。报告由
[格式化函数](../../flutter/overrides/lib/utils/ohos_startup_error.dart) 生成；
异常自身的 `toString()` 失败时仍保留原始堆栈。

## 回归与验收

新增但未执行的 OH 测试模板：

- [配置读取](../../tests/flutter/app_config_numeric_preferences_test.dart.template)：
  整数返回、小数保留、数值字符串、缺省配置、错误值回退、其他设置不变，以及更改行高后的冷启动读取。
- [启动报告](../../tests/flutter/ohos_startup_error_test.dart.template)：
  异常原因与地址保留、脱敏及异常格式化失败时的回退。

用户在 DevEco Sync/准备后，可在 `ohos/.flutter-workspace/` 使用锁定的 Flutter OH 执行：

```powershell
flutter test test/ohos/app_config_numeric_preferences_test.dart test/ohos/ohos_startup_error_test.dart
```

随后构建完整 ARM64 Release HAP，覆盖安装到原先失败的真机，保留原有应用数据：

1. 冷启动应进入正常页面，原来的行高、字号、透明度和其他设置应保留。
2. 将行高改为合法的整数档位，结束进程后再次启动，验证新值仍有效。
3. 将透明度设为 0 或 1、字号设为整数档位，再冷启动，确认同类字段均可恢复。
4. 如仍显示失败页，采集其中新增的异常原因与完整堆栈，使用该次构建的符号文件解析。

修改严格位于 `ohos/`，没有修改插件缓存、SDK、根业务源码或本机签名配置。
仅完成静态源码与清单检查；未执行 Dart 格式化、分析、测试或构建，尚待真机验证。
