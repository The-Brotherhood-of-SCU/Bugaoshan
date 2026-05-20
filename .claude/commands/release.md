# Release Skill

为 Bugaoshan 项目创建新版本发布。按以下步骤执行：

**所有与用户的交互必须使用中文。**

## Step 1: 获取目标版本

如果用户在调用时提供了版本参数（如 `/release 1.2.0`），直接使用。否则，向用户询问目标版本号（格式：`X.Y.Z`，如 `1.1.0`）。在获得有效版本前不要继续。

## Step 2: 检查工作区

运行 `git status --short` 检查未提交的更改。如果有未提交的更改，**警告用户**并列出变更文件，询问是否继续或中止。未经用户确认不要继续。

## Step 3: 更新 pubspec.yaml

编辑 `pubspec.yaml`：将 `version:` 行改为 `version: X.Y.Z`（不含 `v` 前缀）。

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

## Step 5: 提交并打 tag

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
```

## Step 6: 推送前审查确认

推送前，向用户展示变更摘要以获取最终确认：

- 展示 `git diff HEAD~1`（提交差异），让用户审查 pubspec.yaml 和 CHANGELOG.md 的改动。
- 展示即将推送的 tag：`vX.Y.Z`。
- 询问用户确认：继续推送，还是中止（中止需执行 `git tag -d vX.Y.Z` 和 `git reset HEAD~1` 回退）。

只有用户明确确认后才继续推送。

## Step 7: 推送

```bash
git push && git push --tags
```

推送完成后，向用户确认发布已触发，说明 GitHub Actions 会自动检测到 tag 并构建发布。
