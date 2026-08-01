# ADR-0004：Linux WebView 由分发环境提供 WPE

- 状态：已接受并实施
- 决策日期：2026-07-29
- 实施提交：`d5cbabb`
- 当前实现：[Linux 分发架构](../architecture/linux-distribution.md)

## 背景

Linux 的 `flutter_inappwebview` 插件动态依赖 WPE WebKit、WPEBackend-fdo 和 libwpe。Flutter 插件构建规则会把部分原生库加入 `PLUGIN_BUNDLED_LIBRARIES`，早期实现曾把 WPE 副本及补充 SONAME 软链接放进应用 bundle。

私带 WPE 会显著增加制品体积，并可能与目标系统或容器中的 WebKit 栈产生 ABI、加载顺序和安全更新边界问题。完全移除 Linux WebView 插件则会让通知、志愿四川等功能失效。

## 决策

1. Linux bundle 保留 `libflutter_inappwebview_linux_plugin.so`。
2. CMake 从 `PLUGIN_BUNDLED_LIBRARIES` 过滤以下 WPE 库：

```text
libWPEWebKit-2.0.so*
libWPEBackend-fdo-1.0.so*
libwpe-1.0.so*
```

3. 普通 Linux 构建、发行版包和 AUR 由目标系统的软件包管理器提供 WPE 运行库。
4. Flatpak 不使用宿主系统 WPE，而是在 Flatpak `/app` 前缀内构建 WPE；Flutter 私有 `lib/` 中仍不重复携带。
5. Linux CI 必须验证插件存在、Flutter bundle 不含 WPE 副本、`ldd` 没有缺失依赖，并且插件确实链接 `libWPEWebKit-2.0.so.1`。

## 后果

正面影响：

- 保留 Linux 原生 WebView 功能，同时避免在应用私有目录复制完整 WebKit 栈。
- 发行版可以统一提供 WPE 安全更新；Flatpak 则在自己的运行环境内固定版本。
- 普通 bundle、AUR 和 Flatpak 遵循同一个“插件保留、WPE 不进入 Flutter 私有 bundle”边界。

代价与约束：

- GitHub tar.gz 不再是完全自包含制品，目标系统必须预装兼容运行库。
- 裸 tar.gz 无法声明依赖，跨发行版 ABI 兼容性只能通过额外测试保证。
- Flatpak 必须自行编译体积较大的 WPE WebKit。
- AUR、Debian 等正式包必须声明准确运行依赖，不能只解压 tar.gz 后假设系统已满足依赖。
