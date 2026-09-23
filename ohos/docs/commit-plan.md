# 鸿蒙工程同步适配提交清单

准备日期：2026-09-16。上游源码基线：`e5c38070e154ab1a62b701534055e03ab9c8861f`。

后续状态：这 19 批本地提交已经完成。本文保留当时的文件路径与提交方案，不用于提交后续改动。
源码补丁现已迁移为完整 Dart 覆盖文件，当前维护入口及迁移范围见
[源码迁移记录](audits/source-overlay-migration.md)；不要按本文旧文件列表重新执行提交。

工程来源：此前已有的鸿蒙工程。本轮工作在原工程基础上同步上游，补齐 SDK、依赖、
平台功能和构建流程适配。

本清单将现有鸿蒙实现整理为 **19 个连续提交**。准备时共有 113 个未跟踪文件，
加上本清单共 114 个文件，每个文件只分配给一批。所有路径均位于 `ohos/`。

## 提交方式

采用文件级分批，保留各文件当前最终内容。中间提交用于组织审查，**不保证可以单独构建**；
完整构建与验收以整组提交为准。补丁清单、模块声明和原生入口在第 15 批集中加入，
各源码补丁仍按清单原有顺序应用，不因 Git 提交批次而重新编号或重排。

准备时 Git 显示未跟踪，描述的是当前仓库的文件跟踪状态；原生工程本身此前已经存在。
原工程的基础配置、页面和资源随对应批次纳入，提交说明区分继承内容与本轮适配工作。
构建脚本已经位于 `ohos/tool/`，文档、测试和补丁也已经整理；各批记录当前最终内容。
构建脚本、依赖锁等跨阶段文件整体提交。

在仓库根目录的 PowerShell 中按编号执行。每批分为“暂存并检查”和“提交”两个代码块；
先查看暂存区差异，确认无误后再执行该批提交命令。任一命令失败时先处理失败原因，
不要继续运行后续批次。

开始前，以及完成每一批提交后，确认暂存区没有其他内容：

```powershell
git status --short
git diff --cached --name-status
```

`git commit` 会提交暂存区的全部内容。发现已有其他暂存改动时，应先明确它们的归属，
再执行本清单；本清单不包含清空暂存区、回退文件或覆盖既有工作的命令。

所有 `git add` 均使用明确的文件列表，不添加构建副本、Pub 缓存、生成插件注册文件、
本机签名配置或 `local.properties`。其中：

- 提交 `ohos/build-profile.json5` 的无签名基线，使 DevEco 能在首次 Sync 前识别工程；不提交本机签名差异。
- 提交 `ohos/entry/build-profile.json5`，这是模块构建配置，与上一项本机应用签名配置不同。
- 不添加 `ohos/build/`、`oh_modules/`、`node_modules/` 和编译产物。

本清单准备了提交命令，不代表这些命令已经执行，也不代表新增构建或测试通过。
测试源码随第 16 批入库；实际验证结果按 [同步计划](sync-plan.md) 记录。
推送和 PR 按目标仓库约定处理；贡献回上游时先进入 `preview`，再由 `preview` 合入 `main`。

## 批次总览

| 批次 | 提交信息 | 文件数 |
| --- | --- | --- |
| 01 | `chore(ohos): 恢复原有鸿蒙端支持文件` | 17 |
| 02 | `build(ohos): 添加正式工具链校验与隔离构建入口` | 3 |
| 03 | `build(ohos): 固定鸿蒙依赖并适配 Flutter OH SDK` | 5 |
| 04 | `fix(ohos): 适配安全存储插件与异步错误返回` | 4 |
| 05 | `feat(ohos): 接入文件相册与 WebView 下载适配` | 4 |
| 06 | `fix(ohos): 完善外链分享日历与 Passpoint 调用` | 7 |
| 07 | `fix(ohos): 完善凭据恢复与跨账号会话保护` | 2 |
| 08 | `fix(ohos): 完善表单上传生命周期与响应处理` | 2 |
| 09 | `fix(ohos): 适配青春川大移动布局与首屏展示` | 1 |
| 10 | `fix(ohos): 修复 WebView 原生主题切换与边缘回弹` | 11 |
| 11 | `feat(ohos): 接入备用图标切换与即时生效提示` | 6 |
| 12 | `feat(ohos): 添加对齐安卓的课表服务卡片` | 10 |
| 13 | `feat(ohos): 补齐环境信息并调整开发者页面` | 3 |
| 14 | `fix(ohos): 设置 API 20 安装下限与图标版本提示` | 3 |
| 15 | `feat(ohos): 汇总原生通道注册与补丁清单` | 4 |
| 16 | `test(ohos): 添加构建脚本与平台适配测试` | 14 |
| 17 | `docs(ohos): 记录依赖替代方案与完整锁表` | 4 |
| 18 | `docs(ohos): 记录同步阶段与功能验收状态` | 6 |
| 19 | `docs(ohos): 完善开发指南与构建脚本说明` | 8 |

