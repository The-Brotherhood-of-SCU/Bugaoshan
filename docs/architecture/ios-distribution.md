# iOS TestFlight 分发

本文记录本项目的本地 iOS 归档、签名和 TestFlight 分发流程；构建、上传成功和测试员可安装是三个需要分别核实的状态。GitHub 发布流水线见[发布流水线](release-pipeline.md)。

## 工程配置

| 项目 | 当前配置 |
|---|---|
| Flutter | `3.44.9` stable，与仓库 CI 一致 |
| 主应用 Bundle ID | `io.github.thebrotherhoodofscu.bugaoshan.ios` |
| Widget Bundle ID | `io.github.thebrotherhoodofscu.bugaoshan.ios.CourseWidget` |
| App Group | `group.io.github.thebrotherhoodofscu.bugaoshan.ios` |
| 最低系统版本 | 主应用 iOS 15.0；Widget iOS 17.0 |
| 版本 | 主应用与 Widget 均使用 `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` |

使用 macOS、满足 Apple 当前上传要求的 Xcode 和 CocoaPods。在本机安全配置开发者账户、签名证书及对应私钥、描述文件；Apple 开发者后台的两个 App ID 都需要启用同一个 App Group。App Store Connect 应用记录必须关联主应用 Bundle ID。凭据、私钥和本机签名配置不进入仓库。

## 准备和归档

从仓库根目录执行，确保 Flutter 和 Dart 可访问公网，并沿用仓库依赖镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
flutter --version
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart analyze --fatal-infos
flutter test
```

代码生成必须成功，再生成本地化；不要用 `|| true` 掩盖生成失败。检查生成物和工作树差异，确认归档包含的源码、版本及原生配置。

先在当前 shell 设置 `IOS_BUILD_NAME` 和 `IOS_BUILD_NUMBER`：前者使用本次发布的 `X.Y.Z`，后者使用 App Store Connect 尚未使用且比此前上传构建递增的数字。同一版本重复上传也需要新的 build number，不要照搬 Android 预览构建重复使用相同编号的规则。首次构建可参考 `pubspec.yaml` 的版本，后续通过构建参数覆盖，无需为每次 TestFlight 上传修改跨平台版本。

```bash
: "${IOS_BUILD_NAME:?请设置本次发布版本 X.Y.Z}"
: "${IOS_BUILD_NUMBER:?请设置本次上传的递增构建号}"
IOS_GIT_TAG="$(git describe --tags --always --dirty)"
IOS_GIT_COMMIT="$(git rev-parse HEAD)"
IOS_GIT_COMMIT_DATE="$(git log -1 --format=%ci)"

flutter build ipa --release --export-method app-store \
  --build-name "$IOS_BUILD_NAME" \
  --build-number "$IOS_BUILD_NUMBER" \
  --dart-define="GIT_TAG=$IOS_GIT_TAG" \
  --dart-define="GIT_COMMIT=$IOS_GIT_COMMIT" \
  --dart-define="GIT_COMMIT_DATE=$IOS_GIT_COMMIT_DATE"
```

该命令先生成 `build/ios/archive/` 下的 `.xcarchive`，再导出 `build/ios/ipa/` 下的 `.ipa`。导出需要可用的本机签名配置；若归档成功但导出失败，可保留归档，在修正证书和描述文件后重新导出。需要复用特定导出选项时，可使用 Xcode 导出的本地 `ExportOptions.plist` 替换 `--export-method` 参数。参见 [Flutter iOS 发布文档](https://docs.flutter.dev/deployment/ios)。

本项目实际验证发现：使用 `--no-codesign` 归档后再 export，可能得到已签名但缺失 App Group 权利的 IPA。归档阶段就必须为主应用和 Widget 正确签名，不能依赖导出阶段补齐。导出后解压 IPA，分别对 `Payload/Runner.app` 和其中的 `PlugIns/CourseWidgetExtension.appex` 执行 `codesign -d --entitlements :-`，确认实际签名中的 `com.apple.security.application-groups` 均包含上表的 App Group；仅检查源码 `.entitlements` 或 `embedded.mobileprovision` 不足以确认这些权利已写入签名。

归档后核实主应用和内嵌 Widget 的 Bundle ID 分别符合上表，版本、构建号及签名 App Group 一致；同时确认各自包含 `PrivacyInfo.xcprivacy`，主应用图标含不带 alpha 通道的 1024×1024 图像。`pubspec.yaml` 已设置 `remove_alpha_ios: true`，后续重新生成图标时应保留。

## 上传与测试分发

在 Xcode Organizer 打开归档，先 Validate App，再选择 **Distribute App → App Store Connect → Upload**；也可通过 Transporter 上传导出的 IPA。为保留外部 TestFlight 和正式上架能力，不选择 **TestFlight Internal Only**，也不勾选同名限制选项。参见 [Apple 分发说明](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app)。

上传后在 App Store Connect 的 TestFlight 页面等待构建处理，核对版本及构建号，完成加密问卷和测试说明，再把构建加入测试群组。外部测试还需按页面要求填写 Beta 审核信息并通过审核；公开邀请链接需在对应外部群组中启用。最后以 TestFlight 中的构建状态及测试员实际安装结果确认分发完成。

## 隐私清单与加密问卷

两个 target 的隐私清单声明各自实际使用的 required-reason API：主应用使用应用内及 App Group 的 UserDefaults，Widget 使用 App Group 的 UserDefaults；文件元数据访问用于应用容器下载文件及 App Group 课表数据库。依据见 [Apple API 使用原因](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)。这些声明不能代替 App Store Connect 的隐私问卷，也不表示应用不发送用户数据；登录、报修等功能会向相应学校服务发送请求。

应用包含系统 HTTPS / 安全存储以外的加密实现：

- `dart_sm` 的 SM2 C1C2C3 用于 SCU 登录密码加密，见 `lib/utils/sm2_crypto.dart`。
- `encrypt` 的 AES-128-CBC + PKCS7 用于智慧后勤认证 Token 及业务响应解密，见 `lib/utils/zhhq_crypto.dart`。

因此不能把问卷回答为仅使用操作系统加密、仅 HTTPS 或全部仅用于身份认证。应按实际算法、用途及分发地区回答，依据 App Store Connect 的结果决定是否需要文档及 `ITSAppUsesNonExemptEncryption` 配置，不预先声明豁免。法国相关问题也按实际分发计划回答；Apple 当前说明中，标准算法对应的法国加密声明取决于是否在法国 App Store 分发。参见 [Apple 加密文档要求](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption)及[问卷流程](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)。
