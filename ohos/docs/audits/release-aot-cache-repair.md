# Release 启动 SIGSEGV：Flutter OH 平台缓存修复步骤

2026-09-22 状态更新：工具链已升级到 3.44.9 开发快照，插件和嵌入层补丁均已移除。
下文保留 3.41 的排查证据；当前版本及平台缓存哈希以 `ohos/flutter/toolchain.lock.json` 为准。

审计日期：2026-09-17。适用对象：本工程锁定的 Flutter OH `3.41.10-ohos-1.0.1`、
Dart `3.11.5`、ARM64 Release 启动崩溃。

**首选修复是刷新同版本 Flutter OH SDK 的平台缓存，校验内容后重新生成整个 Release HAP。**
现有证据表明，本机 `platform_strong.dill` 中的 ABI 排序与当前编译器不一致；已经核验过的
官方同版本文件具有正确排序。暂不需要以升级 Flutter、调整堆大小或继续绕过 native 调用作为修复起点。

仓库内已撤销 framework 诊断补丁接入，并增加工具链产物提交及平台文件哈希校验。
SDK 缓存刷新、重新准备、构建与真机验收按下列步骤进行；
修复是否成功仍以新 Release 包的真机结果为准。

2026-09-17 执行记录：经用户授权，本机已完成 `precache --ohos --universal --force`，
两份平台文件 SHA-256 与本文记录一致，OH engine/HAR/Dart 提交也通过只读校验。
旧平台目录、ARM64 SO、Release symbols、HAP 与原始故障日志保存在本地
`.flutter-workspace/tooling/cache-repair-backups/<时间>/`，同目录包含下载日志和前后校验记录。
这个位置位于 `build/` 之外，常规 Flutter clean 不会清除这份备份。
本轮没有执行依赖解析、应用缓存清理、构建、测试或真机操作；本机后续从第 5 步开始，
其他环境仍应从第 2 步核对工具链及缓存。

## 1. 为什么这样修

14:48 的完整故障报告与同次 ARM64 AOT 产物匹配：

| 项目 | 已确认内容 |
| --- | --- |
| 故障时间 | 2026-09-17 14:48:22.710，进程启动约 3 秒 |
| 信号与目标地址 | `SIGSEGV(SEGV_MAPERR)@0xffffffffb4e65370` |
| `libapp.so` Build ID | `e0344fe1f58f7591de22cf26f4588bb1` |
| `libflutter.so` Build ID | `ed9d58668a677d85eee6fa8153bda7d531ab61a5` |
| 对应有效入口 | 当次引擎基址 `0x5bb4200000` + `0xc65370` = `0x5bb4e65370` |
| 截断位置 | `Native._ffi_resolver.#ffiClosure0` 返回值处理中的 `sxtw x1, w0` |
| 最终故障指令 | `libapp.so+0x3125c8` 的 `blr x9`，x9 已经是错误地址 |

同次符号还原出的调用链为：

```text
main → _initializeApp → WidgetsFlutterBinding.ensureInitialized
  → RestorationManager.initChannels
  → MethodChannel.setMethodCallHandler
  → ChannelBuffers.setListener → _Channel._drain
  → scheduleMicrotask → _scheduleMicrotask
  → CallNativeThroughSafepoint → 非法地址
```

底层 resolver 的声明使用 `IntPtr`，ARM64 应按 64 位处理。实际 AOT 代码却保留地址低
32 位，再符号扩展为 64 位，因而把 `0x5bb4e65370` 变成 `0xffffffffb4e65370`。
该值随后被缓存，并作为函数指针执行。

这与平台缓存的 ABI 错位吻合：

| 来源 | `ohosArm64` 的序号 | 序号 23 的含义 |
| --- | --- | --- |
| 本机两个旧 `platform_strong.dill` 的内嵌源码 | 6 | `windowsIA32`，`IntPtr` 为 32 位 |
| 当前 SDK / OH Dart 编译器源码 | 23 | `ohosArm64`，`IntPtr` 为 64 位 |
| 已核验的官方同版本两个平台文件 | 23 | `ohosArm64`，与当前编译器一致 |

