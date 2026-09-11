# 发布流水线（Release Pipeline）

本文描述仓库的两级分支发布流水线：一次变更从 Pull Request 到预览版、再到正式版的完整生命周期，以及流水线的版本号模型与已知边界情况。工作流定义见 `.github/workflows/`，版本推导脚本见 `.github/scripts/resolve_release_version.py`。

## 1. 分支模型与触发矩阵

仓库采用严格单向流转的两级分支流，**没有 dev 分支**：

```text
日常开发分支 (feat/*, fix/*, docs/* ...)
       │  发起 PR（触发 pre-flight 门禁）
       ▼
preview ──── 合并即自动发 vX.Y.Z-preview[.N] 预览版（Prerelease）
       │  仅允许来自 preview 的 PR（触发 pre-flight 门禁）
       ▼
main ─────── 合并即自动发 vX.Y.Z 正式版（Latest Release & F-Droid）
```

| 分支 | 职责 | 发布行为 |
|---|---|---|
| `preview` | 预览发布分支，兼日常集成分支，直接接收 feature/fix/docs PR | 每次合并**必然**触发一轮预览版发布（无跳过开关） |
| `main` | 正式版生产分支，仅接收来自 `preview` 的 PR | 从 `pubspec.yaml` 推导 `vX.Y.Z`；tag 已存在则幂等跳过 |

各工作流的触发矩阵：

| 事件 | pre-flight 门禁 | branch-policy | release.yml |
|---|---|---|---|
| 打开 / 更新 PR（→ main 或 preview） | ✅ | ✅（仅 PR 事件） | ❌ |
| push / 合并进 `main` | ✅ | ❌ | ✅ formal 通道 |
| push / 合并进 `preview` | ✅ | ❌ | ✅ preview 通道 |
| push tag `v*.*.*` | ❌ | ❌ | ✅（手动发版的兼容入口） |
| 手动 `workflow_dispatch` | 可选 | ❌ | ✅（可选 channel 与 version_override） |

branch-policy 只做一条硬校验：**`main` 只能接收来自 `preview` 的 PR**；`preview` 接受任意来源分支。该检查仅存在于 PR 事件，真正的强制落地还需要 GitHub 侧把 pre-flight 配置为 required status check（见 §4.4）。

## 2. 一次变更的完整生命周期

以功能分支 `feat/foo` 为例：

1. **切分支并开发**：从 `preview` 切出 `feat/foo`，开发并推送。
2. **发起 PR → `preview`**：pre-flight 门禁执行——
   - 分支策略检查（`preview` 接受任意来源，仅记录日志）；
   - `dart analyze --fatal-infos`；
   - 代码生成物干净树检查：setup 阶段已运行 `flutter pub get`、`build_runner`、`flutter gen-l10n`，之后 `git status --porcelain` 必须为空；
   - `flutter test` 全量测试；
   - Python 自动化脚本单测（`.github/scripts/tests/`）；
   - `tool/pre_release_check.py --ci --prerelease`：版本格式、CHANGELOG 结构等**结构性 FAIL 会拦截**；发布时机类检查（版本递增 / tag 冲突 / Unreleased 空置）为 **WARN** 提示。
3. **合并进 `preview`**：push 事件同时触发 pre-flight 重跑与 release.yml preview 通道——
   - `resolve_release_version.py` 从 `pubspec.yaml` 取基础版本 `X.Y.Z`，按远端已有 tag 推导 `vX.Y.Z-preview`（首次）或递增序号 `vX.Y.Z-preview.N`；
   - workflow 自动打 tag（`resolve-metadata` job，需要 `contents: write`，推送失败立即终止本次发布）；
   - `build-android.yml`（universal + split-per-ABI，混淆，JDK 21）与 `build-windows.yml`（zip）并行构建；
   - 发布走 **Draft → 上传产物 → Publish** 顺序，兼容仓库的不可变 Release 策略，标记为 prerelease；
   - 预览版的 release notes 取 `CHANGELOG.md` 第一个章节（即 `[Unreleased]`），对比范围为上一个**正式** tag。
