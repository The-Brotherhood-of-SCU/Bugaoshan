# Release Skill

为 Bugaoshan 项目准备正式版发布。按以下步骤执行：

**所有与用户的交互必须使用中文。**

> **流水线背景**：仓库采用 `feature -> preview -> main` 两级流水线，`main` 只接收
> 来自 `preview` 分支的 PR。合并进 `main` 后，`release.yml` 会自动从 `pubspec.yaml`
> 推导 `vX.Y.Z` tag、构建双端产物并发布 GitHub Release（latest）。本命令只负责
> **准备发布内容并发起 PR**，不再手动打 tag / 推 tag。

## Step 1: 获取目标版本

如果用户在调用时提供了版本参数（如 `/release 1.2.0`），直接使用。否则，向用户询问目标版本号（格式：`X.Y.Z`，如 `1.1.0`）。在获得有效版本前不要继续。

## Step 2: 检查工作区与分支

- 运行 `git status --short` 检查未提交的更改。如果有未提交的更改，**警告用户**并列出变更文件，询问是否继续或中止。未经用户确认不要继续。
- 运行 `git branch --show-current` 确认当前在 **`preview`** 分支。若不是，说明正式版发布准备必须在 `preview` 上进行（`main` 只接收来自 `preview` 的 PR），询问用户是否切换：

  ```bash
  git fetch origin && git checkout preview && git pull origin preview
  ```

## Step 3: 更新 pubspec.yaml

编辑 `pubspec.yaml`：将 `version:` 的 `X.Y.Z` 部分改为目标版本，**保留 `+buildNumber` 后缀并按现有规则同步更新**（buildNumber = `major*10000 + minor*100 + patch`，如 `2.5.1+20501` -> `2.6.0+20600`）。若 `pubspec.yaml` 已经是目标版本（例如重复执行本命令），跳过本步。

## Step 4: 更新 CHANGELOG.md

读取 `CHANGELOG.md`，查找 `## [Unreleased]` 条目。

- **如果 `[Unreleased]` 存在且有内容**：直接进入下方的重命名步骤。
- **如果 `[Unreleased]` 为空或不存在**：警告用户，然后提供两个选项：
  1. **从 commit 自动生成**（推荐）— 启动子代理读取上一个稳定版本 tag 以来的 git log，生成 changelog 条目。
  2. **跳过** — 使用空的 changelog 继续发布。

### 自动生成 changelog（选项 1）

启动一个 Agent（subagent_type: general-purpose），prompt 如下：

> Read the git log from the last stable release tag to HEAD. Run:
> ```
> # Find last stable tag — must match vX.Y.Z exactly (no pre-release suffix like -beta, -rc1)
> git tag -l "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | head -n 1
> git log <last-tag>..HEAD --pretty=format:"%s" --no-merges
> ```
>
> Classify each commit message by its Conventional Commits prefix into these sections:
> - `### Added` — for `feat:` commits
> - `### Changed` — for `refactor:`, `perf:`, `build:`, `ci:` commits
> - `### Fixed` — for `fix:` commits
> - `### Removed` — for commits that remove functionality
> - Drop `docs:`, `chore:`, `test:`, `style:` commits (internal-only).
>
> For each commit, strip the prefix and convert to a bullet point in Chinese (matching the existing CHANGELOG.md style). If a commit message is already in Chinese, keep it as-is. Output ONLY the classified markdown sections, nothing else. Example output:
>
> ```
> ### Added
> - 添加xxx功能
> - 新增yyy页面
>
> ### Changed
> - 优化zzz性能
>
> ### Fixed
> - 修复aaa问题
> ```

将子代理的输出插入 `[Unreleased]` 条目。

### 重命名并创建占位符

条目有内容后（无论是原有的还是自动生成的）：
1. 将 `## [Unreleased]` 替换为 `## [X.Y.Z] - YYYY-MM-DD`（当天日期，ISO 格式）。
2. 在版本条目**上方**插入新的空 `## [Unreleased]` 占位符，用空行分隔：
   ```
   ## [Unreleased]

   ## [X.Y.Z] - YYYY-MM-DD
   ```

## Step 5: 更新 F-Droid 元数据

1. 运行 `python .github/scripts/metadata_changelog.py --skip-existing`，为 `X.Y.Z` 生成 `metadata/{en-US,zh-CN}/changelogs/` 下的版本说明文件（versionCode = `base*10 + 1/2/4`，如 2.6.0 -> 206001 / 206002 / 206004）。
2. 编辑 `metadata/*.yml`：参照既有版本条目的写法，在 Builds 中追加新版本，`versionName` 为 `X.Y.Z`，三个 ABI 的 `versionCode` 按上述公式填写。

## Step 6: 本地发布前检查

```bash
python tool/pre_release_check.py X.Y.Z
```

- 该命令为**严格模式**：版本号递增、tag 冲突、CHANGELOG `[X.Y.Z]` 章节、F-Droid 元数据等任何 FAIL 都必须处理后重跑，通过前不要继续。
- 若提示「已存在 tag vX.Y.Z」，说明该版本已发布过，停止并提示用户更换版本号。
- WARN 项（如 CHANGELOG 日期、Unreleased 占位符残留）向用户展示并人工确认。

## Step 7: 提交并推送 preview

推送前，向用户展示变更摘要以获取最终确认：

- 展示 `git diff HEAD~1`（提交差异），让用户审查 pubspec.yaml、CHANGELOG.md 与 metadata 的改动。
- 说明推送 `preview` 会自动触发预览版构建（tag 由流水线推导为 `vX.Y.Z-preview` 或下一序号）。
- 询问用户确认：继续推送，还是中止（中止需 `git reset HEAD~1` 回退提交）。

只有用户明确确认后才继续：

```bash
git add pubspec.yaml CHANGELOG.md metadata/
git commit -m "chore: release vX.Y.Z"
git push origin preview
```

## Step 8: 创建 preview -> main 发布 PR

```bash
gh pr create --base main --head preview --title "release: vX.Y.Z" --fill
```

创建后向用户说明：

- PR 合并进 `main` 后，流水线自动创建 `vX.Y.Z` tag、构建并发布正式版（GitHub Release latest），F-Droid 元数据 changelog 由 CI 兜底提交。
- 若 `vX.Y.Z` tag 已存在，流水线会幂等跳过，不会重复发布。
- 全程**不要手动 `git tag` / `git push --tags`**，tag 完全由 CI 管理。
