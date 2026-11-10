# ADR-0010：Linux 端不再提供原生 WebView

- 状态：已接受并实施
- 决策日期：2026-10-18
- 取代：[ADR-0004：Linux WebView 由分发环境提供 WPE](0004-use-distribution-wpe-on-linux.md)
- 当前实现：[Linux 分发架构](../architecture/linux-distribution.md)

## 背景

Linux 的 `flutter_inappwebview` 后端是原生实现，动态依赖 WPE WebKit、WPEBackend-fdo 和 libwpe。ADR-0004 选择了「保留插件、由分发环境提供 WPE」的边界：CMake 不把 WPE 副本写进应用 bundle，运行库由目标系统或 Flatpak `/app` 前缀提供，Flatpak 自行编译 WPE WebKit。

这条边界让通知公告、志愿四川等页面在 Linux 上可用，但代价是 Linux 制品不再是自包含的：裸 bundle 无法声明运行依赖，目标系统必须预装 ABI 兼容的 WPE，跨发行版只能靠额外测试保证；Flatpak 则必须编译 WPE WebKit 这一体积最大的模块。实践中这会让 Linux 用户在相当一部分发行版上无法直接运行。

同时，上游 fork 新增了 `flutter_inappwebview_linux_placeholder`：一个纯 Dart 包（无 C++、无 CMake、无原生依赖），federated plugin 的 Linux `default_package` 指向它，所有平台工厂方法在运行时抛 `UnimplementedError`。依赖它即可让 Linux 构建完全绕开 WPE。

## 决策

**Linux 端不再提供原生 WebView。应用依赖 fork 的纯 Dart 占位实现，用「更广泛的发行版兼容性」换掉 Linux 的应用内网页能力。**

1. `pubspec.yaml` 的 `flutter_inappwebview` git 依赖把 `ref:` 写死到 fork 的具体提交（当前为 fork 最新提交），`flutter_inappwebview_linux` 从依赖图中消失。
2. 平台能力统一由 `hasNoWebViewBackend`（`lib/widgets/webview/webview_unsupported_page.dart`）判定，当前取值为 Linux；通知页与研究生课表导入的应急网页抓取都走这一个判据，不再各自判断。
3. `linux/CMakeLists.txt` 删除只为原生插件准备的 WPE 库过滤；`PLUGIN_BUNDLED_LIBRARIES` 不再需要特殊处理。
4. Flatpak 不再构建 libwpe / wpebackend-fdo / unifdef / wpewebkit，也不再需要为 Linux WebView 准备的 nlohmann JSON 离线输入与 url-hash 补丁。
5. AUR、Debian 等打包渠道的预期运行依赖与验证清单不再要求 WPE 运行库与插件存在性检查。

## 理由

1. **兼容性是 Linux 用户的实际痛点**：ADR-0004 的「WPE 由分发环境提供」在裸 bundle 上没有任何依赖声明能力，缺库时只表现为 loader 错误；占位实现把这条依赖整个去掉，任何发行版都能直接运行。
2. **占位包是上游 fork 的既定方向**：它不是本地 workaround，而是 federated plugin 的正常降级路径（纯 Dart + `dartPluginClass`），后续跟随 fork 即可，不需要在应用侧维护 shim。
3. **没有第三种「半可用」状态**：Linux 上要么有原生 WebView，要么没有。占位实现的所有工厂方法都抛 `UnimplementedError`，所以判定必须是二元的，且必须覆盖所有 WebView 入口——否则用户会点进一个必然抛异常的空页面。
4. **`ref` 写死提交号，而不是留空浮动**：写死提交号时同样的 `pubspec.yaml` 在任何时间都解析出同一个 fork 状态；要跟进上游时显式改这个哈希，而不是让 fork 的任意新提交悄悄改变构建结果。

## 已评估但未采用

| 方案 | 否决理由 |
|---|---|
| 保持 ADR-0004：保留原生插件 + 宿主提供 WPE | 裸 bundle 无法声明运行依赖，跨发行版 ABI 兼容性只能靠额外测试，Linux 用户装不上的问题依旧 |
| 在 bundle 内私带 WPE 副本 | 体积显著增大，且与目标系统 WebKit 栈存在加载顺序、ABI 与安全更新边界问题（ADR-0004 已否决） |
| 抽象出 WebView 接口，Linux 上改用纯 HTTP 兜底 | 通知站点与 ehall 依赖真实浏览器上下文（cookie、重定向、JS），HTTP 兜底不足以替代；超出本次决策范围 |
| 删除 Linux 平台工程 | 课表、成绩、余额等核心功能在 Linux 上完全可用，不应因网页视图整体退场 |

## 后果

正面影响：

- Linux 构建与产物不再依赖 WPE WebKit 运行库，也不再需要 GTK/WPE 相关的系统开发包，跨发行版兼容性显著提升。
- Flatpak 不再构建体积最大的 WPE WebKit 模块，manifest 与构建时间大幅收缩。
- 打包渠道的运行依赖清单与验证步骤同步简化（不再要求「插件存在 + bundle 无 WPE 副本 + `ldd` 可解析 WPE SONAME」）。

代价与约束：

- Linux 上依赖 WebView 的功能不可用：三个通知来源（教务处 / 学工部 / 团委）和志愿四川显示 `WebViewUnsupportedPage` 的浏览器交接页，由系统默认浏览器继续浏览（页面提供复制链接兜底）；研究生课表导入的「应急网页抓取」不提供交接页，因此只保留直连路径。
- 与 ADR-0004 的「插件保留、WPE 不进入私有 bundle」边界正式作废。
- `hasNoWebViewBackend` 是新增 WebView 功能必须检查的平台判据；漏检的入口会在 Linux 上抛 `UnimplementedError`，而不是优雅降级。
- 若将来要恢复 Linux 应用内网页能力，需要重新引入原生插件（或更换后端）并重跑跨发行版 ABI 验证，恢复成本与本次决策前相同。

## 相关实现

- 依赖固定：`pubspec.yaml`、`pubspec.lock`
- 平台判据与占位页：`lib/widgets/webview/webview_unsupported_page.dart`
- 通知页：`lib/widgets/webview/webview_notice_page.dart`
- 研究生课表导入：`lib/pages/graduate/schedule_import_page.dart`
- Linux 工程：`linux/CMakeLists.txt`、`linux/flutter/generated_plugin_registrant.cc`、`linux/flutter/generated_plugins.cmake`
- Flatpak：`packaging/flatpak/flatpak-flutter.yml`、`packaging/flatpak/foreign.json`
