# 在本地 CPF Git 仓库维护独立 OH 包

2026-09-23 按用户要求采用本地 Git 修改方式。两个仓库保留 CPF origin 和历史，
在各自的 `codex/ohos-platform-packages` 分支新增独立包，应用通过 path 引用这些普通源码目录。
构建不会自动 Git 拉取、重新组装或覆盖源码；直接修改独立包内的文件即可。

## 源码位置

| 包 | CPF 基线提交 | 独立包目录（相对仓库根） |
| --- | --- | --- |
| package_info_plus_ohos 0.1.0 | `bc4df814a726042a9dad1a267ebb1d2973544e24` | `ohos/vendor/cpf/package_info_plus/packages/package_info_plus/package_info_plus_ohos` |
| share_plus_ohos 0.1.0 | `bfd882da6893c4c8bfa1648ac637c2d557e6f4fa` | `ohos/vendor/cpf/share_plus/packages/share_plus/share_plus_ohos` |

源仓库都是 [CPF-Flutter/flutter_plus_plugins](https://gitcode.com/CPF-Flutter/flutter_plus_plugins)，
原主包版本分别为 9.0.0、12.0.1；独立包的 0.1.0 是本地集成版本。
各包包含 pubspec、许可证和完整 ohos 模块，只依赖 Flutter SDK，没有主包的 Dart 和其他平台依赖。
原生模块名称改为独立包名，保留原来的导出类与通道名；原主包目录仍保留作对照。
Flutter HAR 沿用应用锁定 SDK 的接入方式。

修改分享时，直接编辑新 share_plus_ohos 内的：

- `ohos/src/main/ets/dev/fluttercommunity/plus/share/MethodChannelHandlerImpl.ets`：解析统一 share 请求。
- `ohos/src/main/ets/dev/fluttercommunity/plus/share/Share.ets`：文件准备和系统分享调用。

应用信息的 PackageInfoPlugin.ets 直接复用原实现，无需新的 Dart 适配层。
分享支持 hosted 平台接口 6.1.0 和根锁 7.2.0 的统一 share 协议，修正 title/subject 次序、
文件复制等待和句柄关闭；按传入 MIME 类型识别文件，并隔离每次请求和同名文件。
文字、链接用 SINGLE 模式，文件用 BATCH；批量文件附带的文字放在首个文件记录，
接收方是否采用 content/description 仍需真机验证。

分享调用失败会通过通道返回错误；成功调起面板后返回 unavailable，未接入最终分享结果事件。
成功后的文件留在应用缓存，避免接收方尚未读取就被删除；当前没有主动定期清理。

## 接入状态与版本

两个本地包版本均为 0.1.0，在根 [pubspec.yaml](../../../pubspec.yaml) 的
`dependency_overrides` 指定 path 来源，没有额外的直接依赖声明。
根锁完全采用 main `7fab588` 的 205 项基线，这两个本地包尚未记录在当前锁中。
鸿蒙工作目录继承根声明和 overrides，把路径转换为相对 `ohos/.flutter-workspace/` 的路径；
不再在 [pubspec_dependencies.json](../../flutter/pubspec_dependencies.json) 中重复声明。
构建入口会检查独立包是否存在，并要求注册列表包含两个新的 OH 包名。
本地 pubspec 变化会使依赖准备指纹失效；原生源码直接参与构建，不经过覆盖生成器。

这两个独立 OH 包通过根 overrides 指定来源，以下主包和接口直接沿用根声明与根锁：

| 包 | 根锁版本 | 来源 |
| --- | --- | --- |
| package_info_plus | 10.2.1 | hosted |
| share_plus | 13.3.0 | hosted |
| share_plus_platform_interface | 7.2.0 | hosted |

file_picker_ohos 10.3.8 的完整原始源码已下载在 `ohos/vendor/cpf/file_picker/`，
HEAD 为 `1a38f43d7c2e976c2add2c057da79223a0913f84`，与远端正式 tag 10.3.8-ohos-1.0.0 一致。
该仓库未修改、未拆分，仍有 `win32: ^5.9.0` 的约束，本次不加入根锁；按用户要求留到下一次适配。
当前主包已采用根锁，但文件选择器的 win32 约束冲突仍需后续迁移解决。

2026-09-23 按用户要求将 [CPF open_filex](https://gitcode.com/CPF-Flutter/fluttertpc_open_filex)
完整仓库下载到 `ohos/vendor/cpf/open_filex/`，保留 origin 和 Git 历史，工作区固定为 detached HEAD
`513644d7a1320d5a9e8f14b97c1bb5c4ec4a2ced`（`br_v4.7.0_ohos_dev`，主包版本 4.7.0）。
鸿蒙原生源码位于 `ohos/vendor/cpf/open_filex/ohos/`，用于后续提取独立包。
当前仅下载原始源码，尚未创建 `open_filex_ohos` 或接入依赖；根 open_filex 仍采用 hosted 4.7.0。

随后用户选择 CPF 已有的 `open_file_ohos 1.0.0`，并将其从根 override 移至普通 `dependencies`。
来源为 [CPF open_file](https://gitcode.com/CPF-Flutter/fluttertpc_open_file) 的 `ohos/` 包，
固定正式 tag `3.4.0-ohos-1.0.0` 对应提交 `85db425fc4b8cc403983fc854a36da6f300ad952`。
它要求的 `plugin_platform_interface ^2.0.2` 可由根锁现有的 2.1.8 满足，未修改其他包记录。
该包直接通过 Git 引用，未复制到 vendor。统一入口 `openFile(path)` 位于
[根 lib/utils/open_file.dart](../../../lib/utils/open_file.dart)：OH 调用 `open_file_ohos.OpenFile.open`，
其他平台调用官方 `OpenFilex.open`，将 OH 返回的五种状态和消息转换为官方 `OpenResult`。
附件弹窗和下载管理在根文件中直接调用 `openFile`，只增加平台分发和返回类型转换，原来的两个页面覆盖及打开工具覆盖已删除；
根日历导入及其 OH 覆盖的通用文件打开分支也调用该入口，
OH 日历导入继续使用已有原生通道。构建检查已改为要求 `open_file_ohos`，不再要求 open_filex 提供 OH 实现。
该入口只统一调用与返回类型，未修改上游插件的原生错误处理或提前返回成功的行为。
根锁保留 main 的 205 项基线，不手写该包的锁记录，后续由用户执行 Pub 生成。
此次未执行依赖解析、测试或构建。

此前加入本地包时，根锁曾使用锁定 Flutter OH 自带的 Dart Pub 更新并通过 --enforce-lockfile 校验，
从 210 项增至 212 项；既有 210 项的版本、来源、依赖分类和 SDK 约束均未变化。
直接运行 Dart Pub，未触发 Flutter 代码生成。根锁的 package_info_plus 10.2.1、share_plus 13.3.0、
file_picker 12.0.0 和 win32 6.4.0 均保持原版本。

鸿蒙现已改用根 `pubspec.lock`，不再维护独立 OH 锁。准备时复制根锁并转换其中本地 path 包的
相对路径，使用 `--enforce-lockfile`。鸿蒙继承根依赖与 overrides，但当前根锁尚未包含这 8 个 OH 包，
严格校验会失败；依赖解析和兼容性留待后续处理。准备入口为：

```powershell
python ohos/tool/build_ohos.py --prepare-only
```

本次同步 main 基线只修改声明和锁文件，未运行依赖解析、测试或构建；
上述 Pub 校验是先前加入两个本地包时的历史记录，不代表当前配置已通过验证。

## Git 保存方式

两个独立包已分别在各自 CPF 仓库的 `codex/ohos-platform-packages` 分支本地提交，尚未推送：
`package_info_plus_ohos` 为 `0a73f367`，`share_plus_ohos` 为 `a6f19c1e`。
后续变更仍在相应 CPF 仓库内查看、提交，例如：

```powershell
git -C ohos/vendor/cpf/share_plus status
git -C ohos/vendor/cpf/package_info_plus status
```

`ohos/vendor/cpf/` 被主项目忽略，主项目提交不会带上这些嵌套仓库，也未配置 submodule。
换机器时需要另行保留或取得含本地新增包的 CPF 分支；只克隆 CPF 原基线不会包含新包。
根工程现在也依赖这两个本地目录，干净检出或 CI 同样需要提供这些未发布包的源码，才能执行 Pub。

此前自动组装尝试产生的缓存已移入 `ohos/vendor/cpf/retired-auto-assembly/` 保留，
没有构建脚本或依赖引用该目录。自动拉取与组装流程已撤回。
