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

## Step 4: 整理目标版本说明

读取 `.agents/skills/bugaoshan-changelog/SKILL.md`，按用户确认的 `X.Y.Z`、上一正式版和本次目标代码整理 `CHANGELOG.md`。

- 同周期已确认的预览版说明先按功能合并去重，再补最后一个已覆盖预览之后的增量；核对 diff，描述正式用户最终获得的变化。
- 创建或更新 `## [X.Y.Z] - YYYY-MM-DD` 章节，日期按实际发布计划填写。已有同版本章节直接合并，其他历史版本保留。
- 正式版必须有对应版本的有效内容；筛选后确无可收录变化时说明情况，不发布空的正式版说明，也不借用上一版本。
- 提交到 `preview` 会先触发 RC。若需为这轮 RC 提供说明，按版本解析器的完整 RC tag 另行整理对应章节；发布端不会自动借用正式版章节。
- 这里只整理版本说明，后续版本元数据、检查和发布操作按以下步骤执行。

## Step 5: 更新 F-Droid 元数据

1. 运行 `python .github/scripts/metadata_changelog.py --skip-existing`，为 `X.Y.Z` 生成 `metadata/{en-US,zh-CN}/changelogs/` 下的版本说明文件（versionCode = `base*10 + 1/2/4`，如 2.6.0 -> 206001 / 206002 / 206004）。
2. 编辑 `metadata/*.yml`：参照既有版本条目的写法，在 Builds 中追加新版本，`versionName` 为 `X.Y.Z`，三个 ABI 的 `versionCode` 按上述公式填写。

## Step 6: 本地发布前检查

```bash
python tool/pre_release_check.py X.Y.Z
```

- 该命令为**严格模式**：版本号递增、tag 冲突、CHANGELOG `[X.Y.Z]` 章节、F-Droid 元数据等任何 FAIL 都必须处理后重跑，通过前不要继续。
- 若提示「已存在 tag vX.Y.Z」，说明该版本已发布过，停止并提示用户更换版本号。
- WARN 项（如 CHANGELOG 日期与发布计划不符）向用户展示并核实。

## Step 7: 提交并推送 preview

推送前，向用户展示变更摘要以获取最终确认：

- 展示 `git diff -- pubspec.yaml CHANGELOG.md metadata/`，让用户审查本次准备的版本、说明与元数据改动。
- 说明推送 `preview` 会自动触发预览版构建（tag 由流水线推导为 `vX.Y.Z-preview` 或下一序号）。
- 询问用户确认：继续推送，还是保留当前改动并中止发布。

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
