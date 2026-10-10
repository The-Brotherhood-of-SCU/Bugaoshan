# macOS App Store 分发与原生控件

macOS 与 iOS 共用 App Store Connect 应用记录 `6813305962`。主应用 Bundle ID 为 `io.github.thebrotherhoodofscu.bugaoshan.ios`，Widget 为该 ID 加 `.CourseWidget`，两者使用 `group.io.github.thebrotherhoodofscu.bugaoshan.ios` 共享课表数据库与显示设置。共用商店条目不代表跨设备同步课表；iPhone 与 Mac 各自保存本地数据。

最低系统为 macOS 13，课表小组件需要 macOS 14。应用、小组件及 Flutter 引擎以 universal binary 支持 Apple Silicon 和 Intel。签名团队与 iOS 一致；证书、私钥、描述文件与 Apple 账户留在本机，不提交仓库。

## Liquid Glass

`Runner/LiquidGlass.swift` 使用 `NSHostingView` 承载 SwiftUI 控件，通过 `AppKitView` 接入 Flutter。macOS 26+ 使用系统 `.glass` / `.glassProminent` 按钮与原生 Toggle，宽窗口使用系统 List 侧栏，图标与文案横排且只有当前入口高亮；窄窗口使用可横向滚动的导航，并用 `GlassEffectContainer` 管理玻璃按钮。课程、表单及列表内容继续由 Flutter 绘制。

Flutter 维护选中入口与开关值，原生层仅回传稳定入口 ID、点击或值变化，避免入口重排与旧事件错选页面。主题、RTL、文字缩放、减少动态效果和高对比度参数通过现有桥接同步；系统减少透明度由原生控件处理。macOS 13–25、旧 SDK 或桥接失败时恢复 Material 导航和控件。按钮与开关复用 iOS 已接入的调用点，未接入的按钮保持原实现。

桥接单测使用模拟通道，不能证明真实材质、鼠标或键盘行为。发布前在签名 release 应用中检查宽窄窗口、导航、设置值同步、滚动、弹窗及路由切换；旧 macOS 与 Intel 的实际运行需要相应设备验收。

## 构建与签名

使用 Flutter 3.44.9、支持 macOS 26 API 的 Xcode 和 CocoaPods。先在 Xcode 登录发布 iOS 时使用的开发者账号，并确保主应用和 Widget 的 App ID 均启用上述 App Group。

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export MACOS_BUILD_NAME=2.5.3
export MACOS_BUILD_NUMBER=<App-Store-Connect-中未使用的递增构建号>
bash tool/macos_distribution.sh archive
bash tool/macos_distribution.sh export
```

脚本依次执行依赖解析、build_runner、本地化生成、Flutter 配置和 Xcode 归档，输出 `build/macos/archive/Bugaoshan.xcarchive`；导出到 `build/macos/appstore/`。归档本身必须正确签名，主应用和内嵌 Widget 必须使用同一证书。`tool/verify_macos_bundle.py` 检查实际包中的版本、Bundle ID、隐私清单、双架构及签名中的 Sandbox/App Group/Keychain/文件/日历权限，拒绝 release 中的调试 JIT 和服务端网络权限。

导出的 Mac App Store 安装包还需使用 `pkgutil --check-signature` 核实安装器签名，并在 Xcode Organizer Validate App 后上传，或通过 Transporter 上传 `.pkg`。App Store Connect 处理成功后才可选择构建；上传、处理、提交审核和正式可下载是不同状态。加密问卷沿用实际 SM2/AES 用途，参见 [iOS 分发说明](ios-distribution.md#隐私清单与加密问卷)，不能声明应用仅使用 HTTPS。

主应用和 Widget 包含 required-reason API 隐私清单。主应用保留 App Sandbox，仅授权出站网络、用户选取的文件、日历和应用自身的 Keychain/App Group；导入日历会请求系统权限，不能把声明权限视为用户已经授权。

## CI 与既有安装

`build-macos.yml` 在发布流水线中执行不需要证书的 universal release 构建与包检查，保留 7 天验证制品。`release_prepare.py` 只整理 Android 与 Windows 安装包，Mac 未签名验证包不上传到 GitHub Release。商店归档、安装器签名和上传通过上述本机流程处理。

旧 Mac 包名为 `io.github.thebrotherhoodofscu.bugaoshan`，App Group 和签名团队也不同。共用条目版使用新的容器，无法直接读取旧容器或 Keychain；旧版用户应先导出课表，再在新版导入并重新登录。不要为迁移删除旧版数据或放宽 Sandbox。共用 Bundle ID 的 iOS 与 macOS App Group 名称一致，但不会自动跨设备共享数据库。

参考：[Flutter macOS 发布](https://docs.flutter.dev/deployment/macos)、[Flutter macOS 平台视图](https://docs.flutter.dev/platform-integration/macos/platform-views)、[Apple macOS 分发](https://developer.apple.com/macos/distribution/)。