4. **周期内迭代**：后续变更继续以 PR 合入 `preview`，预览版序号自动递增（`.2`、`.3`…）。
5. **准备正式版（`/release X.Y.Z`）**：bump `pubspec.yaml` 版本（保留 `+buildNumber`）、将 `[Unreleased]` 重命名为 `[X.Y.Z] - 日期`、更新 F-Droid 元数据（`metadata/*.yml` 的 versionName/versionCode + `metadata_changelog.py` 生成多语言 changelogs）、本地跑严格模式 `pre_release_check.py X.Y.Z`，提交推送 `preview` 后创建 `preview → main` 的发布 PR。
6. **合并进 `main`**：release.yml formal 通道——
   - 基础版本读自 pubspec；远端不存在 `vX.Y.Z` → 打 tag、双端构建、发布正式 Release（`--latest`）；
   - F-Droid changelog 由 `metadata_changelog.py --skip-existing` 生成并兜底提交回 `main`；
   - `vX.Y.Z` 已存在 → `should_release=false`，秒级跳过，不会重复发布。
7. **事后**：main 的 push 再触发一次 pre-flight（结构性检查照常硬拦截；时机类检查在两个版本之间的正常状态下为 WARN，不会长期挂红）。

## 3. 版本号模型

- **唯一事实来源是 `pubspec.yaml` 的 `version: X.Y.Z+BBBB`**，流水线不做任何版本推断。`BBBB`（buildNumber）= `major*10000 + minor*100 + patch`（如 `2.5.1+20501`）；F-Droid 的 ABI versionCode = `base*10 + 1/2/4`（如 2.5.1 → 205011 / 205012 / 205014）。
- **发 2.5.2 还是 2.6.0 完全是人的决策**，落点是「谁在什么时候 bump pubspec」。流水线的全部智能只有：给预览通道追加 `-preview[.N]` 自动序号；对 formal 通道做「tag 已存在即跳过」的幂等守卫。
- **周期开始 bump 约定**：一个正式版发布后、下一轮预览开始前，应先把 `pubspec.yaml` bump 到下一个目标版本。否则周期内的预览 tag 会沿用上一版本号（如 `v2.5.1-preview.2`），在 semver 排序上**倒挂**于已发布的 `v2.5.1` 正式版（prerelease 排在 release 之前），任何按 semver 比较的工具都会视其为旧版本。脚本与预检在「预览版基础版本 == 最新正式 tag」时会输出 WARN 提醒。
- 预览版推导只识别 `-preview` / `-preview.N` 形态；历史上的 `-pre1`、`-rc1`、`-preview2` 等命名不会被自动递增逻辑匹配。需要特殊后缀（如 `-rc1`）时，通过 `workflow_dispatch` 的 `version_override` 手动触发。

## 4. 边界情况与已知风险

### 4.1 创建分支即触发发布
`on: push` 事件在**分支创建时同样触发**。从 `main` 创建 `preview` 分支的瞬间，release.yml 就会以当时的 pubspec（可能还是上一个正式版）发一轮预览版。启用流水线时的规避方式见 §5。

### 4.2 preview 通道没有跳过开关
每次合入 `preview` 都会真实构建并发版。不要把 preview 当作「只合代码、不发版」的集成分支使用；不希望发版的改动（如纯文档微调）也应接受一次预览版，或攒到下一轮一起合。

### 4.3 代码生成物漂移对 SDK 版本敏感
`lib/injection/injector.config.dart` 由 build_runner 经 **SDK 自带的 dart_style** 格式化，输出随 Flutter patch 版本变化。CI 在 setup action 中精确钉住 `flutter-version: "3.44.9"`，生成物以 CI 产物为准；本地 SDK 版本不同时重新生成可能产生纯格式 diff，不要把它提交回去。`pubspec.lock` 锁定的是国内镜像 `pub.flutter-io.cn`，setup action 需要设置 `PUB_HOSTED_URL`，否则 CI 的 `pub get` 会把 lock 全量翻成 pub.dev 造成漂移。

### 4.4 门禁红不等于挡合并
`main` 的 ruleset（`protect-main`）要求 1 个 approve、评论必须解决、禁止删除与强推，但**未配置 required status checks**。pre-flight 挂红只是展示性的，不阻塞合并；流程的真正闸门是人工 review。若要让门禁硬生效，需在仓库设置中将 pre-flight 的 check 配为 required。