上述排序来自 `.dill` 的内嵌源码检查，并非完整反序列化 kernel 元数据；
实际反汇编中的 32 位截断是独立证据。两项证据共同支持缓存不配套这一诊断，
最终仍要用修正缓存后的机器码或真机运行验证。

本机 SDK 还存在缓存有效性判断的隐患：`FlutterSdk` 的缓存版本使用上游
`engineRevision`，而平台 ZIP 的下载地址使用 `engine.ohos` revision。
OH 产物版本变化但上游版本不变时，旧缓存可能仍被判断为有效。
这解释了为何只看 `flutter --version` 不够，但不能据此还原本机过去具体哪次操作引入了旧缓存。

**内存读数不是本次故障的修复依据。** 最新日志的 RSS 为 `251686 kB`，约 246 MiB，
它包含进程驻留的 Dart/原生内存、代码映射等，不等于 Dart 堆大小。
此次明确观察到的是错误函数指针跳转，日志没有提供把它判为堆过大或 OOM 的依据。

## 2. 停止构建，设置本次操作路径

先停止 DevEco 的构建、运行及自动 Sync，再完全退出 DevEco，避免刷新缓存时有编译任务读取 SDK。
如果已有 Hvigor daemon，在原生工程目录执行 `hvigorw --stop-daemon`。
以下代码块由你在**同一个 PowerShell 窗口**依次执行，从仓库根目录开始。
`Read-Host` 要求输入目录本身，不要额外输入包裹路径的引号。

```powershell
$repairRepoRoot = (Get-Location).Path
if (-not (Test-Path -LiteralPath (Join-Path $repairRepoRoot 'ohos/tool/build_ohos.py'))) {
  throw '请先进入 Bugaoshan 仓库根目录。'
}
$repairFlutterSdk = (Resolve-Path -LiteralPath (Read-Host 'Flutter OH SDK 根目录')).Path
$repairHarmonySdk = (Resolve-Path -LiteralPath (Read-Host 'DevEco SDK 根目录，包含 default/openharmony')).Path
$repairFlutterCommand = Join-Path $repairFlutterSdk 'bin/flutter.bat'
$repairNativeRoot = Join-Path $repairRepoRoot 'ohos'
$repairWorkspace = Join-Path $repairNativeRoot '.flutter-workspace'
$repairToolchain = Get-Content -LiteralPath (Join-Path $repairNativeRoot 'flutter/toolchain.lock.json') -Raw -ErrorAction Stop | ConvertFrom-Json
$repairDevEcoRoot = Split-Path -Parent $repairHarmonySdk
if (-not (Test-Path -LiteralPath $repairFlutterCommand)) {
  throw '所选目录中没有 bin/flutter.bat。'
}
if (-not (Test-Path -LiteralPath (Join-Path $repairHarmonySdk 'default/openharmony'))) {
  throw 'HarmonyOS SDK 目录层级错误。'
}

# 只调整当前终端的 PATH，确保准备脚本使用同一套工具。
$env:PATH = (@(
  (Join-Path $repairFlutterSdk 'bin')
  (Join-Path $repairDevEcoRoot 'tools/node')
  (Join-Path $repairDevEcoRoot 'tools/hvigor/bin')
  (Join-Path $repairDevEcoRoot 'tools/ohpm/bin')
  $env:PATH
) -join [IO.Path]::PathSeparator)
Get-Command python, git, flutter, node, hvigorw, ohpm -ErrorAction Stop |
  Select-Object Name, Source

Push-Location -LiteralPath $repairNativeRoot
try {
  hvigorw --stop-daemon
  if ($LASTEXITCODE -ne 0) { throw '停止 Hvigor daemon 失败，请先处理后再继续。' }
} finally {
  Pop-Location
}
```

