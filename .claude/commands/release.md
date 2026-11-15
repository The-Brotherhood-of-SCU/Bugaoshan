# Release Skill

为 Bugaoshan 项目准备正式版发布。**所有与用户的交互必须使用中文。**

> 发布状态由 `CHANGELOG.md` 与最新正式 tag 决定：把 `[Unreleased]` 并入
> `## [X.Y.Z]` 并 bump `pubspec.yaml` 后，推送 `preview` 会触发 `vX.Y.Z-rc`。
> 正式版只在 `preview → main` 的 PR 合并后发布，tag 由 CI 管理。

## Step 1: 获取目标版本

用户提供了版本参数（如 `/release 1.2.0`）就直接使用；否则询问目标版本（`X.Y.Z`）。没有有效版本不要继续。

## Step 2: 检查工作区与分支

- `git status --short`：有未提交变更时列出文件并询问是否继续。
- `git branch --show-current`：应为 `preview`；不是则询问是否切换：

  ```bash
  git fetch origin && git checkout preview && git pull origin preview
  ```

## Step 3: 更新 pubspec.yaml

把 `version:` 改为 `X.Y.Z`，同步 `+buildNumber`（`major*10000 + minor*100 + patch`，如 `2.6.0+20600`）。已经是目标版本则跳过。

## Step 4: 整理目标版本说明

读取 `.agents/skills/bugaoshan-changelog/SKILL.md`。

- 把 `## [Unreleased]` 中的条目归并去重，写入 `## [X.Y.Z] - YYYY-MM-DD`。
- 删除或清空 `[Unreleased]`；正式版发布时它必须为空。
- 合并同周期预览的净变化，补最后一个预览之后的增量；不要直接搬 git log。
- 正式版必须有有效内容；确无用户可感知变化时停止，不要发布空说明。
- CHANGELOG 的最高版本必须等于 `X.Y.Z`，且不能同时存在第二个未发布版本。

## Step 5: 更新 F-Droid 元数据

1. `python .github/scripts/metadata_changelog.py --skip-existing` 生成 `metadata/{en-US,zh-CN}/changelogs/`。
2. 编辑 `metadata/*.yml`，在 Builds 中追加 `versionName: 'X.Y.Z'` 与三个 ABI 的 versionCode（`X.Y.Z → base*10 + 1/2/4`）。

## Step 6: 发布前检查

```bash
python tool/pre_release_check.py X.Y.Z
```

严格模式，任何 FAIL 都必须处理。它会校验：版本递增、tag 冲突、pubspec 版本与 buildNumber、CHANGELOG 最高版本、正式版章节非空、`[Unreleased]` 为空、F-Droid 元数据与 changelog 文件。

## Step 7: 提交并推送 preview

先展示 `git diff -- pubspec.yaml CHANGELOG.md metadata/` 获取确认，然后：

```bash
git add pubspec.yaml CHANGELOG.md metadata/
git commit -m "chore: release vX.Y.Z"
git push origin preview
```

推送后 CI 会以 `## [X.Y.Z]` 为说明发布 RC；不要让 RC 单独维护章节。

## Step 8: 创建 preview → main 发布 PR

```bash
gh pr create --base main --head preview --title "release: vX.Y.Z"
```

- PR 门禁会按 `X.Y.Z` 运行正式版严格检查；合并后自动打 `vX.Y.Z` tag、构建并发布正式版。
- 若 `vX.Y.Z` 已存在，流水线幂等跳过。全程不要手动 `git tag` / `git push --tags`。