## 01 · 恢复原有鸿蒙端支持文件

恢复原有鸿蒙端支持文件，包括原生工程基础配置、页面及资源，同时纳入当前忽略规则和维护约定。
这些原生基础文件来自原有鸿蒙工程，后续同步与适配在恢复的支持文件基础上展开。
本批提交所列文件的当前版本；原生通道、卡片、图标和构建适配等内容按后续批次记录。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/.gitignore'
  'ohos/AGENTS.md'
  'ohos/entry/.gitignore'
  'ohos/entry/build-profile.json5'
  'ohos/entry/hvigorfile.ts'
  'ohos/entry/oh-package.json5'
  'ohos/hvigor/hvigor-config.json5'
  'ohos/hvigorconfig.ts'
  'ohos/oh-package.json5'
  'ohos/AppScope/resources/base/element/string.json'
  'ohos/entry/src/main/ets/pages/Index.ets'
  'ohos/entry/src/main/resources/base/element/color.json'
  'ohos/entry/src/main/resources/dark/element/color.json'
  'ohos/entry/src/main/resources/base/media/icon.png'
  'ohos/entry/src/main/resources/base/profile/main_pages.json'
  'ohos/entry/src/main/resources/rawfile/buildinfo.json5'
  'ohos/entry/src/main/resources/rawfile/framesconfig.json'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'chore(ohos): 恢复原有鸿蒙端支持文件' -m '恢复原有鸿蒙工程的基础配置、页面及资源，并纳入当前忽略规则和维护约定；后续提交在此基础上完成上游同步和平台适配。'
```

## 02 · 添加正式工具链校验与隔离构建入口

固定正式 Flutter OH / DevEco 工具链，提供独立工作副本、OH 专用缓存、版本同步和 unsigned HAP 构建。脚本采用最终版本，其余依赖配置和嵌入层辅助模块在后续批次加入。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/toolchain.lock.json'
  'ohos/tool/build_ohos.py'
  'ohos/tool/ohos_patches.py'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'build(ohos): 添加正式工具链校验与隔离构建入口'
```

## 03 · 固定鸿蒙依赖并适配 Flutter OH SDK

加入鸿蒙独立依赖声明、覆盖和锁文件，以及 Flutter SDK 差异和非 OH 插件隔离补丁。最终依赖锁整体提交，包含后续各功能需要的依赖，不人为拆出历史锁文件。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/pubspec_dependencies.json'
  'ohos/flutter/pubspec_overrides.yaml'
  'ohos/flutter/pubspec.lock'
  'ohos/flutter/patches/source/0001-flutter-sdk-compat.patch'
  'ohos/flutter/patches/source/0002-mobile-plugin-scope.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'build(ohos): 固定鸿蒙依赖并适配 Flutter OH SDK'
```

## 04 · 适配安全存储插件与异步错误返回

接入安全存储 9.2.4 的解析后兼容配置，补齐原生返回与错误类型，并保留旧缓存补丁的迁移依据。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/plugins/secure-storage.json'
  'ohos/flutter/patches/plugins/secure-storage-results.patch'
  'ohos/flutter/patches/plugins/secure-storage-error-types.patch'
  'ohos/flutter/patches/plugins/legacy/secure-storage-results-untyped-throw.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 适配安全存储插件与异步错误返回'
```

## 05 · 接入文件相册与 WebView 下载适配

加入文件选择、相册保存和下载 WebView 的基础适配，并修复保存字节及相册操作结果返回。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0003-file-and-gallery.patch'
  'ohos/flutter/patches/source/0004-webview-downloads.patch'
  'ohos/flutter/patches/plugins/file-picker-save-bytes.patch'
  'ohos/flutter/patches/plugins/gallery-save-result.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'feat(ohos): 接入文件相册与 WebView 下载适配'
```

## 06 · 完善外链分享日历与 Passpoint 调用

处理系统外链、选图、附件打开和分享结果，启用 ICS 日历交接，完善 Passpoint HTTP 业务操作。日历原生通道随第 15 批完整入口加入。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0005-external-links.patch'
  'ohos/flutter/patches/source/0006-files-images-and-share.patch'
  'ohos/flutter/patches/source/0007-calendar-handoff.patch'
  'ohos/flutter/patches/source/0008-passpoint-results.patch'
  'ohos/flutter/patches/plugins/open-file-result.patch'
  'ohos/flutter/patches/plugins/share-files-result.patch'
  'ohos/flutter/patches/plugins/image-picker-result.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 完善外链分享日历与 Passpoint 调用'
```

