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

- 使用版本解析器中的 `latest_formal()` 筛选严格的正式 tag，再与 `pubspec.yaml` 的 `version:` 比较——**一致**为常态；pubspec **落后**则提示先对齐；pubspec **领先**说明处于 `/release` 准备期，本轮预览将使用 `-rc` 命名。

## Step 2: 整理目标预览版本说明

先从 `.github/scripts/resolve_release_version.py` 的 `resolve_release()` 以 `preview` 分支上下文只读解析目标 tag；使用当前远端 tag 集合，不执行打 tag 或推送。常态目标可能是 `vX.Y.Z-preview[.N]`，正式版准备期为 `vX.Y.Z-rc[N]`。

若用户给出了目标 tag，核对它与本次发布上下文一致；自定义后缀通过 `workflow_dispatch` 的 `version_override` 发布。不要将 `pubspec.yaml` 中上一正式版的包体版本当作本次预览 tag。

读取 `.agents/skills/bugaoshan-changelog/SKILL.md`，创建或更新 `## [完整目标版本]` 章节（标题不带 tag 的 `v` 前缀，发布日期确定后可补日期）。已有同版本说明按实际覆盖点增量补充，保留其他版本。

如果筛选后没有用户可感知的变化，明确说明；用户选择不提供本次说明时允许继续，发布端会显示占位文案。不能借用其他预览、RC 或正式版的条目。

## Step 3: 本地预检

以本次完整目标版本调用，不能只传基础版本：

```bash
python tool/pre_release_check.py X.Y.Z-preview.2 --prerelease
```

- 本地严格模式要求目标章节存在且有有效内容；结构错误、重复章节等 FAIL 必须先处理。
- 用户明确选择本次无更新说明时，可用 `--ci` 运行同一明确版本的检查，将缺少预览说明作为 WARN 报告；其余结构性 FAIL 仍须处理。
- 日常 PR 门禁使用 `--ci --prerelease --changelog-structure-only`，只检查版本章节结构，实际发布时再根据最终解析的 tag 提取内容。它不能代替本次明确目标版本的准备检查。

## Step 4: 提交并推送 preview

推送前，向用户展示变更摘要以获取最终确认：

- 展示本次完整目标 tag 和相应章节的 diff；本命令不修改 `pubspec.yaml`。发布端会再次解析 tag，若已有新版本占用该序号，应先更新目标说明。
- 询问用户确认：继续推送，还是中止。

只有用户明确确认后才继续：

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG prerelease 条目"  # 仅在 CHANGELOG 有变更时
git push origin preview
```

推送完成后，向用户确认预览版流水线已触发：CI 会自动创建 `vX.Y.Z-preview`（或递增序号）tag、构建并发布 GitHub Prerelease。全程**不要手动 `git tag` / `git push --tags`**。
