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
| `preview` | 预览发布分支，兼日常集成分支，直接接收 feature/fix/docs PR | 每次合并**必然**触发一轮预览版发布（无跳过开关）；并发上只保留最新一轮（见 §4.14） |
| `main` | 正式版生产分支，仅接收来自 `preview` 的 PR | 从 `pubspec.yaml` 推导 `vX.Y.Z`；tag 已存在则幂等跳过 |

各工作流的触发矩阵：

| 事件 | pre-flight 门禁 | branch-policy | release.yml |
|---|---|---|---|
| 打开 / 更新 PR（→ main 或 preview） | ✅ | ✅（仅 PR 事件） | ❌ |
| push / 合并进 `main` | ✅ | ❌ | ✅ formal 通道 |
| push / 合并进 `preview` | ✅ | ❌ | ✅ preview 通道 |
| push tag `v*.*.*` | ❌ | ❌ | ✅ 仅当指向 main / preview 顶端；其他指向仅构建产物（见 §4.16） |
| 手动 `workflow_dispatch`（main/preview 上） | 可选 | ❌ | ✅ 正常发布（可选 channel 与 version_override） |
| 手动 `workflow_dispatch`（其他分支） | 可选 | ❌ | 仅构建产物：不推 tag、不发 Release（见 §4.15） |

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
   - 预览 tag 与 pubspec 解耦：脚本取「最新正式 tag」严格递增 Z 位（X、Y 不动），推导 `vX.Y.Z-preview`（首次）或递增序号 `vX.Y.Z-preview.N`（如上一正式版 v2.5.1 → v2.5.2-preview.2）；
   - workflow 自动打 tag（`resolve-metadata` job，需要 `contents: write`，推送失败立即终止本次发布）；
   - `build-android.yml`（universal + split-per-ABI，混淆，JDK 21）与 `build-windows.yml`（zip）并行构建；
   - 发布走 **Draft → 上传产物 → Publish** 顺序，兼容仓库的不可变 Release 策略，标记为 prerelease；
   - 预览版的 release notes 取 `CHANGELOG.md` 第一个章节（约定为 `[Unreleased]`；该取法的已知问题见 §4.8），对比范围为上一个**正式** tag。tag 在构建开始前就已推送，构建/发布失败时 tag 会留存（见 §4.12）。
4. **周期内迭代**：后续变更继续以 PR 合入 `preview`，预览版序号自动递增（`.2`、`.3`…）。周期内 `pubspec.yaml` 的版本号保持上一正式版不变，预览产物的 versionName 与 tag 不同名是设计使然。
5. **准备正式版（`/release X.Y.Z`）**：bump `pubspec.yaml` 版本（保留 `+buildNumber`）、将 `[Unreleased]` 重命名为 `[X.Y.Z] - 日期`、更新 F-Droid 元数据（`metadata/*.yml` 的 versionName/versionCode + `metadata_changelog.py` 生成多语言 changelogs）、本地跑严格模式 `pre_release_check.py X.Y.Z`，提交推送 `preview`——这会先触发一轮预览版发布（tag 按 §3 规则切换为 `vX.Y.Z-rc`，直接使用即将发布的版本号；若 RC 之后仍有合并进 preview，后续轮次为 `vX.Y.Z-rc1`、`-rc2`…；产物版本号与其余预览一致，构建时注入的是上一正式版的版本号，pubspec 的 bump 不影响预览构建；内容与正式版一致，性质等同发布候选）——随后创建 `preview → main` 的发布 PR，合并后才发正式版。
6. **合并进 `main`**：release.yml formal 通道——
   - 基础版本读自 pubspec；远端不存在 `vX.Y.Z` → 打 tag、双端构建、发布正式 Release（`--latest`）；
   - F-Droid changelog 由 `metadata_changelog.py --skip-existing` 生成并兜底提交回 `main`；
   - `vX.Y.Z` 已存在 → `should_release=false`，秒级跳过，不会重复发布。
7. **事后**：main 的 push 再触发一次 pre-flight（结构性检查照常硬拦截；时机类检查在两个版本之间的正常状态下为 WARN，不会长期挂红）。

## 3. 版本号模型