Flutter OH SDK 根目录应包含 `bin/`、`packages/`；DevEco SDK 根目录应包含
`default/openharmony/`，不要选成其下的 `native/`。
本工程后续准备步骤还会严格检查正式标签、源码提交、DevEco、Node、OHPM 和 Hvigor 版本。

## 3. 清理前保存故障包和符号

后续 `flutter clean` 会删除工作区 `build/` 内的 AOT symbols。
先保留故障时对应的 symbols、SO、HAP 和原始日志，避免后续无法复查。

```powershell
$repairArchive = Join-Path ([IO.Path]::GetTempPath()) (
  'bugaoshan-aot-before-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
)
New-Item -ItemType Directory -Path $repairArchive -ErrorAction Stop | Out-Null
$repairEvidence = [ordered]@{
  'release-symbols' = (Join-Path $repairWorkspace 'build/symbols/release')
  'arm64-libs' = (Join-Path $repairNativeRoot 'entry/libs/arm64-v8a')
  'hap-outputs' = (Join-Path $repairNativeRoot 'entry/build/default/outputs/default')
}
foreach ($repairItem in $repairEvidence.GetEnumerator()) {
  if (Test-Path -LiteralPath $repairItem.Value) {
    Copy-Item -LiteralPath $repairItem.Value -Destination (
      Join-Path $repairArchive $repairItem.Key
    ) -Recurse -ErrorAction Stop
  } else {
    Write-Warning ('未找到旧产物，请确认是否已被其他构建覆盖：' + $repairItem.Value)
  }
}
Write-Host ('旧产物备份目录：' + $repairArchive)
```

把本次完整 NativeCrash/FaultLog 原文也保存到该目录，并把整份备份转存到长期保存位置。
备份反映的是当前磁盘文件；若它们已经被后续 Debug 或 Release 构建覆盖，不能再当作旧故障的配套产物。
不需要复制工程签名配置、证书或密码。

## 4. 强制刷新同版本 SDK 缓存，并校验结果

### 4.1 先确认版本基线

本方案中的哈希只适用于下列版本组合。SDK 已升级或切换提交时，应按新版本重新核验产物，
不要把旧版平台文件覆盖进新版 SDK。

| 项目 | 本次基线 |
| --- | --- |
| Flutter OH | `3.41.10-ohos-1.0.1` |
| framework revision | `adaf911c35c9136a7d18fc424d714c9ec7724e60` |
| 上游 engine revision | `42d3d75a56efe1a2e9902f52dc8006099c45d937` |
| OH artifact / HAR revision | `3fb08d34b6f96a15fbb219b903c9d0ab37b6c2e0` |
| Dart | `3.11.5` |
| OH Dart 源码 revision | `ee3baaa7621306ad8eaa2c4961abec5cbf8672a6` |

```powershell
$repairFrameworkRevision = git -C $repairFlutterSdk rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $repairFrameworkRevision.Trim() -ne $repairToolchain.flutter.frameworkRevision) {
  throw 'Flutter OH 源码提交与本次修复基线不一致。'
}
$repairRevisionFiles = [ordered]@{
  'engine.ohos.version' = $repairToolchain.flutter.ohosArtifacts.engineRevision
  'engine.ohos.har.version' = $repairToolchain.flutter.ohosArtifacts.harRevision
}
foreach ($repairVersionFile in $repairRevisionFiles.Keys) {
  $repairRevision = (Get-Content -LiteralPath (
    Join-Path $repairFlutterSdk ('bin/internal/' + $repairVersionFile)
  ) -Raw -ErrorAction Stop).Trim()
  if ($repairRevision -ne $repairRevisionFiles[$repairVersionFile]) {
    throw ('OH 产物版本不匹配：' + $repairVersionFile + ' = ' + $repairRevision)
  }
}
```

### 4.2 执行强制刷新

