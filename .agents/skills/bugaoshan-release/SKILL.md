---
name: bugaoshan-release
description: 为 Bugaoshan 执行预览版 / RC / 正式版发布流程。涵盖 CHANGELOG 整理、pubspec 与 F-Droid 元数据更新、发布前检查与 PR 提交。changelog 文案规则见 bugaoshan-changelog。
---

# Bugaoshan Release

为 Bugaoshan 准备预览版 / RC / 正式版发布。**所有与用户的交互必须使用中文。**

发布状态由 `CHANGELOG.md` 与最新正式 tag 共同决定，tag 由 CI 在构建前自动创建，全程不要手动 `git tag` / `git push --tags`。

## 状态判定

取 `CHANGELOG.md` 中最高的 `## [X.Y.Z]` 正式版本章节，与最新正式 tag 比较：

| 条件 | 状态 | preview 合并 | main 合并 |
|---|---|---|---|
| 最高版本 == 最新正式 tag | 常态预览 | 发 `v<最新正式+1 patch>-preview[.N]`，说明取 `[Unreleased]` | 不发版 |
| 最高版本 > 最新正式 tag | 准备期（RC） | 发 `v<最高版本>-rc[.N]`，说明取 `## [最高版本]` | 发 `v<最高版本>` 正式版 |
| 最高版本 < 最新正式 tag | 非法 | 失败 | 失败 |

不变量（任一不满足直接失败）：

1. 有且只有一个高于最新正式 tag 的版本章节。
2. `[Unreleased]` 与高于最新正式 tag 的版本章节不能同时有内容。
3. `pubspec.yaml` 版本必须等于当前目标（分支流程断言）。
4. 正式版必须有非空的 `## [X.Y.Z]`；`[Unreleased]` 必须为空。
5. 同一版本只能有一个章节。

说明来源只有两个，不做回退：

- `-preview` tag → `[Unreleased]`；为空时发占位文案并 warning。
- `-rc` / 正式 tag → `## [X.Y.Z]`；为空时失败。

## 共用准备

### 1. 目标版本

- 正式版：用户提供版本参数（如 `X.Y.Z`）就直接使用；否则询问目标版本。没有有效版本不要继续。
- 预览版 / RC：无需指定版本，由 `CHANGELOG.md` 最高版本决定。

### 2. 工作区与分支

```bash
git status --short
git branch --show-current
```

- 有未提交变更时列出文件并询问是否继续。
- 当前分支应为 `preview`；不是则询问是否切换：

  ```bash
  git fetch origin && git checkout preview && git pull origin preview
  ```

---

## 正式版发布

目标：把 `[Unreleased]` 并入 `## [X.Y.Z]`，bump `pubspec.yaml` 与 F-Droid 元数据，推送 `preview` 触发 RC，再创建 `preview → main` PR。

### Step 1: 更新 pubspec.yaml

把 `version:` 改为 `X.Y.Z+BBBB`，其中 `BBBB = major*10000 + minor*100 + patch`（如 `2.6.0+20600`）。已经是目标版本则跳过。

### Step 2: 整理目标版本说明

按 [bugaoshan-changelog](../bugaoshan-changelog/SKILL.md) 的规则：

- 把 `## [Unreleased]` 中的条目归并去重，写入 `## [X.Y.Z] - YYYY-MM-DD`（日期未定则省略）。
- 清空 `[Unreleased]`；正式版发布时它必须为空。
- 合并同周期预览的净变化，补最后一个预览之后的增量；不要直接搬 git log。
- 正式版必须有有效内容；确无用户可感知变化时停止，不要发布空说明。
- CHANGELOG 的最高版本必须等于 `X.Y.Z`，且不能同时存在第二个未发布版本。

### Step 3: 更新 F-Droid 元数据

1. 生成多语言 changelog：

   ```bash
   python .github/scripts/metadata_changelog.py --skip-existing
   ```

2. 编辑 `metadata/*.yml`，在 Builds 中追加 `versionName: 'X.Y.Z'` 与三个 ABI 的 versionCode（`base*10 + 1/2/4`）。

### Step 4: 发布前严格检查

```bash
python tool/pre_release_check.py X.Y.Z
```

严格模式，任何 FAIL 都必须处理。校验：版本递增、tag 冲突、pubspec 版本与 buildNumber、CHANGELOG 最高版本、正式版章节非空、`[Unreleased]` 为空、F-Droid 元数据与 changelog 文件。

### Step 5: 提交并推送 preview

先展示 diff 获取确认：

```bash
git diff -- pubspec.yaml CHANGELOG.md metadata/
```

确认后：

```bash
git add pubspec.yaml CHANGELOG.md metadata/
git commit -m "chore: release vX.Y.Z"
git push origin preview
```

推送后 CI 会以 `## [X.Y.Z]` 为说明发布 RC；不要让 RC 单独维护章节。

### Step 6: 创建 preview → main 发布 PR

```bash
gh pr create --base main --head preview --title "release: vX.Y.Z"
```

- PR 门禁会按 `X.Y.Z` 运行正式版严格检查；合并后自动打 `vX.Y.Z` tag、构建并发布正式版。
- 若 `vX.Y.Z` 已存在，流水线幂等跳过。

---

## 预览版 / RC 发布

目标：整理 `[Unreleased]`（常态）或 `## [X.Y.Z]`（准备期）的说明，推送 `preview` 触发发布。不需要修改 `pubspec.yaml`。

### Step 1: 确认当前状态

```bash
python tool/pre_release_check.py
```

- 输出「常态预览」：编辑 `## [Unreleased]`。
- 输出「准备期」：编辑 `## [X.Y.Z]`，`X.Y.Z` 为 CHANGELOG 最高版本。
- 输出 FAIL：先按提示修复，不要发布。

### Step 2: 整理说明

按 [bugaoshan-changelog](../bugaoshan-changelog/SKILL.md) 的规则写用户可感知的变化。

- 常态：只维护 `[Unreleased]`；为空时允许继续，发布端会显示占位说明。
- 准备期：只维护 `## [X.Y.Z]`；为空时发布会失败。
- 不要把 `[Unreleased]` 与未发布版本章节同时留内容；准备正式版时并入目标章节并清空 `[Unreleased]`。
- 已有同版本说明则合并增量，不重复追加。

### Step 3: 提交并推送 preview

先展示 CHANGELOG diff 获取确认，然后（仅在有变更时）：

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG prerelease 条目"
git push origin preview
```

推送后 CI 会自动创建 `vX.Y.Z-preview.N` 或 `vX.Y.Z-rc[.N]` tag、构建并发布 Prerelease。
