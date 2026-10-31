# macOS App Store 分发与原生控件

macOS 与 iOS 共用 App Store Connect 应用记录 `6813305962`。主应用 Bundle ID 为 `io.github.thebrotherhoodofscu.bugaoshan.ios`，Widget 为该 ID 加 `.CourseWidget`，两者使用 `group.io.github.thebrotherhoodofscu.bugaoshan.ios` 共享课表数据库与显示设置。共用商店条目不代表跨设备同步课表；iPhone 与 Mac 各自保存本地数据。

最低系统为 macOS 13，课表小组件需要 macOS 14。应用、小组件及 Flutter 引擎以 universal binary 支持 Apple Silicon 和 Intel。签名团队与 iOS 一致；私钥和描述文件只存入本机受限目录及个人仓库 `wjlfish/Bugaoshan-macos` 的 GitHub Secrets，不提交 Git。

安装后的主应用为 `不高山上.app`，`CFBundleName` 与 `CFBundleDisplayName` 均为「不高山上」，供 Finder、Dock、菜单栏、窗口标题和系统授权页面使用。内部可执行文件仍为 `Bugaoshan`；Bundle ID、签名身份和数据容器保持连续。商店导出包为 `不高山上.pkg`，CI 的 unsigned ZIP 与公开 DMG 文件名保留既有 ASCII 命名规则。

## Liquid Glass

`Runner/LiquidGlass.swift` 使用 `NSHostingView` 承载 SwiftUI 控件，通过 `AppKitView` 接入 Flutter。macOS 26+ 只对导航、开关与滑块采用原生呈现：设置使用系统 Toggle / Slider，宽窗口使用系统 List 侧栏，图标与文案横排且只有当前入口高亮；窄窗口使用可横向滚动的导航，并用 `GlassEffectContainer` 管理玻璃按钮。课程、表单及列表内容继续由 Flutter 绘制。

Flutter 维护选中入口与开关值，原生层仅回传稳定入口 ID、开关值或滑块开始/变化/结束事件，避免入口重排与旧事件错选页面。主题、RTL、文字缩放、减少动态效果和高对比度参数通过现有桥接同步；系统减少透明度由原生控件处理。macOS 13–25、旧 SDK 或桥接失败时恢复 Material 导航和控件。开关与滑块复用 iOS 的调用点，登录/登出、重试、确认等操作按钮统一保留原有 Material 样式。原生绑定先更新自身值，再通知 Flutter；相同值的回传不重启动效，也不额外叠加玻璃或切换动画。

拖动期间保留系统滑块的当前位置，延迟的 Flutter 回传不能把滑块拉回旧值；范围或主题变更仍会同步，松手后恢复以 Flutter 业务值为准。普通控件配置与同值回传不额外启动 SwiftUI 动画。

桥接单测使用模拟通道，不能证明真实材质、鼠标或键盘行为。`tool/test_macos_glass_state.py --framework-dir <FlutterMacOS.framework 的父目录>` 在 macOS 26+ 编译并执行实际 Swift 状态模型，覆盖开关同值回传、滑块拖动期间的旧值回传、开始/结束回调去重与中途禁用。发布前在签名 release 应用中检查宽窄窗口、导航、设置值同步、滚动、弹窗及路由切换；旧 macOS 与 Intel 的实际运行需要相应设备验收。

## 本地提醒

`Runner/ReminderChannel.swift` 注册 `bugaoshan/reminder`，实现授权、权限查询、计划替换、取消、待投递数量和系统通知设置跳转。只有用户主动点击授权或首次开启提醒时请求权限，启动及排期同步只查询状态。`UNUserNotificationCenter` 在应用关闭后仍负责已登记的提醒，前台提醒也显示横幅与声音；展示受系统通知设置和专注模式控制。

同步与取消串行执行，仅替换 `bugaoshan.reminder.` 命名空间的通知。计划格式先验证再撤销旧请求，登记错误返回 Dart 层；宿主缺失或系统接口错误不能转换为“授权被拒绝”。重新授权会清除计划短路缓存并重新登记当前课表。开发者页的 15 秒提醒探针可验证真实投递；通道单测不能代替签名应用的系统授权与投递验收。

## 构建与签名