```powershell
# 当前 PowerShell 会话使用 SDK 默认的官方 OH 产物源。
$env:FLUTTER_OHOS_STORAGE_BASE_URL = 'https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com'
Push-Location -LiteralPath ([IO.Path]::GetTempPath())
try {
  & $repairFlutterCommand precache --ohos --universal --force
  if ($LASTEXITCODE -ne 0) { throw 'SDK 缓存刷新失败，请勿继续构建。' }
} finally {
  Pop-Location
}
```

本 SDK 支持这三个参数：`--force` 使缓存重新更新，`--universal` 包含平台 SDK，
`--ohos` 包含 OH 目标工具与引擎产物。需保持网络可用并等待成功退出。
仅执行 `pub get` 或清理应用 `build/`，都不会修正 SDK 中的旧平台文件。

### 4.3 校验两个平台文件

```powershell
$repairExpectedPlatforms = $repairToolchain.flutter.ohosArtifacts.platformSha256
$repairHashResults = foreach ($repairPlatform in $repairExpectedPlatforms.PSObject.Properties) {
  $repairDill = Join-Path $repairFlutterSdk (
    'bin/cache/artifacts/engine/common/' + $repairPlatform.Name + '/platform_strong.dill'
  )
  $repairHash = (Get-FileHash -LiteralPath $repairDill -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
  if ($repairHash -ne $repairPlatform.Value) {
    throw ('平台缓存哈希不匹配：' + $repairDill + '；实际：' + $repairHash)
  }
  [pscustomobject]@{ Platform = $repairPlatform.Name; SHA256 = $repairHash }
}
$repairHashResults | Format-List
$repairHashResults | ConvertTo-Json | Set-Content -LiteralPath (
  Join-Path $repairArchive 'platform-hashes-after-refresh.json'
) -Encoding UTF8 -ErrorAction Stop
```

两项均通过后再继续。它们对应已核验官方 ZIP 中的文件：

- [Release 平台 SDK ZIP](https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com/flutter_infra_release/flutter/3fb08d34b6f96a15fbb219b903c9d0ab37b6c2e0/flutter_patched_sdk_product.zip)
- [非 product 平台 SDK ZIP](https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com/flutter_infra_release/flutter/3fb08d34b6f96a15fbb219b903c9d0ab37b6c2e0/flutter_patched_sdk.zip)

本次审计时，Release ZIP 为 3,949,636 字节，其 SHA-256 为
`c0db9958a85ab0f0435997a9318c6f3cff094bed3b23fbb66b397eeb8154e28c`。
ZIP 哈希和解压后的 `.dill` 哈希是两种不同检查，不应混用。

故障环境原来的两个 `.dill` 哈希如下，可用于识别“实际仍未刷新”：

```text
product：1f929a894df4a7a27df0e2a3fc19bcf5c89e2042fe44739c55e28a793c55834e
普通：   b2b4077be7d95c7a1ce32055ebce5b5a34ceb2de6a780e387d952668a26b1db6
```

### 4.4 刷新后哈希仍不匹配时

先停止后续构建，按顺序检查：

1. 当前实际使用的是否是 `$repairFlutterSdk`；终端、DevEco 和准备脚本不能各自使用不同 SDK。
2. 下载地址是否包含上述 OH artifact revision；是否仍由代理或镜像提供旧文件。
3. 直接下载上面的官方 ZIP 到 SDK 之外的临时目录，先解压并校验 `.dill`。
   如果官方内容也与记录不同，保留响应信息和哈希重新核验，不强行放行。
4. 若官方 ZIP 内容正确而 `precache` 始终未更新本机文件，可关闭所有使用该 SDK 的进程，
   备份 `common/` 下这两个旧平台目录，再用已校验 ZIP 中的**完整对应目录**替换。
   以压缩包实际目录结构为准，最终应直接得到上述 `…/<平台目录>/platform_strong.dill`，
   不得多嵌套一层目录，也不要只覆盖一个 `.dill` 留下其他旧文件。
5. 再执行 4.3 的检查。手动替换只是平台目录刷新失败时的补救；如果此前 `precache` 报错，
   还必须解决其他目标工具或引擎产物下载失败，不能凭两个哈希通过就把半套 SDK 用于构建。