## 07 · 完善凭据恢复与跨账号会话保护

加入旧凭据恢复、登录持久化、退出与续期并发控制，以及子系统认证和报修 token 的账号绑定。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0009-session-recovery.patch'
  'ohos/flutter/patches/source/0010-subsystem-session-guards.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 完善凭据恢复与跨账号会话保护'
```

## 08 · 完善表单上传生命周期与响应处理

加入表单上传快照、账号切换清理、裁剪保存检查，以及空文件、响应状态和超时处理。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0011-form-upload-lifecycle.patch'
  'ohos/flutter/patches/source/0012-upload-responses.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 完善表单上传生命周期与响应处理'
```

## 09 · 适配青春川大移动布局与首屏展示

加入移动端视口与页面布局适配、禁用缩放、正文等待和美化后的展示控制。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0013-tuanwei-mobile-layout.patch'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 适配青春川大移动布局与首屏展示'
```

## 10 · 修复 WebView 原生主题切换与边缘回弹

加入通知页主题和布局控制、空消息离页确认处理、全局 WebView 边缘回弹禁用，以及插件和 Flutter HAR 的配置更新修复。0017 与 0018 同批，最终行为是不因切换主题主动刷新或重建 WebView。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0014-notice-dark-and-scroll.patch'
  'ohos/flutter/patches/source/0015-webview-theme-and-lifecycle.patch'
  'ohos/flutter/patches/source/0016-notice-layout-before-display.patch'
  'ohos/flutter/patches/source/0017-notice-reload-on-theme-change.patch'
  'ohos/flutter/patches/source/0018-notice-native-theme.patch'
  'ohos/flutter/patches/plugins/webview-configuration-update.patch'
  'ohos/flutter/patches/embedding/color-mode-update.patch'
  'ohos/flutter/patches/embedding/manifest.json'
  'ohos/tool/ohos_embedding.py'
  'ohos/tool/flutter_embedding_plugin.ts'
  'ohos/hvigorfile.ts'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 修复 WebView 原生主题切换与边缘回弹'
```

## 11 · 接入备用图标切换与即时生效提示

加入备用图标原生通道、应用图标资源和 Flutter 入口，调整鸿蒙确认文案。API 版本入口限制在第 14 批加入；应用版本仍由构建脚本从根 pubspec.yaml 同步。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0019-ohos-dynamic-icon.patch'
  'ohos/flutter/patches/source/0022-ohos-icon-confirmation.patch'
  'ohos/entry/src/main/ets/platform/DynamicIconChannel.ets'
  'ohos/AppScope/app.json5'
  'ohos/AppScope/resources/base/media/app_icon.png'
  'ohos/AppScope/resources/base/media/app_icon_old.png'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'feat(ohos): 接入备用图标切换与即时生效提示'
```

## 12 · 添加对齐安卓的课表服务卡片

加入 2*2、2*4、4*4 卡片、完整可滚动课表列表、当前课表快照、多实例同步、刷新与系统管理入口。完整字符串资源直接随本批加入。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0020-ohos-course-cards.patch'
  'ohos/entry/src/main/ets/cards/CourseCard.ets'
  'ohos/entry/src/main/ets/cards/CourseCardChannel.ets'
  'ohos/entry/src/main/ets/cards/CourseCardModel.ets'
  'ohos/entry/src/main/ets/cards/CourseCardStore.ets'
  'ohos/entry/src/main/ets/cards/CourseFormAbility.ets'
  'ohos/entry/src/main/resources/base/profile/course_card.json'
  'ohos/entry/src/main/resources/base/element/string.json'
  'ohos/entry/src/main/resources/en_US/element/string.json'
  'ohos/entry/src/main/resources/zh_CN/element/string.json'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'feat(ohos): 添加对齐安卓的课表服务卡片'
```

## 13 · 补齐环境信息并调整开发者页面

加入鸿蒙设备与环境信息通道、复制和失败重试能力，并移除鸿蒙开发者页的 UI Preview 入口。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0021-ohos-environment-info.patch'
  'ohos/flutter/patches/source/0023-ohos-remove-ui-preview.patch'
  'ohos/entry/src/main/ets/platform/EnvironmentInfoChannel.ets'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'feat(ohos): 补齐环境信息并调整开发者页面'
```

## 14 · 设置 API 20 安装下限与图标版本提示

加入最低 API 20 的构建配置示例及兼容性说明；API 低于 26 时点击图标入口提示鸿蒙 7 以下不支持。本批是代码和兼容性分析交付，不表示新增 API 20 真机验收。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/flutter/patches/source/0024-ohos-icon-api-gate.patch'
  'ohos/build-profile.json5'
  'ohos/docs/compatibility/api20.md'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'fix(ohos): 设置 API 20 安装下限与图标版本提示'
```