- **正式版的唯一事实来源是 `pubspec.yaml` 的 `version: X.Y.Z+BBBB`**，formal tag = `vX.Y.Z`，远端已存在同名 tag 时幂等跳过。`BBBB`（buildNumber）= `major*10000 + minor*100 + patch`（如 `2.5.1+20501`）；F-Droid 的 ABI versionCode = `base*10 + 1/2/4`（如 2.5.1 → 205011 / 205012 / 205014）。
- **预览通道与 pubspec 解耦，按阶段命名**：常态（pubspec == 最新正式版）下 tag 锚定「最新正式 tag」**严格只递增 Z 位**（X、Y 不动）加 `-preview[.N]`——上一正式版 v2.5.1 → v2.5.2-preview、v2.5.2-preview.2…；进入准备期（`/release` 已 bump，pubspec > 最新正式版）后 tag 直接使用即将发布的版本号：首个为 `v2.5.2-rc`，之后每次合并递增为 `v2.5.2-rc1`、`v2.5.2-rc2`…。仓库尚无任何正式 tag 的极端情况回退用 pubspec 版本推导。周期内 `pubspec.yaml` 保持上一正式版的版本号不变。**所有预览构建（含 RC）在构建时注入「最新正式 tag」的 versionName/versionCode**（`flutter build --build-name/--build-number`），整个周期的预览产物版本号完全一致（= 上一正式版），pubspec 的 bump 不影响预览构建的版本号；常态的 `-preview.N` tag 不预示正式版的最终版本号，RC 阶段的 tag 就是即将发布的版本。
- **预览触发时的自检与阶段判定**：比较 pubspec 版本与最新正式 tag——**一致**（常态）静默通过，按 `-preview.N` 命名；pubspec **落后**于最新正式版属于异常状态（下一次正式发布会被幂等守卫卡住），输出强 WARN 提示尽快 bump 对齐；pubspec **领先**即为 `/release` 准备期，输出 notice 并切换到 `-rc` 命名（首个 `vX.Y.Z-rc`，后续 `-rc1`、`-rc2`…）。semver 排序上两类预览 tag 恒大于上一正式版、小于未来正式版，永不倒挂。
- **与应用内更新渠道的兼容**：稳定渠道只读 GitHub `/releases/latest`（不含 prerelease），RC 不进入正式用户的更新视野；预览渠道取最近一个 prerelease tag 的基础版本号（`v2.5.2-preview.3` → `2.5.2`）与当前版本做语义比较（`isNewerPrerelease`），并对「当前构建就是该预发布版」自我排除。预览构建统一使用上一正式版的 versionName/versionCode，因此：正式版用户在周期内会被任何新预览正常提示升级；预览/RC 用户在正式版发布后也会被稳定渠道提示升级（versionCode 真实递增），预览→预览的同 versionCode 重装 Android 允许（仅禁止降级）。
- **发 2.5.2 还是 2.6.0 完全是人的决策**，发生在 `/release` 准备正式版、修改 pubspec 的那一刻；预览阶段不需要任何 bump，也不存在「周期开始 bump」的约定。
- 自动推导识别两类形态：常态 `-preview[.N]`、准备期 `-rc` / `-rcN`（同版本下扫描已有 rc tag 递增序号）；历史遗留的 `-pre1`、`-preview2` 等命名不参与推导。其他自定义后缀（如 `-beta`）通过 `workflow_dispatch` 的 `version_override` 手动触发。

## 4. 边界情况与已知风险

### 4.1 创建分支即触发发布
`on: push` 事件在**分支创建时同样触发**。从 `main` 创建 `preview` 分支的瞬间，release.yml 就会以当时的 pubspec（可能还是上一个正式版）发一轮预览版。启用流水线时的规避方式见 §5。

### 4.2 preview 通道没有跳过开关
每次合入 `preview` 都会真实构建并发版。不要把 preview 当作「只合代码、不发版」的集成分支使用；不希望发版的改动（如纯文档微调）也应接受一次预览版，或攒到下一轮一起合。

### 4.3 代码生成物漂移对解析来源敏感
`lib/injection/injector.config.dart` 由 build_runner（injectable_generator + dart_style）生成，输出取决于 **pub get 实际解析到的工具链状态**：`pubspec.lock` 锁定国内镜像 `pub.flutter-io.cn`，若 CI 未设置 `PUB_HOSTED_URL`，pub get 会按 pub.dev 重解析——除把 lock 的 hosted URL 全量翻成 pub.dev 外，还可能产出格式不同的生成物（曾在依赖版本完全相同的情况下复现为 injector.config.dart 多一行空行）。setup action 已统一设置 `PUB_HOSTED_URL`，生成随之确定；生成物以锁定工具链的产物为准，出现纯格式 diff 时不要提交回去（干净树检查会在 CI 兜底拦截）。

