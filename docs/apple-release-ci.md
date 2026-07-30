# Apple 平台 Release CI 配置

发布 `v*.*.*` 标签时，`.github/workflows/release.yml` 会并行执行：

- macOS：构建 arm64 App，使用 Developer ID 签名，提交 Apple 公证，生成并装订 `.dmg`。
- iOS：使用 Apple Distribution 签名导出 App Store `.ipa`，上传 GitHub Release，并自动上传到 TestFlight。

手动运行 Release 工作流时，只有勾选 `upload_testflight` 才会上传 TestFlight，避免测试工作流误传正式构建。

## 一、Apple Developer 配置

### iOS App 与 Widget

确认以下 Identifier 都属于同一个 Apple Developer Team，并启用了 App Groups：

- `io.github.thebrotherhoodofscu.bugaoshan`
- `io.github.thebrotherhoodofscu.bugaoshan.CourseWidget`
- App Group：`group.io.github.thebrotherhoodofscu.bugaoshan`

创建一个 **Apple Distribution** 证书，将含私钥的证书从“钥匙串访问”导出为有密码的 `.p12`。

为主 App 和 Widget 分别创建 **App Store Connect** provisioning profile。工作流会通过 App Store Connect API 按 Bundle ID 自动下载，因此不用把 profile 本身存进 GitHub。

### macOS DMG

创建 **Developer ID Application** 证书，将含私钥的证书导出为有密码的 `.p12`。Developer ID 用于 GitHub 直接分发；不能用 Mac App Distribution 或 Apple Development 证书替代。

macOS Runner 的 `flutter_secure_storage` 使用 `keychain-access-groups` entitlement，因此还需要 Developer ID provisioning profile。Keychain Sharing 在 Xcode 中表现为 capability，但无需在开发者网站的 App ID 页面寻找同名开关；profile 会提供默认 Keychain 授权。

1. 使用现有多平台显式 App ID `io.github.thebrotherhoodofscu.bugaoshan`；macOS 与 iOS 复用该 App ID。
2. 创建面向站外分发的 **Developer ID** provisioning profile，选择上述 App ID 和 CI 使用的 Developer ID Application 证书。
3. Profile 名称固定为 `Bugaoshan Developer ID`。工作流会通过 API 按 Bundle ID 自动下载，Runner target 仅在 Release 配置中选择该名称，避免把 profile 错误应用到 CocoaPods targets。

## 二、App Store Connect API Key

在 App Store Connect 的“用户和访问 → 集成 → App Store Connect API”创建团队 API Key，建议授予 **App Manager**；如果下载 provisioning profile 时权限不足，改用 **Admin**。

`.p8` 私钥只能下载一次。记录：

- Key ID
- Issuer ID
- `.p8` 文件内容

macOS 公证可以使用同一个团队 API Key；如果 Developer ID 属于另一个团队，需要在该团队另建 Key。

## 三、GitHub Actions 变量与 Secrets

进入仓库 **Settings → Secrets and variables → Actions**。

Variables：

| 名称 | 内容 |
| --- | --- |
| `APPLE_TEAM_ID` | iOS App 与 Widget 所属 Team ID（当前工程为 `2F6UXH5569`） |
| `APPSTORE_API_KEY_ID` | iOS/TestFlight API Key ID |
| `APPSTORE_ISSUER_ID` | iOS/TestFlight Issuer ID |
| `IOS_APP_PROVISIONING_PROFILE_NAME` | 主 App 的 App Store Connect profile 名称 |
| `IOS_WIDGET_PROVISIONING_PROFILE_NAME` | Widget 的 App Store Connect profile 名称 |
| `MACOS_NOTARY_API_KEY_ID` | macOS 公证 API Key ID |
| `MACOS_NOTARY_ISSUER_ID` | macOS 公证 Issuer ID |

Secrets：

| 名称 | 内容 |
| --- | --- |
| `APPSTORE_CERTIFICATES_FILE_BASE64` | Apple Distribution `.p12` 的 Base64 |
| `APPSTORE_CERTIFICATES_PASSWORD` | 上述 `.p12` 密码 |
| `APPSTORE_API_PRIVATE_KEY` | iOS/TestFlight `.p8` 的完整文本 |
| `MACOS_DEVELOPER_ID_CERTIFICATES_FILE_BASE64` | Developer ID `.p12` 的 Base64 |
| `MACOS_DEVELOPER_ID_CERTIFICATES_PASSWORD` | 上述 `.p12` 密码 |
| `MACOS_NOTARY_API_PRIVATE_KEY` | macOS 公证 `.p8` 的完整文本 |

在 macOS 上生成 `.p12` 的单行 Base64：

```bash
base64 -i certificate.p12 | pbcopy
```

不要对 `.p8` 再做 Base64，直接复制包含 `BEGIN PRIVATE KEY` 和 `END PRIVATE KEY` 的完整文本。

## 四、首次配置 TestFlight

1. 在 App Store Connect 创建/确认 iOS App，Bundle ID 为 `io.github.thebrotherhoodofscu.bugaoshan`。
2. 在 TestFlight → Test Information 填写 Beta App Description、Feedback Email、联系人和登录/审核说明。
3. 创建一个内部测试组，并启用 **Enable automatic distribution**。此后 CI 上传并处理完成的构建会自动对内部测试组可用；内部测试不需要 TestFlight App Review。
4. 如需外部测试，先创建外部测试组。首次构建处理完成后，将它加入外部组，填写 What to Test，并点击 **Submit Review**。外部测试需要 TestFlight App Review，且同一版本同一时间只能有一个构建处于审核中。

当前工作流负责“构建、签名、上传、等待 Apple 处理完成”。外部测试组的首次资料和首次提交建议在网页完成；完成后可再通过 App Store Connect API 的 `betaAppReviewSubmissions` 自动化后续外部审核提交，但应先确定固定测试组、出口合规答案和审核联系资料，避免 CI 将错误构建自动送审。

### 出口合规说明

工作流没有硬编码 `ITSAppUsesNonExemptEncryption`，也不会替团队回答出口合规问题。项目使用 HTTPS，并包含 SM2 加密实现；团队的 Account Holder 或 Admin 应根据实际密码学用途和适用法规，在 App Store Connect 中确认是否属于豁免加密并按要求提供文件。首次上传后若 Apple 显示 “Missing Compliance”，先在构建详情页完成该项，之后再把经确认的答案固化进应用配置或上传流程。

## 五、发布与构建号

- 推送 `v2.3.0`、`v2.3.0-beta.1` 等标签会触发完整 Release；标签构建会自动上传 TestFlight。
- Apple 的版本号取标签中的前三段数字，例如 `v2.3.0-beta.1` 使用版本 `2.3.0`。
- 构建号使用 `GitHub run number.run attempt`，例如 `128.1`，每次运行递增，避免 App Store Connect 拒绝重复构建号。
- 手动运行工作流时填写版本标签；如需上传 TestFlight，再勾选 `upload_testflight`。