## 15 · 汇总原生通道注册与补丁清单

一次加入最终 EntryAbility、模块声明，以及源码和插件清单，连接前面已提交的功能。补丁应用顺序以 source/manifest.json 为准，与各补丁进入 Git 的先后无关。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/entry/src/main/ets/entryability/EntryAbility.ets'
  'ohos/entry/src/main/module.json5'
  'ohos/flutter/patches/source/manifest.json'
  'ohos/flutter/patches/plugins/manifest.json'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'feat(ohos): 汇总原生通道注册与补丁清单'
```

## 16 · 添加构建脚本与平台适配测试

加入现有 Python 测试、仅在隔离副本还原的 Flutter 测试模板、原生测试和执行说明。提交测试源码不代表本轮已执行测试。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/tests/README.md'
  'ohos/tests/flutter/platform_adapters_test.dart.template'
  'ohos/tests/python/test_build_ohos.py'
  'ohos/tests/python/test_ohos_patches.py'
  'ohos/entry/src/ohosTest/ets/test/Ability.test.ets'
  'ohos/entry/src/ohosTest/ets/test/List.test.ets'
  'ohos/entry/src/ohosTest/ets/testability/TestAbility.ets'
  'ohos/entry/src/ohosTest/ets/testability/pages/Index.ets'
  'ohos/entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ts'
  'ohos/entry/src/ohosTest/module.json5'
  'ohos/entry/src/ohosTest/resources/base/element/color.json'
  'ohos/entry/src/ohosTest/resources/base/element/string.json'
  'ohos/entry/src/ohosTest/resources/base/media/icon.png'
  'ohos/entry/src/ohosTest/resources/base/profile/test_pages.json'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'test(ohos): 添加构建脚本与平台适配测试'
```

## 17 · 记录依赖替代方案与完整锁表

> **已作废（2026-09-23）**：本节对应的双锁对比文档与生成脚本已按用户要求删除
> （`lock-inventory.md`、`overview.md`、`replacements.md`、
> `generate_ohos_dependency_inventory.py` 等）。鸿蒙不再维护独立锁文件，
> 保留本节仅作历史记录，命令不可再执行。

加入依赖调研、替代矩阵、完整 Dart 依赖对照及对应生成脚本，保留正式版本和固定 Git 提交依据。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/docs/dependencies/lock-inventory.md'
  'ohos/docs/dependencies/overview.md'
  'ohos/docs/dependencies/replacements.md'
  'ohos/tool/generate_ohos_dependency_inventory.py'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'docs(ohos): 记录依赖替代方案与完整锁表'
```

## 18 · 记录同步阶段与功能验收状态

加入第三至第五阶段实现说明、WebView 和业务代码排查、同步进度及后续安排。保留现有验证记录，不将阶段六持续检查或阶段七签名升级标记为已完成。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/docs/sync-plan.md'
  'ohos/docs/phases/phase3.md'
  'ohos/docs/phases/phase4.md'
  'ohos/docs/phases/phase5.md'
  'ohos/docs/audits/notice-webview.md'
  'ohos/docs/audits/phase3-code.md'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'docs(ohos): 记录同步阶段与功能验收状态'
```

## 19 · 完善开发指南与构建脚本说明

加入面向 GitHub 开发者的各级 README、最终目录与适配机制说明，以及本次提交清单。

暂存并检查：

```powershell
$ohosBatchFiles = @(
  'ohos/README.md'
  'ohos/flutter/README.md'
  'ohos/flutter/patches/source/README.md'
  'ohos/flutter/patches/plugins/README.md'
  'ohos/flutter/patches/embedding/README.md'
  'ohos/tool/README.md'
  'ohos/docs/flutter-adaptation.md'
  'ohos/docs/commit-plan.md'
)
git add -- $ohosBatchFiles
git diff --cached --stat
git diff --cached
```

确认本批差异后提交：

```powershell
git commit -m 'docs(ohos): 完善开发指南与构建脚本说明'
```

## 整组提交后的核对

完成全部批次后，在仓库根目录查看实际提交和最终范围：

```powershell
git status --short
git log --reverse --oneline e5c38070e154ab1a62b701534055e03ab9c8861f..HEAD
git diff --name-only e5c38070e154ab1a62b701534055e03ab9c8861f HEAD
```

本清单对应的文件应全部入库，最终相对基线的修改范围应仅为 `ohos/`。
如果准备后又有新增或修改，先调整对应批次，再执行命令；不要把后来的工作误计入本次清单。

需要构建验证时，使用 [构建脚本说明](../tool/README.md) 中的完整入口。
阶段六的双 SDK 持续检查、阶段七的正式签名与覆盖升级仍按原计划推进，
不因完成 Git 提交而自动视为通过。