### 4.4 门禁红不等于挡合并
`main` 的 ruleset（`protect-main`）要求 1 个 approve、评论必须解决、禁止删除与强推，但**未配置 required status checks**。pre-flight 挂红只是展示性的，不阻塞合并；流程的真正闸门是人工 review。若要让门禁硬生效，需在仓库设置中将 pre-flight 的 check 配为 required。

### 4.5 预览 tag 竞态
preview 通道开启「只保留最新一轮」的取消语义后，短时间连续 push 的竞态窗口大幅收窄：仅当旧 run 恰好在被取消前已推 tag，新 run 会自动递增序号绕开。tag 推送失败仍会立即终止当前 run（宁可早失败，不在 20 分钟构建后死在 publish 阶段）。formal 通道不取消，靠幂等守卫防重复。

### 4.6 version_override 无预检
`workflow_dispatch` 传入 `version_override` 时不做「tag 是否已存在」检查，遇到已存在的 tag 会在构建完成后才于 publish 阶段失败。手动触发前先确认目标 tag 未被占用。

### 4.7 不会递归触发
CI 自己的 `git push`（自动 tag、F-Droid metadata 兜底提交）使用 `GITHUB_TOKEN`，GitHub 不会为 GITHUB_TOKEN 产生的事件新建 workflow run，因此发布流程不会自我连环触发。

### 4.8 CHANGELOG 的提取路径
`release_changelog.py`：版本号含 `-`（预览/RC）→ 按**名称**匹配 `CHANGELOG.md` 的 `[Unreleased]` 章节；正式版 → 严格匹配 `[X.Y.Z]` 章节，缺失或为空直接报错终止。

预览/RC 路径的行为：

- `[Unreleased]` 有内容 → 作为发布说明；
- `[Unreleased]` 存在但为空、或整个缺失 → 发布占位文案 `*No changelog entry for this version.*` 并打 `::warning::` 注解，**绝不借用其他版本的章节**（早期实现按位置取第一个章节，章节缺失时会静默把上一个正式版的更新说明发进新预览版，已修复并有回归测试锁定）；
- 预览阶段**不要**重命名 `[Unreleased]` 章节——重命名是 `/release` 的职责。

相关守卫：正式版忘记把 `[Unreleased]` 重命名清空时，下周期预览会把已发布内容重复宣传——`pre_release_check` 稳定模式已有 WARN（「[Unreleased] 仍有 N 条未发布内容」）兜底；正式版 `[X.Y.Z]` 章节缺失/为空除 publish 阶段硬失败（构建跑完才报错）外，pre-flight 稳定模式会在发布 PR 阶段就 FAIL 提前拦截——但门禁不是 required check，需要人工看红叉。

### 4.9 F-Droid 元数据需要先行
`metadata/*.yml` 的 versionName/versionCode 不会由流水线自动生成，必须在 `preview → main` 发布 PR 之前手动补齐（`/release` 命令包含此步骤），否则 pre-flight 的结构性检查会 FAIL；`metadata/{lang}/changelogs/*.txt` 由 CI 在正式发布时兜底生成并提交回 `main`。

### 4.10 手动严格模式与 CI 门禁模式的分界
`tool/pre_release_check.py` 手动运行（`/release` 流程）为严格模式：版本递增、tag 冲突、Unreleased 空置等一律 FAIL，用于发布前拦截。`--ci` 模式运行在任意 PR/push 上，代码库常处于「两个版本之间」的正常状态，上述时机类检查降级为 WARN，结构性检查（版本格式、pubspec 解析、CHANGELOG 结构、F-Droid 元数据）保持 FAIL。

### 4.11 fork PR 的推送方式
外部贡献者的 PR 分支位于其 fork。维护者推送修正提交依赖 PR 的 `maintainer_can_modify`；仓库启用 git-lfs 时，直接推送需跳过 LFS pre-push 钩子（`git push --no-verify`，仅当变更不含 LFS 文件时安全）。

### 4.12 tag 先于产物：孤儿 tag
tag 在 `resolve-metadata` 阶段推送，构建在其后。构建/发布失败时 tag 已经存在：

- preview 通道：留下无 release 的孤儿 tag。重跑**失败的 job** 可复用原 tag 重试发布；重跑整个 run 或重新合并则会因 tag 已存在而推导出**下一个序号**；
- formal 通道：孤儿 tag 会触发幂等守卫，同一版本的重发被跳过——必须手动 `git push origin --delete vX.Y.Z` 删除孤儿 tag 后才能重发。

### 4.13 Draft 半成品残留
正式发布采用 Draft → 上传 → Publish 顺序；上传中途失败会留下带部分产物的 draft release。无论以哪种方式重试，都需先手动删除残留草稿，否则 `gh release create` 会因同名 tag 的 release 已存在而失败。