另一种处理是另建一份同标签、同提交的干净 Flutter OH SDK，保留原 SDK 备查，
在新目录执行完整 `precache` 和哈希检查，然后把 `$repairFlutterSdk` 与
`$repairFlutterCommand` 改为新路径。不要从旧 SDK 拷回 `bin/cache/`。

## 5. 清理应用缓存，重新准备鸿蒙工程

先确认第 3 步已经备份。只在鸿蒙独立 Flutter 工作目录运行 clean：

```powershell
Push-Location -LiteralPath $repairWorkspace
try {
  & $repairFlutterCommand clean
  if ($LASTEXITCODE -ne 0) { throw 'Flutter 工作区清理失败。' }
} finally {
  Pop-Location
}

Push-Location -LiteralPath $repairRepoRoot
try {
  python ohos/tool/build_ohos.py --prepare-only --flutter-sdk $repairFlutterSdk --ohos-sdk $repairHarmonySdk
  if ($LASTEXITCODE -ne 0) { throw '鸿蒙工程准备失败，请先处理报错。' }
} finally {
  Pop-Location
}
```

`--prepare-only` 会解析依赖、生成代码、应用补丁和更新本地工具路径，但不编译 HAP。
本次修复不用 `--update-lockfile`，依赖版本保持已有锁定关系。
准备后重新执行 4.3 的哈希检查，确认工具准备期间没有重新写回旧缓存。

不要递归删除整个 `.flutter-workspace/`：里面有链接到维护源码和资源的文件。
也不要执行仓库级 `git clean -xfd`。根工程的 `ohos/build-profile.json5` 含本机签名配置，
本方案不需要打开、删除或重置它。

## 6. 清理原生工程并完整重建 Release

接下来的两种入口选一种即可。不要让 DevEco 和终端同时构建同一工程。

### 方案 A：使用 DevEco

1. 重开 DevEco，打开仓库原有的 `ohos/`。
2. 执行 Sync，确认使用刚才准备的 Flutter OH SDK。
3. 对整个原生工程执行 Clean Project，然后选择 **Release** 构建完整 HAP。
4. 使用现有设备与签名配置部署该 Release 包；确认运行操作没有又构建并安装 Debug 包。

### 方案 B：使用命令行

```powershell
Push-Location -LiteralPath $repairNativeRoot
try {
  hvigorw clean --no-daemon
  if ($LASTEXITCODE -ne 0) { throw '原生工程清理失败。' }
} finally {
  Pop-Location
}

Push-Location -LiteralPath $repairRepoRoot
try {
  python ohos/tool/build_ohos.py --mode release --flutter-sdk $repairFlutterSdk --ohos-sdk $repairHarmonySdk
  if ($LASTEXITCODE -ne 0) { throw 'Release 构建失败。' }
} finally {
  Pop-Location
}
```

脚本会再次准备工作区，并执行 Hvigor Sync 与 `assembleHap`。
只运行 `flutter_inappwebview_ohos` 模块的 `compileNative` 不能替代该过程，
它不能证明 Dart AOT 和最终 HAP 已重新生成。本工程也不要改用 `flutter build hap`：
Flutter 工作目录内没有第二个 `ohos/` 子工程。

