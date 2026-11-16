# 发布流水线（Release Pipeline）

工作流定义在 `.github/workflows/`，版本状态与发布说明由 `.github/scripts/changelog_sections.py` 统一解析。

## 1. 分支模型

```text
feature/fix/docs/*  --PR-->  preview（预览版/RC）  --PR-->  main（正式版）
```

- `preview`：日常集成分支，接受任意来源的 PR，合并即触发发布。
- `main`：只接受来自 `preview` 的 PR，合并即发布正式版。
- `main` 的 ruleset 要求 1 个 approve；pre-flight 目前不是 required status check。

## 2. 发布状态由 CHANGELOG 决定

取 `CHANGELOG.md` 中最高的 `## [X.Y.Z]` 正式版本章节，与最新正式 tag 比较：

| 条件 | 状态 | preview 合并 | main 合并 |
|---|---|---|---|
| 最高版本 == 最新正式 tag | 常态 | 发 `v<最新正式+1 patch>-preview[.N]`，说明取 `[Unreleased]` | 不发版（没有新版本） |
| 最高版本 > 最新正式 tag | 准备期 | 发 `v<最高版本>-rc[.N]`，说明取 `## [最高版本]` | 发 `v<最高版本>`，说明取同一章节 |
| 最高版本 < 最新正式 tag | 非法 | 失败 | 失败 |

不变量，任一不满足直接失败：

1. 有且只有一个高于最新正式 tag 的版本章节。
2. `[Unreleased]` 与高于最新正式 tag 的版本章节不能同时有内容。
3. `pubspec.yaml` 版本必须等于当前目标：常态等于最新正式 tag，准备期等于最高版本（分支流程断言）。
4. 正式版必须有非空的 `## [X.Y.Z]`；`[Unreleased]` 必须不存在或为空。
5. 同一版本只能有一个章节；代码块中的示例标题不算章节。

说明来源只有两个，不做回退：

- `-preview` tag → `[Unreleased]`；为空时发占位文案并 warning。
- `-rc` / 其他预发布 tag → 基础版本 `## [X.Y.Z]`；为空时失败。
- 正式 tag → `## [X.Y.Z]`；为空时失败。

## 3. 版本与 tag

- 正式版以 `pubspec.yaml` 的 `version: X.Y.Z+BBBB` 为准，tag = `vX.Y.Z`；tag 已存在时幂等跳过。`BBBB = major*10000 + minor*100 + patch`，F-Droid versionCode = `base*10 + 1/2/4`。
- 常态预览 tag 锚定最新正式 tag 并递增 patch 位：`v2.5.3` → `v2.5.4-preview`、`v2.5.4-preview.2`…
- 准备期 tag：`v2.6.0-rc`、`v2.6.0-rc1`、`v2.6.0-rc2`…
- 所有预览/RC 构建注入最新正式版的 versionName/versionCode；tag 与包体版本不同是设计如此。
- 合并到 `preview` 自动发预览/RC；合并 `preview → main` 自动发正式版。
- `release.yml` 只由 branch push（`main` / `preview`）和 `workflow_dispatch` 触发；不监听 tag push，tag 由发布流程在构建前自动创建。
- 手动 dispatch 到非 main/preview 分支只构建产物。

## 4. 一次发布的流程

1. 功能/fix PR → `preview`。pre-flight 运行分析、测试、代码生成漂移检查、`pre_release_check.py`（PR 门禁）。
2. 合并到 `preview`：自动发预览版。常态使用 `[Unreleased]`；准备期使用 `## [X.Y.Z]` 发 RC。
3. 准备正式版（[bugaoshan-release](.agents/skills/bugaoshan-release/SKILL.md)）：把 `[Unreleased]` 并入 `## [X.Y.Z]`，bump pubspec 与 F-Droid metadata，运行 `pre_release_check.py X.Y.Z`，推送 `preview` 触发 RC，再创建 `preview → main` PR。
4. 合并到 `main`：`release.yml` 先运行 `pre_release_check.py X.Y.Z` 严格检查（pubspec、CHANGELOG、F-Droid metadata 与 changelogs 一致），再打 tag、构建 Android/Windows/Linux、发布 Release（latest）；F-Droid changelog 由 CI 兜底生成。
5. 正式版发布后，下一轮常态预览从新的 `[Unreleased]` 开始；为空时预览说明显示占位文案。

## 5. 已知边界

- `on: push` 在分支创建时也会触发；从 `main` 创建 `preview` 会立即发一轮预览版。
- `preview` 每次合并都发版，没有跳过开关；纯文档改动也会发布预览，只能攒到下一轮或接受一轮预览。
- tag 在构建前推送；构建/发布失败会留下孤儿 tag。预览 tag 可随旧 release 清理；正式版孤儿 tag 需手动删除后重发。
- 发布采用 Draft → 上传 → Publish；上传失败会留下草稿，重试前先删除。
- preview 发布只保留最新一轮（cancel-in-progress）；被取消的 run 也可能留下孤儿 tag。
- `pubspec.lock` 锁定国内镜像；未设置 `PUB_HOSTED_URL` 时 pub get 会按 pub.dev 重解析，依赖与 `injector.config.dart` 可能漂移。setup 已统一设置。
- setup 的 `build_runner` 带 `|| true`，生成失败不会让 setup 直接报错，由干净树检查与测试兜底。
- F-Droid `metadata/*.yml` 与 changelogs 必须在 `preview → main` PR 前更新；正式版发布前的一致性检查会拦截缺失或版本不匹配。
- pre-flight 不是 required check，红/绿都不阻塞合并；真正的闸门是 review。要硬拦截需在仓库设置中把检查设为 required。
- `release.yml` 不监听 tag push；手动推任何 tag 都不会触发发布。tag 由发布流程在构建前自动创建。
- macOS DMG 由个人仓库 `wjlfish/Bugaoshan-macos` 独立构建发布；主仓库只发布 Android / Windows / Linux。

## 6. 文件

| 文件 | 职责 |
|---|---|
| `.github/workflows/pre-flight.yml` | PR/push 质量门禁 |
| `.github/workflows/release.yml` | 状态解析、打 tag、构建、发布 |
| `.github/workflows/build-{android,windows,linux}.yml` | 平台构建 |
| `.github/actions/setup/action.yml` | Flutter、依赖、代码生成、git 元数据 |
| `.github/scripts/changelog_sections.py` | CHANGELOG 解析、状态判定、说明选择 |
| `.github/scripts/resolve_release_version.py` | 状态、tag、版本注入 |
| `.github/scripts/release_changelog.py` | 发布说明提取 |
| `.github/scripts/metadata_changelog.py` | F-Droid 多语言 changelog |
| `tool/pre_release_check.py` | PR 门禁 / 正式版严格检查 |