### 4.14 预览轨道只保留最新一轮
preview 通道的并发组开启取消（cancel-in-progress）：短时间连续合并会停掉进行中的旧发布，只构建发布最后一轮——设计上预览轨道只保留最新一轮。被取消的 run 与失败的 run 一样可能留下孤儿 tag（见 §4.12），随预览清理一并处理；历史预览版 release 与 tag 属于可清理对象，定期删除即可。formal 通道绝不取消，正式发布必须完整走完。

### 4.15 手动 dispatch 的行为边界
`workflow_dispatch` 的发布行为由触发所在的 ref 决定：

- 在 `main` 上触发：auto → formal 通道，tag 从 pubspec 推导；tag 已存在（如刚发完版）则整个 run 秒级跳过，不会误发。显式选择 preview 通道会用 main 的代码发一轮预览（少见但允许）；
- 在 `preview` 上触发：auto → preview 通道，等同「把当前 preview 状态重新发一轮」——常态期发 `vX.Y.Z-preview.N`（自动递增），准备期发 `vX.Y.Z-rc[.N]`。适合在构建失败或清理残留草稿后重发；注意它会取消同一通道上正在进行的 run；
- 在其他分支上触发 → **仅构建产物**（build-only）：照常解析版本号并命名产物，可供下载验证，但不推 tag、不创建 Release——特性分支上演练发布构建不会误发版；
- 仍在的陷阱：在 preview 上 dispatch 且 `version_override` 不含 `-` 时，通道仍为 preview（is_prerelease=true），会把形如 `v2.5.1` 的正式命名以 prerelease 发布，占用正式 tag 命名空间，后续真正的 formal 会被幂等守卫挡住。

### 4.16 手动推 tag 的指向约束
`v*.*.*` tag push 仍不跑 pre-flight、不校验 pubspec（tag 号与 APK 内 versionName 可能错位），但**发布资格由 tag 指向的 commit 决定**——与在哪个分支上执行 `git tag` 无关：

- 指向 **main 顶端** → 按名称发布：无 `-` 为 formal，含 `-` 为 prerelease；
- 指向 **preview 顶端** → 一律按 prerelease 发布（可用于手动补发 `v2.5.2-rc1` 这类 RC）；若名称无 `-`（形如 `v2.5.2` 的正式命名），**只构建不发版**并告警——正式 tag 只允许指向 main；
- 指向其他任何 commit（feature 分支、历史提交等）→ 仅构建产物并告警，不发布；若为误推请手动删除该 tag。

对比旧行为的收益：指向 preview / feature 分支的正式 tag 不再能用未进 main 的代码发布正式版、不再预先占用版本命名（此前会让真正的 formal 被幂等守卫挡死）。仍存在的不便：tag 路径没有幂等守卫，同名 release 已存在时会在完整构建后才于 `gh release create` 处失败。

### 4.17 bump 版本号须同步 `+buildNumber`
`buildNumber = major*10000 + minor*100 + patch`，与 F-Droid 元数据的 versionCode（`base*10 + 1/2/4`）同源。只改 `X.Y.Z` 忘改 `+BBBB` 会导致 APK versionCode 与元数据错位。`/release` 命令已内置该规则提醒。

### 4.18 setup 阶段的代码生成失败被吞
setup action 里 `build_runner` 带 `|| true`，生成器配置坏了不会让 setup 显式失败，只能靠漂移检查与测试兜底。

### 4.19 发布正文的外链硬编码 fork 地址
`release_body.py` 中 macOS dmg / iOS ipa 的下载链接指向 `Visio-Vanitas/Bugaoshan`（#285 的 ipa mirror 决策），且这些产物不由流水线上传。仓库迁移、改名或镜像调整时需同步修改该脚本。

### 4.20 Python 单测重复发现
pre-flight 的 `unittest discover -s .github/scripts/` 会把 `tests/` 子目录的用例再发现并执行一遍，用例双跑属无害冗余，分析 CI 时长时勿据此误判。

## 5. 启用时序（一次性）

流水线随引入它的 PR 合入 `main` 而生效，启用时需要注意：

1. 引入 PR 本身合入 `main` 时，formal 通道因「tag 已存在」而跳过（若 pubspec 未 bump），不会误发版。
2. 从 main 直接创建 `preview` 分支即可：分支创建触发的那轮预览发布按 §3 规则自动命名为「上一正式版 +1」-preview（如 v2.5.2-preview），命名正确；该轮内容与刚发布的正式版相同，属预期，无需处理。
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
