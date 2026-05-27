# Prerelease Skill

为 Bugaoshan 项目创建预览版发布。按以下步骤执行：

**所有与用户的交互必须使用中文。**

## Step 1: 获取预览版名称

如果用户在调用时提供了参数（如 `/prerelease v1.2.3-preview`），直接用作预览版名称。否则，向用户询问预览版名称（如 `v1.2.3-preview`、`v1.2.3-rc1`、`v1.2.3-beta` 等）。

## Step 2: 检验版本号

从 `pubspec.yaml` 读取当前 `version:` 字段，提取基础版本号。

验证：预览版名称版本号语义上必须>基础版本号。否则警告。

## Step 3: 检查工作区

运行 `git status --short` 检查未提交的更改。如果有未提交的更改，**警告用户**并列出变更文件，询问是否继续或中止。未经用户确认不要继续。

## Step 4: 检查 CHANGELOG.md

读取 `CHANGELOG.md`，检查 `## [unreleased]` 条目是否存在且有内容。

- **如果有内容**：转到下一步。
- **如果为空或不存在**：警告用户，然后提供两个选项：
  1. **从 commit 自动生成**（推荐）— 启动子代理读取上一个稳定版本 tag 以来的 git log，生成 changelog 条目。
  2. **跳过** — 该预览版将没有 changelog 条目，继续发布。

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

将子代理的输出插入 `## [unreleased]` 条目（若不存在则先创建）。

## Step 5: 推送前审查确认

向用户展示变更摘要以获取最终确认：

- 即将创建的 tag：`vX.Y.Z-{后缀}`
- 注意：不会修改 `pubspec.yaml` 版本号
- 询问用户确认：继续推送，还是中止。

只有用户明确确认后才继续。

## Step 6: 打 tag 并推送

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG prerelease 条目"  # 仅在 CHANGELOG 有变更时
git tag vX.Y.Z-{后缀}
git push && git push --tags
```

推送完成后，向用户确认发布已触发，说明 GitHub Actions 会自动检测到 tag 并构建预览版发布（标记为 prerelease）。
