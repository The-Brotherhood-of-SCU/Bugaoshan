# Linux 分发架构

> 文档状态：当前实现的权威说明
>
> 最后核对：2026-07-31
>
> WPE 边界的设计取舍见 [ADR-0004：Linux WebView 由分发环境提供 WPE](../decisions/0004-use-distribution-wpe-on-linux.md)。若本文与代码不一致，以代码为准，并应在同一变更中更新本文。

## 1. 当前渠道

| 渠道 | 当前状态 | 架构 | WPE 来源 |
|---|---|---|---|
| 源码构建 | 可用 | 在当前 Linux 系统执行 `flutter build linux` | 构建及运行系统 |
| GitHub Release tar.gz | 已移除，不再随 GitHub Release 发布 | x64（历史） | 用户目标系统（历史） |
| Flatpak | 有 source/generated manifest 和本地构建流程，未接入 CI | Freedesktop 25.08 容器 | Flatpak `/app/lib` |
| AUR | 仅有设计说明 | 尚无 `PKGBUILD` / `.SRCINFO` | 计划使用 Arch 系统包 |
| Debian `.deb` | 未实现 | 尚无 `debian/` 控制文件或构建流程 | 尚未声明 |

`packaging/linux/` 目前只是跨渠道复用的 desktop 文件、AppStream metainfo 和图标，不是 Debian 包目录。

## 2. Flutter Linux bundle

`flutter build linux --release` 生成标准 bundle：

```text
bundle/
├── Bugaoshan
├── data/
│   ├── icudtl.dat
│   └── flutter_assets/
└── lib/
    ├── libflutter_linux_gtk.so
    ├── libapp.so
    ├── libflutter_inappwebview_linux_plugin.so
    └── other plugin/native libraries
```

可执行文件使用 `$ORIGIN/lib` RPATH 查找 Flutter engine、AOT 和应用私有插件库。bundle 不包含 desktop entry、AppStream metadata、图标安装规则、依赖声明或 PATH 启动器。

因此直接解压 tar.gz 后运行的是 `./Bugaoshan`，而 `packaging/linux/*.desktop` 中的 `Exec=bugaoshan` 只有在正式安装流程提供小写 PATH 入口后才成立。

## 3. WPE WebKit 边界

Linux 通知 WebView 需要原生插件：

```text
libflutter_inappwebview_linux_plugin.so
  -> libWPEWebKit-2.0.so.1
  -> libWPEBackend-fdo-1.0.so.*
  -> libwpe-1.0.so.*
```

[`linux/CMakeLists.txt`](../../linux/CMakeLists.txt) 在 Flutter 生成插件规则后过滤三类 WPE 库：

```cmake
list(FILTER PLUGIN_BUNDLED_LIBRARIES EXCLUDE REGEX
  "lib(WPEWebKit-2\\.0|WPEBackend-fdo-1\\.0|wpe-1\\.0)\\.so")
```

这不是构建后删除插件，也不是禁用 WebView。最终边界是：

```text
Flutter private bundle: native WebView plugin, no WPE copies
Distribution environment: WPE runtime and its transitive dependencies
```

普通系统由宿主发行版提供 WPE；Flatpak 的“分发环境”是 `/app` 前缀，不是宿主操作系统。

源码构建所需的主要开发组件列在 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)：GTK 3、WPE WebKit 2.0、WPEBackend-fdo、libwpe、libsecret、libepoxy 和 Wayland。

## 4. GitHub Linux tar.gz（已移除）

Linux 构建发布 action 已移除：`build-linux.yml` 已删除，`release.yml` 只构建 Android 与 Windows，Release 正文不再提供 Linux 下载链接。

用户仍可在本地 Linux 系统执行 `flutter build linux --release` 得到第 2 节描述的 bundle，但仓库不再自动：

- 生成并发布 `bugaoshan_<version>_linux_x64.tar.gz`；
- 由 CI 验证插件存在、bundle 不含 WPE 副本及 `ldd` 可解析依赖；
- 在 Release 正文固定 Linux 下载链接。

若未来恢复正式 Linux 发布，应重新引入构建工作流、`release_prepare.py` 重命名、Release 正文链接以及本节原有的动态链接验证检查。

## 5. Flatpak

[`packaging/flatpak/flatpak-flutter.yml`](../../packaging/flatpak/flatpak-flutter.yml) 是 source manifest；`flatpak-flutter` 根据它和 `foreign.json` 生成离线 manifest `io.github.the_brotherhood_of_scu.bugaoshan.yml`。

