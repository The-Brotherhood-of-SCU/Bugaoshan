# 鸿蒙测试

本目录包含鸿蒙构建脚本测试和 Flutter 平台适配测试。请先按
[开发指南](../README.md) 配置工具链，并根据测试类型选择运行目录。

## Python 脚本测试

`python/` 包含构建、源码链接/翻译合并和插件补丁脚本的测试。
链接测试需要系统允许创建符号链接，Windows 请启用开发者模式或使用管理员 PowerShell。在仓库根目录执行：

```powershell
python -m unittest discover -s ohos/tests/python -p "test_*.py"
```

## Flutter 适配测试

`flutter/` 维护 `*.dart.template`，避免上游整仓分析直接解析依赖 OH 插件的测试。
`ohos/tool/build_ohos.py` 将模板链接为 `ohos/.flutter-workspace/test/ohos/*.dart`，
保留模板内相对目录；遇到与根测试同名的文件即停止，不覆盖上游文件。

执行 `--prepare-only` 后，在 `ohos/.flutter-workspace/` 中使用同一 Flutter OH SDK 执行：

```powershell
flutter test --no-pub test/ohos/platform_adapters_test.dart test/webview_notice_handlers_test.dart
```

首页按需加载及认证隔离的回归检查：

```powershell
flutter test --no-pub test/ohos/home_page_loading_test.dart test/auth_scoped_indexed_stack_test.dart
```

该组检查覆盖未访问页不初始化、已访问页状态保留、导航重排及移除、认证变化后清理页面状态。

课程复制与 OH 转场检查：

```powershell
flutter test --no-pub test/ohos/course_duplicate_test.dart test/ohos/course_copy_mode_test.dart test/ohos/theme_page_transitions_test.dart
```

课程测试使用 `support/memory_course_database.dart` 的内存替身，不依赖
`sqflite_common_ffi`，也不打开原生数据库插件。准备 OH 工作区时，上游的
`course_copy_mode_test.dart`、`course_duplicate_test.dart` 和
`theme_page_transitions_test.dart` 不会被链接；它们分别由上述 OH 模板
替代，避免全量 `flutter test` 解析桌面依赖或使用缺少 OH 项的平台断言。

本次迁移新增了上游变化拒绝、翻译合并、路径边界及组装前完整检查的 Python 测试，
并更新原有副本测试；代理未执行测试。`ohos_sources.py --check` 只检查维护输入，不代替测试。

链接工程另有共享文件即时可见、覆盖切换、链接移除不删除原文件、生成代码独立、
外部生成路径拒绝的 Python 测试。根原生工程接入另覆盖 SDK 源码漂移拒绝、
原生版本注入、依赖准备失效、生成代码复用和参数传递。代理只提供测试代码，未执行。

这些测试模拟平台通道，不替代真机操作。DevEco 原生测试仍按工程约定放在
[entry/src/ohosTest/](../entry/src/ohosTest/)。构建和调试入口见 [鸿蒙开发说明](../README.md)。
