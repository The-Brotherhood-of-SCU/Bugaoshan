# Linux 分发架构

> 文档状态：当前实现的权威说明
>
> 最后核对：2026-10-18
>
> 网页视图边界的设计取舍见 [ADR-0010：Linux 端不再提供原生 WebView](../decisions/0010-remove-linux-native-webview.md)。若本文与代码不一致，以代码为准，并应在同一变更中更新本文。

## 1. 当前渠道

| 渠道 | 当前状态 | 架构 | 网页视图后端 |
|---|---|---|---|
| 源码构建 | 可用 | 在当前 Linux 系统执行 `flutter build linux` | 无（纯 Dart 占位） |
| GitHub Release tar.gz | 可用，随正式与预览发布一起分发 | x64，CI 在 `debian:13` 容器内构建 | 无（纯 Dart 占位） |
| Flatpak | 有 source/generated manifest 和本地构建流程，未接入 CI | Freedesktop 25.08 容器 | 无（纯 Dart 占位） |
| AUR | 仅有设计说明 | 尚无 `PKGBUILD` / `.SRCINFO` | 无（计划） |
| Debian `.deb` | 未实现 | 尚无 `debian/` 控制文件或构建流程 | 无 |

`packaging/linux/` 目前只是跨渠道复用的 desktop 文件、AppStream metainfo 和图标，不是 Debian 包目录。

## 2. Flutter Linux bundle

`flutter build linux --release` 生成标准 bundle：

```text
bundle/
├── Bugaoshan
├── data/
│   ├── icudtl.dat
│   └── flutter_assets/
├── lib/
│   ├── libflutter_linux_gtk.so
│   ├── libapp.so
│   └── other plugin/native libraries
└── share/
    ├── applications/
    │   └── io.github.the_brotherhood_of_scu.bugaoshan.desktop
    └── icons/hicolor/512x512/apps/
        └── io.github.the_brotherhood_of_scu.bugaoshan.png
```

可执行文件使用 `$ORIGIN/lib` RPATH 查找 Flutter engine、AOT 和应用私有插件库。GTK runner 启动时从 `share/icons/hicolor/512x512/apps/<application-id>.png` 加载窗口图标（X11/XWayland 使用）。Wayland 合成器不读取 GTK 的窗口图标，而是按 desktop entry 匹配应用图标；因此 runner 首次启动时还会读取 bundle 内的 desktop 模板，在 `$XDG_DATA_HOME/applications/<application-id>.desktop` 写入一个 `NoDisplay=true` 的隐藏条目（`Exec` 指向当前可执行文件的绝对路径，`X-Bugaoshan-Generated=true`），并把图标以 `<application-id>.generated` 的私有名称复制到 `$XDG_DATA_HOME/icons/hicolor/512x512/apps/`，避免覆盖系统包安装的同名图标。如果 `XDG_DATA_DIRS` 中已经存在系统包 / Flatpak / Snap 安装的 desktop entry，runner 会跳过我方注册并删除自己生成的条目和图标。bundle 仍不安装 AppStream metadata、可见的启动器条目、依赖声明或 PATH 启动器。

因此直接解压 tar.gz 后运行的是 `./Bugaoshan`，而 `packaging/linux/*.desktop` 中的 `Exec=bugaoshan` 只有在正式安装流程提供小写 PATH 入口后才成立。

## 3. Linux 网页视图

Linux 端不再提供原生 WebView（见 [ADR-0010](../decisions/0010-remove-linux-native-webview.md)）。`flutter_inappwebview` 在 Linux 上解析到 fork 的纯 Dart 占位实现 `flutter_inappwebview_linux_placeholder`：没有 C++、没有 CMake、没有任何原生依赖，平台工厂方法在运行时抛 `UnimplementedError`。

因此 Linux 构建链路中：