使用 Flutter 3.44.9、支持 macOS 26 API 的 Xcode 和 CocoaPods。先在 Xcode 登录发布 iOS 时使用的开发者账号，并确保主应用和 Widget 的 App ID 均启用上述 App Group。

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
# 以下归档脚本在个人 fork 的 macos-signing 分支执行。
# 先更新个人 fork 的 .github/macos-signing.json 中 Mac 专用的 version / build。
# build 必须是 App Store Connect 中未使用的递增构建号。
bash tool/macos_distribution.sh archive
bash tool/macos_distribution.sh export
```

脚本依次执行依赖解析、build_runner、本地化生成、Flutter 配置和 Xcode 归档，输出 `build/macos/archive/Bugaoshan.xcarchive`；导出到 `build/macos/appstore/`。归档本身必须正确签名，主应用和内嵌 Widget 必须使用同一证书。`tool/verify_macos_bundle.py` 检查实际包中的版本、Bundle ID、隐私清单、双架构及签名中的 Sandbox/App Group/Keychain/文件/日历权限，拒绝 release 中的调试 JIT 和服务端网络权限。

导出的 Mac App Store 安装包还需使用 `pkgutil --check-signature` 核实安装器签名，并在 Xcode Organizer Validate App 后上传，或通过 Transporter 上传 `.pkg`。App Store Connect 处理成功后才可选择构建；上传、处理、提交审核和正式可下载是不同状态。加密问卷沿用实际 SM2/AES 用途，参见 [iOS 分发说明](ios-distribution.md#隐私清单与加密问卷)，不能声明应用仅使用 HTTPS。

主应用和 Widget 包含 required-reason API 隐私清单。主应用保留 App Sandbox，仅授权出站网络、用户选取的文件、日历和应用自身的 Keychain/App Group；导入日历会请求系统权限，不能把声明权限视为用户已经授权。

## CI 与既有安装

主仓库保留独立的 `build-macos.yml` PR / 手动无证书 universal 构建验证，制品保留 7 天。该工作流不参与 Release Pipeline，也不持有发布凭据。macOS 应用和 Widget 源码正常留在主仓库。

所有 macOS 发布编排、Developer ID 签名、公证、DMG 工具及 Mac version/build 配置均迁至个人 fork [wjlfish/Bugaoshan-macos](https://github.com/wjlfish/Bugaoshan-macos)，由 `macos-signing` 分支维护；商店归档脚本也在该分支。其定时任务每 30 分钟检查上游最新 tag，也支持手动指定 tag。源码固定到已合入上游 main/preview 的 commit，编译 job 不接触凭据，签名代码与 entitlements 来自个人签名分支。

DMG 及校验 manifest 仅发布到[个人仓库 Releases](https://github.com/wjlfish/Bugaoshan-macos/releases)，版本名为 `macos-<上游 tag>`。上游不触发、不等待、不下载这些产物；个人发布失败可独立重跑，绝不影响 Android / Windows / Linux 发布。`stapler staple` 与 `validate` 均重试最多三次（间隔 10 / 20 秒），验证失败不发布未签名替代包。

7 项 Secrets 仅配置在个人 fork：`MACOS_CERTIFICATE_P12_BASE64`、`MACOS_CERTIFICATE_PASSWORD`、`MACOS_APP_PROFILE_BASE64`、`MACOS_WIDGET_PROFILE_BASE64`、`NOTARY_KEY_P8`、`NOTARY_KEY_ID`、`NOTARY_ISSUER_ID`。主仓库无需 macOS Environment、签名 Secrets、启用变量或跨仓库 PAT。公证使用 App Store Connect 团队 API 密钥。

macOS 凭据统一使用 Data Protection Keychain，服务名独立于插件默认值，权限由签名和描述文件中的 access group 决定。旧实现 `usesDataProtectionKeychain: false` 使用登录钥匙串，其 ACL 绑定旧应用签名，更新后会对多个凭据反复弹授权。新版不自动读取、删除或迁移旧钥匙串项目；既有 Mac 用户需重新登录一次，本地课表和设置保留。iOS 的服务名和可访问性设置保持原样。

旧 Mac 包名为 `io.github.thebrotherhoodofscu.bugaoshan`，App Group 和签名团队也不同。共用条目版使用新的容器，无法直接读取旧容器或 Keychain；旧版用户应先导出课表，再在新版导入并重新登录。不要为迁移删除旧版数据或放宽 Sandbox。共用 Bundle ID 的 iOS 与 macOS App Group 名称一致，但不会自动跨设备共享数据库。

参考：[Flutter macOS 发布](https://docs.flutter.dev/deployment/macos)、[Flutter macOS 平台视图](https://docs.flutter.dev/platform-integration/macos/platform-views)、[Apple macOS 分发](https://developer.apple.com/macos/distribution/)。