当前运行环境：

- `org.freedesktop.Platform` / SDK `25.08`
- LLVM 20 extension
- Flutter `3.44.4`
- libwpe `1.16.3`
- wpebackend-fdo `1.16.1`
- WPE WebKit `2.52.4`

构建顺序：

```text
libwpe
  -> wpebackend-fdo
  -> WPE WebKit installed under /app
  -> Flutter application
  -> remove any WPE copy from Flutter private lib/
  -> install app under /app/lib/bugaoshan
  -> create /app/bin/bugaoshan symlink
  -> install desktop, metainfo, icon and license
```

Flatpak 因此是自包含的分发环境：它不依赖宿主发行版的 WPE，但 WPE 也没有重复进入 `/app/lib/bugaoshan/lib`。

manifest 通过 `flatpak-update-policy.patch` 禁用容器内应用自更新，并通过 `foreign.json` 为 Linux WebView 的 nlohmann JSON 和 sqlite3 native asset 提供离线构建输入。

当前仓库没有 Flatpak GitHub Actions 或 Flathub 发布配置；manifest 只提供本地构建路径，当前整理没有执行完整 WPE/Flatpak 构建，也不能据此认定已经发布到 Flathub。

## 6. AUR

[`packaging/aur/README.md`](../../packaging/aur/README.md) 只记录未来 `PKGBUILD` 的运行依赖和验证要求。当前没有：

- `PKGBUILD`
- `.SRCINFO`
- AUR 发布脚本或 CI
- 经 `namcap` 验证的包元数据

正式 AUR 包更适合在 Arch 环境从源码构建，以避免复用 Debian sid 二进制产生 ABI 风险。预期运行依赖至少包括 GTK 3、libepoxy、libsecret、libwpe、Wayland、wpebackend-fdo 和 wpewebkit。

无论采用源码还是二进制包，package step 都必须验证插件存在、bundle 不含 WPE 副本、`ldd` 可从系统解析全部依赖。

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
4. 验证目标 Debian/Ubuntu 基线上的 WPE ABI，而不只是在 sid 构建容器运行 `ldd`。
5. 定义升级、卸载及 desktop/icon cache 刷新行为。

## 8. 发布职责矩阵

| 事项 | tar.gz | Flatpak | AUR | Debian `.deb` |
|---|---|---|---|---|
| 当前构建入口 | 无（已移除 CI） | 本地 manifest，未由 CI 验证 | 无 | 无 |
| 正式 Release 自动发布 | 否 | 否 | 否 | 否 |
| 提供 WPE | 用户系统 | Flatpak `/app` | 计划由 Arch 包 | 未来由 Debian 包 |
| 声明系统依赖 | 否 | manifest | 尚未实现 | 尚未实现 |
| desktop/AppStream 安装 | 否 | 是 | 尚未实现 | 尚未实现 |
| 当前架构 | x64 | x86_64 / aarch64 manifest | 未定 | 未定 |

## 9. 已知技术债

1. GitHub tar.gz 渠道已移除；若恢复，需重新设计针对稳定发行版的最低 ABI 基线测试。
2. 若恢复 tar.gz，裸 bundle 没有运行依赖说明或启动前检查，缺库时通常只表现为 loader 错误。
3. Flatpak source manifest 与 generated manifest 需要人工同步；两者当前固定旧应用 commit，不会直接构建当前 HEAD。
4. Flatpak Flutter `3.44.4` 与 CI Flutter `3.44.6` 不一致。
5. AppStream metainfo 最新 release 仍为 `2.1.1`，落后于 `pubspec.yaml` 的 `2.2.0`。
6. WPE WebKit 使用 `ENABLE_BUBBLEWRAP_SANDBOX=OFF`，属于需要持续评估的安全折衷。
7. AUR 和 Debian 还没有可安装包，系统依赖方案尚未经过真实打包工具验证。

## 10. 修改检查清单

修改 Linux WebView、CMake 或打包配置时：

1. 保留 native WebView plugin，不把 WPE 重新复制进 Flutter 私有 bundle。
2. 在构建环境运行 `ldd`，检查 `not found` 和预期 WPE SONAME。
3. 在不含构建开发包的干净目标环境验证运行时依赖。
4. 同步 source/generated Flatpak manifest、应用 commit、Flutter 版本和 AppStream release。
5. 若新增正式 AUR 或 Debian 渠道，同时更新 release workflow、产物命名、下载正文和本文职责矩阵。
6. 实际打开通知页面，验证 WPE WebView 非空白、可导航并能下载附件。