### 4.5 预览 tag 竞态
preview 短时间连续两次 push 时，两个 run 都可能在对方 tag 落地前推导出同一个 `vX.Y.Z-preview`。tag 推送失败会使当前 run 快速终止（宁可早失败，不在 20 分钟构建后死在 publish 阶段）；重新合并或空 push 即可重试。

### 4.6 version_override 无预检
`workflow_dispatch` 传入 `version_override` 时不做「tag 是否已存在」检查，遇到已存在的 tag 会在构建完成后才于 publish 阶段失败。手动触发前先确认目标 tag 未被占用。

### 4.7 不会递归触发
CI 自己的 `git push`（自动 tag、F-Droid metadata 兜底提交）使用 `GITHUB_TOKEN`，GitHub 不会为 GITHUB_TOKEN 产生的事件新建 workflow run，因此发布流程不会自我连环触发。

### 4.8 CHANGELOG 的两条提取路径
`release_changelog.py`：版本号含 `-`（预览版）→ 取 CHANGELOG 第一个 `##` 章节，缺失时降级为占位文案；正式版 → 严格匹配 `[X.Y.Z]` 章节，缺失或为空直接报错终止。因此预览版发布前应保证 `[Unreleased]` 有内容，且**不要**在预览阶段重命名该章节。

### 4.9 F-Droid 元数据需要先行
`metadata/*.yml` 的 versionName/versionCode 不会由流水线自动生成，必须在 `preview → main` 发布 PR 之前手动补齐（`/release` 命令包含此步骤），否则 pre-flight 的结构性检查会 FAIL；`metadata/{lang}/changelogs/*.txt` 由 CI 在正式发布时兜底生成并提交回 `main`。

### 4.10 手动严格模式与 CI 门禁模式的分界
`tool/pre_release_check.py` 手动运行（`/release` 流程）为严格模式：版本递增、tag 冲突、Unreleased 空置等一律 FAIL，用于发布前拦截。`--ci` 模式运行在任意 PR/push 上，代码库常处于「两个版本之间」的正常状态，上述时机类检查降级为 WARN，结构性检查（版本格式、pubspec 解析、CHANGELOG 结构、F-Droid 元数据）保持 FAIL。

### 4.11 fork PR 的推送方式
外部贡献者的 PR 分支位于其 fork。维护者推送修正提交依赖 PR 的 `maintainer_can_modify`；仓库启用 git-lfs 时，直接推送需跳过 LFS pre-push 钩子（`git push --no-verify`，仅当变更不含 LFS 文件时安全）。

## 5. 启用时序（一次性）

流水线随引入它的 PR 合入 `main` 而生效，启用时需要注意：

1. 引入 PR 本身合入 `main` 时，formal 通道因「tag 已存在」而跳过（若 pubspec 未 bump），不会误发版。
2. 创建 `preview` 分支前，先在本地基于 `main` 制作一个 pubspec bump commit（目标版本号在此刻决定：2.5.2 还是 2.6.0），然后直接 `git push origin <sha>:refs/heads/preview`——让分支以已 bump 的提交创建，避免 §4.1 所述的「分支创建触发一轮旧版本号的预览发布」。
3. 此后进入 §2 的常规循环：feature PR → preview；正式版经 `/release` 走 `preview → main`。

## 6. 相关文件

| 文件 | 职责 |
|---|---|
| `.github/workflows/pre-flight.yml` | PR/push 质量门禁与分支策略 |
| `.github/workflows/release.yml` | 双通道发布：版本推导、打 tag、构建、发布 |
| `.github/workflows/build-android.yml` / `build-windows.yml` | 双端构建（可独立 workflow_call 复用） |
| `.github/actions/setup/action.yml` | 公共环境：钉版 Flutter、镜像 pub get、代码生成、git 元数据 |
| `.github/scripts/resolve_release_version.py` | 通道判定、tag 推导、幂等守卫 |
| `.github/scripts/release_tags.py` / `release_changelog.py` / `release_body.py` / `release_prepare.py` | 发布说明与产物整理 |
| `.github/scripts/metadata_changelog.py` | F-Droid 多语言 changelogs 生成 |
| `tool/pre_release_check.py` | 发布前静态检查（手动严格 / `--ci` 门禁两种模式） |
| `.claude/commands/release.md` / `prerelease.md` | `/release` 与 `/prerelease` 操作流程 |