- 不存在 `libflutter_inappwebview_linux_plugin.so`，也没有 `libWPEWebKit-2.0.so.1` → `libWPEBackend-fdo-1.0.so.*` → `libwpe-1.0.so.*` 这条原生依赖链；
- `linux/flutter/generated_plugins.cmake` 与 `linux/flutter/generated_plugin_registrant.cc` 不再注册任何 WebView 插件（两者由 `flutter pub get` 生成，不要手改）；
- [`linux/CMakeLists.txt`](../../linux/CMakeLists.txt) 不再需要从 `PLUGIN_BUNDLED_LIBRARIES` 过滤 WPE 库（ADR-0004 的过滤块已删除）；
- 构建系统不再需要 WPE WebKit 2.0、WPEBackend-fdo、libwpe 开发包。

依赖 WebView 的功能在 Linux 上显示 [`WebViewUnsupportedPage`](../../lib/widgets/webview/webview_unsupported_page.dart) 的浏览器交接页：三个通知来源（教务处 / 学工部 / 团委）和志愿四川会把目标地址交给系统默认浏览器打开，页面同时提供复制链接作为兜底；登录与附件下载都在浏览器中完成。平台判据是 `hasNoWebViewBackend`；研究生课表导入因此只保留直连路径。

源码构建所需的主要开发组件列在 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)：GTK 3、libsecret、libepoxy 和 Wayland。

## 4. GitHub Linux tar.gz

Linux 构建由 [`.github/workflows/build-linux.yml`](../../.github/workflows/build-linux.yml) 提供：在 `debian:13`（当前稳定版，而不是滚动的 `debian:testing`，以便钉住 glibc / GTK 基线）容器内安装 Flutter Linux 构建依赖（GTK 3、libsecret、libepoxy、libwayland；不再需要 WPE 相关开发包），调用公共 setup action 装配 Flutter、生成代码与 git 元数据，执行 `flutter build linux --release`，把 `build/linux/x64/release/bundle` 打包为 `linux-release.tar.gz` 并上传为 artifact。

[`release.yml`](../../.github/workflows/release.yml) 在正式与预览两条通道上都调用它，发布阶段下载为 `linux-release/`；[`release_prepare.py`](../../.github/scripts/release_prepare.py) 将其重命名为 `bugaoshan_<version>_linux_x64.tar.gz` 后随 Release 上传，[`release_body.py`](../../.github/scripts/release_body.py) 在发布正文固定给出该下载链接。

制品是第 2 节描述的裸 bundle：解压后运行 `./Bugaoshan`，没有可见的桌面菜单条目、依赖声明或 PATH 启动器，目标系统需要自备 GTK 3、libsecret、libepoxy、Wayland 等运行库。首次启动会按第 2 节的规则自动注册一个隐藏的桌面条目和用户级图标，用于 Wayland 下的窗口 / 任务栏图标关联；运行 `./Bugaoshan` 不需要该步骤预先完成。当前工作流不额外校验 `ldd` 依赖可解析，也不校验 bundle 内是否残留网页视图原生库（见第 9 节）。

## 5. Flatpak

[`packaging/flatpak/flatpak-flutter.yml`](../../packaging/flatpak/flatpak-flutter.yml) 是 source manifest；`flatpak-flutter` 根据它和 `foreign.json` 生成离线 manifest `io.github.the_brotherhood_of_scu.bugaoshan.yml`。

当前运行环境：

- `org.freedesktop.Platform` / SDK `25.08`
- LLVM 20 extension
- Flutter `3.44.4`

构建顺序：

```text
Flutter application
  -> install app under /app/lib/bugaoshan
  -> create /app/bin/bugaoshan symlink
  -> install desktop, metainfo, icon and license
```

Flatpak 因此是自包含的分发环境：它不依赖宿主的任何 WebView 运行库，应用 bundle 里也没有网页视图原生库。

manifest 通过 `flatpak-update-policy.patch` 禁用容器内应用自更新，并通过 `foreign.json` 为 sqlite3 native asset 提供离线构建输入。

当前仓库没有 Flatpak GitHub Actions 或 Flathub 发布配置；manifest 只提供本地构建路径，当前整理没有执行完整 Flatpak 构建，也不能据此认定已经发布到 Flathub。

## 6. AUR

