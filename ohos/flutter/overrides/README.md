# 鸿蒙 Dart 文件覆盖

`lib/` 保存适配后的完整 Dart 文件。未出现在本目录的业务源码直接使用仓库根 `lib/`。
本目录不单独运行 `pub get`，也不是第二个 Flutter 应用。

构建入口按 [源码清单](../source-manifest.json) 检查上游基线，在 `ohos/.flutter-workspace/lib/`
逐文件建立链接：有覆盖时指向本目录，无覆盖时指向根 `lib/`。
例如编译工程的 `lib/main.dart` 链接 `overrides/lib/main.dart`。包名、相对导入及
`package:bugaoshan/...` 导入保持统一。各级源码目录是普通目录，生成代码使用鸿蒙本地文件。

## 修改代码

直接编辑本目录的 Dart 文件，已有链接立即读取修改后的内容；新增或删除文件后重新运行构建入口。
通过编译工程里的链接编辑文件，也会修改它指向的维护文件；不要通过共用链接修改根源码。
不要提交 `ohos/build/`，也不要对整个链接工程执行格式化。
新增覆盖文件时，同时在 `source-manifest.json` 的 `files` 中登记：

- `path`：相对根工程的 `lib/...dart`。
- `upstreamSha256`：对应上游文件的 SHA-256，计算前仅将 CRLF 统一为 LF；BOM 和其他字节保留。
  鸿蒙新增、上游不存在的文件使用 `null`。

清单未登记的 Dart 文件、丢失的覆盖文件及新增文件与上游重名都会阻止组装。
修改鸿蒙文件本身不要求更新上游哈希；哈希记录的是被覆盖的上游文件。

## 同步上游

在仓库根目录检查，不需要 SDK、Pub 或原生工具链：

```powershell
python ohos/tool/ohos_sources.py --check
```

没有被覆盖的上游文件可直接跟随更新。被覆盖文件发生变化时，检查会列出路径、原基线及
当前 SHA-256。先对照上游变化合并对应鸿蒙文件，再将清单更新为检查输出的当前哈希；
不要直接刷新全部哈希。`upstreamRevision` 记录最近整体同步所依据的源码提交，
实际构建按逐文件哈希检查，提交号变化本身不阻止构建。

翻译只维护 [l10n/](../l10n/README.md) 中的差异条目，按键合并。
源码基线检查只能发现覆盖文件及覆盖条目的变化，不替代依赖、接口和真机回归检查。

## 分析与构建

[analysis_options.yaml](analysis_options.yaml) 排除本目录的 `lib/**`，使根工程的上游 SDK
不单独分析这些缺少共用文件和鸿蒙依赖的维护文件。
此配置不覆盖副本根目录的 `analysis_options.yaml`；在副本中分析最终 `lib/`、运行测试。
它也不改变 `dart format` 的文件选择规则。

构建命令仍使用 [build_ohos.py](../../tool/build_ohos.py)，见 [脚本说明](../../tool/README.md)。
此前 26 个源码补丁已转换为这里的完整 Dart 文件。迁移时为 65 个，后经精简为当前的
43 个：28 个覆盖上游、15 个仅鸿蒙新增。编号、内容摘要和迁移范围见
[迁移记录](../../docs/audits/source-overlay-migration.md)。插件和嵌入层仍使用各自补丁。