如果仍遇到历史 `00303038 / Schema validate failed`，这是构建配置校验阶段的问题，
还没有进入真机的 native resolver 调用。先从 DevEco 详细日志提取 `instancePath`、
规则及被拒绝的配置项，再按 [构建排查说明](../../tool/README.md#常见问题)处理。
修改配置后停止 daemon 再重试，不能把这条构建错误当作缓存修复无效的证据。

清理原生缓存仍无效时，可在停止所有构建后，先用文件管理器核实完整路径，再把
`ohos/entry/build/`、`ohos/build/` 和 `ohos/.hvigor/` 三个生成目录移到工程外备份，
重新 Sync/Build。不要移动 `ohos/` 本身、维护源码、依赖锁或本机签名配置。

## 7. 确认新包与符号属于同一次构建

主要产物：

| 相对仓库根目录的路径 | 用途 |
| --- | --- |
| `ohos/entry/libs/arm64-v8a/libapp.so` | ARM64 Dart AOT 机器码 |
| `ohos/.flutter-workspace/build/symbols/release/app.ohos-arm64.symbols` | 同次 Dart AOT 调试信息 |
| `ohos/entry/build/default/outputs/default/entry-default-unsigned.hap` | 构建脚本报告的未签名 HAP |

检查新 `libapp.so` 和 symbols 的更新时间。默认符号路径如上，构建日志若显式设置其他
`SplitDebugInfo` 目录，则保存实际目录。查询 Build ID 的示例：

```powershell
$repairLlvmBin = Join-Path $repairHarmonySdk 'default/openharmony/native/llvm/bin'
& (Join-Path $repairLlvmBin 'llvm-readelf.exe') -n (
  Join-Path $repairNativeRoot 'entry/libs/arm64-v8a/libapp.so'
)
if ($LASTEXITCODE -ne 0) { throw '读取新 libapp.so 的 ELF notes 失败。' }
```

修正了代码生成输入后，若 `libapp.so` 的 Build ID、SHA-256 都与故障包完全相同，
优先检查是否复用了旧 AOT 输出。引擎本身仍是同一版本，`libflutter.so` 的 Build ID
保持不变可以是正常现象，不要求它必须变化。

还需用压缩包查看器打开**最终部署的 HAP**，核对其中实际打包的 ARM64 `libapp.so`
是否与刚生成文件一致。部署使用 DevEco 现有配置生成的已签名 Release HAP；
上表的 unsigned HAP 用于检查产物，不能直接作为真机安装步骤。

把这次新 HAP、新 SO、新 symbols、构建日志和第 4 步哈希结果另存一份，
不要覆盖第 3 步保留的旧故障证据。符号文件包含调试信息，反汇编应使用真正的 `libapp.so`，
不能把 `.symbols` 当作包含全部机器码的库。

## 8. 真机验收与诊断补丁退出

### 8.1 先验收缓存修复

在发生故障的 MatePad Mini 上覆盖安装新的 Release 包，保留原数据即可开始验证。
建议至少进行 5 次彻底结束进程后的冷启动，而不是只做前后台切换：

- 每次均能越过 `WidgetsFlutterBinding.ensureInitialized` 并正常进入 EULA、向导或首页。
- 能读取设置和数据库，进入课表及 WebView，执行一次分享或打开链接等平台通道操作。
- 前后台切换和系统深浅主题切换正常；没有重新出现相同的高位全 `f` 的函数指针跳转。
- 复查旧 Want 模块加载错误、`Observed is not defined` 与重复运行 DartExecutor 的日志。
  这些属于此前独立缺陷的回归项，即使仍出现，也需要按各自日志定位。

5 次冷启动是本次故障的初步回归门槛，不代表全部功能或设备组合均已验证。

### 8.2 恢复被绕过的 RootIsolateToken 路径

[RootIsolateToken 诊断补丁](../../flutter/patches/framework/README.md)
只绕过第一个崩溃点，不修复 ABI。目前 [build_ohos.py](../../tool/build_ohos.py) 已移除
`stage_flutter_framework` 的导入和调用，保留 Flutter package 必须来自锁定 SDK 的校验。
不需要再手工删除调用或 patch 文件；补丁、清单及历史辅助脚本已经移除，可从 Git 历史复查。

每次准备时依赖解析会重新生成 package_config，直接使用 SDK 的 `packages/flutter`。
工具链锁的变更使旧运行配置失效，DevEco 下次 Sync 会重新准备。
[增量入口](../../tool/ohos_native.py)也会核对 Flutter package 路径，拒绝仍指向旧诊断副本的工作区。

验收时仍须确认：

1. 使用第 5、6 步重新准备及构建；不要手改生成的 package_config 或补丁副本。
2. `.flutter-workspace/.dart_tool/package_config.json` 的 `flutter.rootUri` 指向所选 SDK，
   `platform_channel.dart` 使用原始 `ServicesBinding.rootIsolateToken` 判断。
3. 按第 7、8.1 步归档新产物，安装新的 Release 包，验证原始调用路径能冷启动。

旧副本可保留为未被引用的生成物，不能把它仍存在视为补丁仍在使用。
其他插件和 embedding 补丁有各自原因，不随这一个诊断补丁一起撤销。

## 9. 仍然失败时如何继续定位

| 结果 | 下一步 |
| --- | --- |
| 两个平台文件哈希不匹配 | 回到 4.4，修正 SDK 路径或下载内容，先不要继续构建 |
| 哈希通过但新 `libapp.so` 与旧故障包完全相同 | 核对真实构建 SDK，清理 Flutter/原生缓存并重新完整构建 |
| 哈希通过，新包仍出现同类地址截断 | 保存新机器码与完整日志，继续核对 `gen_snapshot`、Dart SDK 和 HAR 的实际版本及 resolver 生成代码 |
| SIGSEGV 已消失，出现 Dart/ArkTS 异常 | 按新的异常栈定位，检查之前被启动崩溃遮住的问题 |
| 只有移除诊断补丁后再次崩溃 | 检查原始 RootIsolateToken 路径与新机器码，不能靠重新绕过后宣称根因已修复 |

重新收集故障时，最少保留以下材料：

1. 完整原始 FaultLog：信号、`#00`、全部故障线程栈、寄存器和进程内存映射。
2. 实际安装 HAP 中的 `libapp.so` / `libflutter.so`、各自 Build ID 和同次 AOT symbols。
3. 本次 SDK 源码提交、OH artifact / HAR revision、两个平台文件 SHA-256，以及构建日志。

DevEco 的 `00403003 / So Error in Line X` 是地址解析失败提示，不能代替原始故障材料。
这一点参见 [华为应用调试 FAQ](https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-app-debugging-17)。
新包偏移会变化，不要拿本次旧 `0x3125c8` 或 `0x9b61ac` 直接解析另一份包。
符号化使用同次 `.symbols`；反汇编 Dart AOT 代码时使用 `llvm-objdump -D`，
这里的 `-d` 可能把 Dart instructions 当数据而不能显示所需指令。

引擎帧需要匹配实际 `libflutter.so` Build ID 的未剥离符号。
工具链锁中的上游 engine revision 和 OH artifact revision 不是同一个标识，
不能仅凭上游 `42d3…` 或“Dart 3.11.5”就认定引擎符号匹配。

## 10. 防止再次发生

已落实到仓库：

- [工具链锁](../../flutter/toolchain.lock.json)同时登记上游 engine revision、OH engine/HAR/Dart
  revision 及两个平台 `.dill` 的 SHA-256。
- [产物校验](../../tool/ohos_toolchain.py)在首次准备和 DevEco 增量入口读取这些内容；
  缺失或不一致时在生成代码/AOT 前报错，不替用户静默修改共享 SDK。
- [回归测试](../../tests/python/test_ohos_toolchain.py)覆盖两份平台缓存漂移、文件缺失、
  OH 提交不匹配、旧 framework 副本，以及命令行/增量入口提前拒绝。测试由开发者执行。

后续发布仍需：

- 每次发布归档 HAP、AOT symbols、实际 SO 的 Build ID 和工具链指纹，便于配套解析。
- OH artifact revision 更新时明确刷新平台缓存；若向 SDK 维护方反馈，附上缓存版本键
  与下载版本键不一致的源码证据，不把尚未确认的本机操作历史写成既定原因。

验收完成的条件是：**平台哈希匹配、Release 确实重新生成、实际安装包与符号配套，
并且恢复原始 framework 路径后在故障设备上通过冷启动与平台通道回归。**
