# Prerelease Skill

为 Bugaoshan 项目准备预览版 / RC 的发布说明。**所有与用户的交互必须使用中文。**

> 状态由 CHANGELOG 决定：
> - 最高版本 == 最新正式 tag：常态预览，说明写入 `## [Unreleased]`。
> - 最高版本 > 最新正式 tag：准备期，说明写入 `## [X.Y.Z]`，发布为 `vX.Y.Z-rc[.N]`。
>
> 两种来源互斥；不要新增 `## [X.Y.Z-preview.N]` 或 `## [X.Y.Z-rcN]` 章节。

## Step 1: 检查工作区与分支

- `git status --short`：有未提交变更时列出并询问是否继续。
- `git branch --show-current`：应为 `preview`；不是则询问是否切换：

  ```bash
  git fetch origin && git checkout preview && git pull origin preview
  ```

## Step 2: 确认当前状态

```bash
python tool/pre_release_check.py
```

- 输出「常态预览」：编辑 `## [Unreleased]`。
- 输出「准备期」：编辑 `## [X.Y.Z]`，`X.Y.Z` 为 CHANGELOG 最高版本。
- 输出 FAIL：先按提示修复，不要发布。

## Step 3: 整理说明

读取 `.agents/skills/bugaoshan-changelog/SKILL.md`，按实际覆盖范围写用户可感知的变化。

- 常态：只维护 `[Unreleased]`；为空时允许继续，发布端会显示占位说明。
- 准备期：只维护 `## [X.Y.Z]`；为空时发布会失败。
- 不要把 `[Unreleased]` 与未发布版本章节同时留内容；准备正式版时并入目标章节并清空 `[Unreleased]`。
- 已有同版本说明则合并增量，不重复追加。

## Step 4: 提交并推送 preview

先展示 CHANGELOG diff 获取确认，然后：

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG prerelease 条目"  # 仅在 CHANGELOG 有变更时
git push origin preview
```

推送后 CI 会自动创建 `vX.Y.Z-preview.N` 或 `vX.Y.Z-rc[.N]` tag、构建并发布 Prerelease。全程不要手动打 tag，也不需要修改 `pubspec.yaml`。
