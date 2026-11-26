# Linux 分发架构

网页视图取舍见 [ADR-0010：Linux 端不再提供原生 WebView](../decisions/0010-remove-linux-native-webview.md)。若本文与代码不一致，以代码为准并同步更新。

## 渠道现状

| 渠道 | 状态 | 架构 | 入口与产物 |
|---|---|---|---|
| 源码构建 | 可用 | 本机架构 | `flutter build linux --release`，运行 `./Bugaoshan` |
| GitHub Release `tar.gz` | 随正式与预览版自动发布 | x64 | `debian:13` 容器构建的裸 bundle（`bugaoshan_<version>_linux_x64.tar.gz`） |
| Flatpak | 仅本地离线 manifest，未接入 CI / Flathub | x86_64 / aarch64 | [`packaging/flatpak/flatpak-flutter.yml`](../../packaging/flatpak/flatpak-flutter.yml) |
| AUR / Debian `.deb` | 未实现 | — | 无 `PKGBUILD` / `debian/`；AUR 约束见 [`packaging/aur/README.md`](../../packaging/aur/README.md) |

[`packaging/linux/`](../../packaging/linux) 存放跨渠道复用的 `.desktop`、AppStream metainfo 与图标（`metainfo.xml` 最新已同步至 `2.6.0`）。

## Bundle 与桌面集成

- `flutter build linux --release` 生成标准 bundle，主程序通过 `$ORIGIN/lib` RPATH 查找引擎、AOT 与插件库；裸解压包直接运行 `./Bugaoshan`，`packaging/linux/*.desktop` 中的 `Exec=bugaoshan` 仅用于正式安装后的 PATH 入口。
- **图标注册**：X11/XWayland 直接读取 bundle 内 `share/icons/hicolor/512x512/apps/<application-id>.png`。Wayland 合成器按 desktop entry 匹配图标：首次启动若 `XDG_DATA_DIRS` 中尚无系统包 / Flatpak / Snap 提供的同名条目，runner 会在 `$XDG_DATA_HOME/applications/` 写入隐藏条目（`NoDisplay=true`、`X-Bugaoshan-Generated=true`、`Exec` 指向当前可执行文件）并将图标复制到 `$XDG_DATA_HOME/icons/hicolor/512x512/apps/<application-id>.generated`；若已存在外部安装条目，则跳过并清理自建条目。
- **构建与运行依赖**：GTK 3、libsecret、libepoxy、Wayland（见 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)）。

## 网页视图边界

- `flutter_inappwebview` 在 Linux 解析到 fork 的纯 Dart 占位包 `flutter_inappwebview_linux_placeholder`，无 C++/CMake 与 WPE 运行库依赖；`linux/flutter/generated_plugins.cmake` 与 `generated_plugin_registrant.cc` 由 `flutter pub get` 自动生成，勿手改。
- 依赖网页的入口（教务处 / 学工部 / 团委通知与志愿四川）通过 `hasNoWebViewBackend` 切到 [`WebViewUnsupportedPage`](../../lib/widgets/webview/webview_unsupported_page.dart)，拉起系统默认浏览器并提供复制链接兜底；研究生课表导入走直连路径。
- 修改构建或插件时勿在 Linux 重新引入原生 WebView 或 WPE（确需恢复须先更新 ADR-0010）。

## CI 发布包（`tar.gz`）

[`.github/workflows/build-linux.yml`](../../.github/workflows/build-linux.yml) 在 `debian:13` 容器（钉住 glibc / GTK 基线）内安装常规 GTK/Wayland 开发包后构建 `build/linux/x64/release/bundle`，由 [`release.yml`](../../.github/workflows/release.yml) 经 [`release_prepare.py`](../../.github/scripts/release_prepare.py) 重命名并随 [`release_body.py`](../../.github/scripts/release_body.py) 发布的下载正文一起上传。

> [!NOTE]
> CI 目前不额外校验 `ldd` 依赖可解析性或 bundle 残留库；裸 bundle 不附带运行依赖声明，目标机器缺少系统库时由动态链接器直接报错。

## Flatpak（本地离线 manifest）

[`packaging/flatpak/flatpak-flutter.yml`](../../packaging/flatpak/flatpak-flutter.yml) 与 [`foreign.json`](../../packaging/flatpak/foreign.json) 由 `flatpak-flutter` 生成离线 manifest `io.github.the_brotherhood_of_scu.bugaoshan.yml`（`org.freedesktop.Platform` 25.08 + LLVM 20），并通过 `flatpak-update-policy.patch` 禁用容器内应用自更新、通过 `foreign.json` 为 `sqlite3` native asset 提供离线构建输入。

当前已知滞后：source/generated manifest 仍固定旧应用 commit 与 Flutter `3.44.4`（落后于 CI 的 `3.47.9`），实际打包前需人工同步版本并重生成。
