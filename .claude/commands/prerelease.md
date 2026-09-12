# Prerelease Skill

为 Bugaoshan 项目准备预览版发布。按以下步骤执行：

**所有与用户的交互必须使用中文。**

> **流水线背景**：仓库采用 `feature -> preview -> main` 两级流水线。变更合并进
> `preview` 分支后，`release.yml`（preview 通道）自动推导 tag：常态（pubspec 与
> 最新正式版一致）为最新正式版递增 Z 位加 `-preview[.N]`（如上一正式版 v2.5.1 →
> `v2.5.2-preview`、`-preview.2`…）；`/release` bump 之后进入准备期，切换为 rc
> 命名（`vX.Y.Z-rc`、`-rc1`…）。预览构建的包体版本号统一注入上一正式版。本命令
> 只准备 CHANGELOG 并推送到 `preview`，**不修改 `pubspec.yaml`，也不手动打 tag**。
>
> 注意：其他自定义后缀（`-beta` 等）仍需在 GitHub Actions 手动触发 `release.yml`
> 并通过 `version_override` 指定。

## Step 1: 检查工作区与分支

- 运行 `git status --short` 检查未提交的更改。如果有未提交的更改，**警告用户**并列出变更文件，询问是否继续或中止。未经用户确认不要继续。
- 运行 `git branch --show-current` 确认当前在 **`preview`** 分支。若不是，说明预览版发布必须在 `preview` 上进行，询问用户是否切换：

  ```bash
  git fetch origin && git checkout preview && git pull origin preview
  ```

- 校验 pubspec 与最新正式 tag 的一致性：取最新正式 tag（`git tag -l "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | head -n 1`）并与 `pubspec.yaml` 的 `version:` 比较——**一致**为常态，直接继续；pubspec **落后**则警告用户先对齐（否则下一次正式发布会被幂等守卫卡住）；pubspec **领先**说明处于 `/release` 准备期，告知用户本轮预览将使用 `-rc` 命名（若本意是发正式版，建议改走 `/release`）。

## Step 2: 检查 CHANGELOG.md

读取 `CHANGELOG.md`，检查 `## [Unreleased]` 条目是否存在且有内容。

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

将子代理的输出插入 `## [Unreleased]` 条目（若不存在则先创建）。

**不要重命名 `[Unreleased]` 章节**：预览版的 release body 取 CHANGELOG 第一个章节的内容，`[Unreleased]` 留到正式版 `/release` 时才重命名为 `[X.Y.Z]`。

## Step 3: 本地预检

```bash
python tool/pre_release_check.py --ci --prerelease
```

- 该命令为 CI 门禁模式：发布时机类检查（版本号递增、tag 冲突、`[Unreleased]` 空置）为 **WARN** 提示，向用户展示即可。
- 版本号格式、CHANGELOG 结构等**结构性 FAIL** 必须处理后重跑，通过前不要继续。

## Step 4: 提交并推送 preview

推送前，向用户展示变更摘要以获取最终确认：

- 本次预览版基于 `X.Y.Z`，最终 tag 由流水线自动推导，**不会修改 `pubspec.yaml`**。
- 询问用户确认：继续推送，还是中止。

只有用户明确确认后才继续：

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG prerelease 条目"  # 仅在 CHANGELOG 有变更时
git push origin preview
```

推送完成后，向用户确认预览版流水线已触发：CI 会自动创建 `vX.Y.Z-preview`（或递增序号）tag、构建并发布 GitHub Prerelease。全程**不要手动 `git tag` / `git push --tags`**。