[`packaging/aur/README.md`](../../packaging/aur/README.md) 只记录未来 `PKGBUILD` 的运行依赖和验证要求。当前没有：

- `PKGBUILD`
- `.SRCINFO`
- AUR 发布脚本或 CI
- 经 `namcap` 验证的包元数据

正式 AUR 包更适合在 Arch 环境从源码构建，以避免复用 Debian sid 二进制产生 ABI 风险。预期运行依赖至少包括 GTK 3、libepoxy、libsecret 和 Wayland。

无论采用源码还是二进制包，package step 都必须验证 `ldd` 可从系统解析全部依赖。

## 7. Debian 包

当前没有 `.deb` 实现。仓库不存在以下文件：

```text
debian/control
debian/rules
debian/install
debian/changelog
```

未来实现必须至少解决：

1. 根据最终 ELF `DT_NEEDED` 声明准确的运行依赖，不能直接照抄 sid 开发包名。
2. 把 bundle 安装到固定的 `/usr/lib` 或 `/opt` 位置，并提供 `/usr/bin/bugaoshan`。
3. 安装 `packaging/linux/` 的 desktop、metainfo 和图标。
4. 确认 bundle 中不存在网页视图原生库残留，且依赖 WebView 的页面在 Linux 上显示系统浏览器交接页。
5. 定义升级、卸载及 desktop/icon cache 刷新行为。

## 8. 发布职责矩阵

| 事项 | tar.gz | Flatpak | AUR | Debian `.deb` |
|---|---|---|---|---|
| 当前构建入口 | `build-linux.yml`（CI） | 本地 manifest，未由 CI 验证 | 无 | 无 |
| 正式 Release 自动发布 | 是 | 否 | 否 | 否 |
| 网页视图后端 | 无 | 无 | 无 | 无 |
| 声明系统依赖 | 否 | manifest | 尚未实现 | 尚未实现 |
| desktop/AppStream 安装 | 隐藏 desktop entry（首次启动自动注册）；AppStream 未安装 | 是 | 尚未实现 | 尚未实现 |
| 当前架构 | x64 | x86_64 / aarch64 manifest | 未定 | 未定 |

## 9. 已知技术债

1. Linux 构建只做 `flutter build linux --release` 与打包：不校验 `ldd` 依赖可解析，也不校验 bundle 内是否残留网页视图原生库；最低 ABI 基线仍只靠用户实测。
2. 裸 bundle 没有运行依赖说明或启动前检查，缺库时通常只表现为 loader 错误。
3. Flatpak source manifest 与 generated manifest 需要人工同步；两者当前固定旧应用 commit，不会直接构建当前 HEAD。
4. Flatpak Flutter `3.44.4` 与 CI Flutter `3.44.6` 不一致。
5. AppStream metainfo 最新 release 仍为 `2.1.1`，落后于 `pubspec.yaml` 的 `2.2.0`。
6. Linux 端没有应用内网页视图；若恢复，需要重新引入原生插件并重跑跨发行版 ABI 验证（见 [ADR-0010](../decisions/0010-remove-linux-native-webview.md)）。
7. AUR 和 Debian 还没有可安装包，系统依赖方案尚未经过真实打包工具验证。

## 10. 修改检查清单

修改 Linux 构建、CMake 或打包配置时：

1. 不要在 Linux 工程中重新引入网页视图原生插件或 WPE 运行库；确需恢复时先更新 [ADR-0010](../decisions/0010-remove-linux-native-webview.md)。
2. 在构建环境运行 `ldd`，检查 `not found`；Linux bundle 中不应出现网页视图 / WPE 原生库。
3. 在不含构建开发包的干净目标环境验证运行时依赖。
4. 同步 source/generated Flatpak manifest、应用 commit、Flutter 版本和 AppStream release。
5. 若新增正式 AUR 或 Debian 渠道，同时更新 release workflow、产物命名、下载正文和本文职责矩阵。
6. 在 Linux 上打开通知页面，确认显示「用浏览器打开此页面」交接页，且主按钮能拉起系统默认浏览器、复制链接可用。
