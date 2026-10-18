# 日志证据说明

适用于运行日志分析、补材料和日志缺失排查。以下说明对应 `AppLogger` 迁移后的实现；旧版需回到用户 revision 核对 `AuthLogger`、路径、格式与导出能力。当前权威说明为 [logging.md](../../../../docs/architecture/logging.md)，发生冲突时读代码和测试。

## 材料获取与覆盖范围

正常启动时：**我的 → 关于 → 开发者页面 → 运行日志 → 保存并分享**。同页“环境信息”可复制版本与构建信息；设备信息可能需要另外说明。启动失败恢复页也有复制、保存、分享日志入口，DI 未完成时使用启动缓冲。

| 材料 | 包含什么 | 判读限制 |
| --- | --- | --- |
| “复制全部”或启动失败页“复制日志” | 当前进程的整个内存缓冲，经 `exportToText()` 导出 | 不包含磁盘历史；不受查看器筛选影响 |
| `bugaoshan-export-数字.log` | 当前及轮转文件，随后是当前内存上下文 | 两段可以重叠；已有导出快照不会再合入 |
| `bugaoshan.log` | 当前自动落盘文件 | 仅 `WARN` / `ERROR`，可能包含多次启动 |
| `bugaoshan.1.log`、`bugaoshan.2.log` | 较新、较旧的轮转历史 | 不是分卷压缩包；缺少它们会缩短历史窗口 |
| 查看器截图 | 当前分类、级别、tag 筛选下可见的内存日志，最新记录在上方 | 被隐藏的条目不等于没记录；条数不是故障总数 |
| 系统崩溃记录或设备日志 | 原生崩溃、系统终止、平台插件等额外线索 | Dart 日志不能保证覆盖，按平台和故障类型判断是否需要 |

“全部”“认证日志”“业务错误”是查看器视图；业务错误只显示 `business` 分类下的 `WARN` / `ERROR`。认证失败仍属于 `authentication`，不会因严重而进入业务错误视图。级别和 tag 可继续过滤。复制、保存和分享都导出完整缓冲，而非当前筛选结果。

日志目录由 `resolveLogDir()` 解析：Android 优先使用应用外部缓存目录，其他平台使用临时目录，再拼接 `Bugaoshan/logs/`。这不是一个所有设备通用的固定绝对路径。Android 的目录按钮复制路径，不保证系统文件管理器可访问，优先让用户“保存并分享”。

Web 的日志策略仅保留内存；不要承诺原生文件落盘或同样的文件导出交互。若具体 Web 构建出现导出问题，核对该平台实际支持的入口。

## 文本结构与记录边界

当前记录样式示例（示例时间不是用户现场）：

```text
2026-10-14 10:00:00.123 WARN  [business] [ZhjwApiService] 会话失效，重新认证后重试
  error: UnauthenticatedException
2026-10-14 10:00:00.456 ERROR [business] [GradesProvider] 加载成绩失败
  error: StateError: example
#0      example (package:bugaoshan/example.dart:10:2)
```

- 记录首行为日期时间、级别、分类、tag、操作说明；查看器或 `includeDate: false` 的文本可能只有时间。
- `error:` 与随后多行堆栈属于同一条记录。搜索命中后读足上下文，不能把每行都计为独立事件。
- `authentication` / `business` 是调用来源分类，`DEBUG` / `INFO` / `WARN` / `ERROR` 是独立级别。`AppLogger` 的默认分类为认证，`AppLog` 写业务分类；分类本身不能证明根因所在层。
- tag 通常对应类/模块常量；`FlutterError.*`、`PlatformDispatcher`、`Isolate` 是全局错误入口，应继续追堆栈和此前的业务记录。

文件快照的分段由以下标记确定：

```text
# Bugaoshan persisted logs
# file: bugaoshan.2.log
...
# file: bugaoshan.1.log
...
# file: bugaoshan.log
...
# Current in-memory context
# Bugaoshan app log
# exported: ...
# entries: ...
```

历史按旧到新拼接，随后内存也按旧到新导出。存在的文件不足三份是正常情况，分段也可能为空。不要将整份文本再无条件排序；先保留分段、文件来源及原始顺序，再建立分析用时间线。

同一记录可能同时出现在磁盘段和内存段；文件部分写入后恢复也可能造成重复。合并分析时对比完整时间、tag、消息、异常和堆栈，保留来源，不能把重复段直接认定为重复请求。不同时间但内容相同的记录也不能草率去重。

导出头的时间表示取证时刻，没有时区偏移；`entries` 只计当前内存记录。导出文件不自动包含应用版本、构建渠道或设备信息，应与环境信息配对。

## 缺失、重复与截断的解释

| 现象 | 先核对什么 |
| --- | --- |
| 文件没有 `INFO` / `DEBUG` | 自动落盘仅保留 `WARN` / `ERROR`；当前进程内存才可能补充这些级别 |
| 只有最近的内存上下文 | 默认环形缓冲为 1000 条，超出会淘汰；重启、清空也会改变范围 |
| 重启后日志仍有旧错误 | 轮转文件会保留旧启动记录，不能把它们全部归入当前操作 |
| 开关开启但文件没有新记录 | 区分开启意图与实际可写状态，查看落盘不可用原因及丢弃条数 |
| 同一异常出现多条 | 先排除历史/内存重叠、失败写入重放、API/Provider/页面各层补充上下文，再判断业务是否真的重试 |
| 堆栈带 `truncated` | 全局错误的消息、异常与堆栈共享 2000 字符预算；不能声称所有局部日志都按此截断 |
| 图片多次重建但只记录一次失败 | 图片错误按当前展示来源去重；更换来源后可再次记录，日志条数不等于图片重试次数 |
| 办事大厅 HTML 错误缺正文 | 按设计仅记脱敏短标题和响应长度；无法凭标题还原整个响应或断言全部 HTML 都是登录过期 |
| 白屏/闪退但没有 Dart 错误 | 先确认版本、时间窗和日志可用性，再考虑原生崩溃、系统终止或尚未覆盖的错误路径；缺日志不能证明没崩溃 |

所有级别都可进入内存，控制台回显只在 debug 构建启用。不能要求 release 用户通过控制台找回已经淘汰的上下文。

## 落盘与导出故障

- 默认开启连续落盘，单写入队列最多 2000 条；满后累计 `droppedWriteLines`。该计数说明待写日志损失，不是业务请求失败计数，也不是全部历史丢失量。
- `fileSinkEnabled` 是开启意图，`fileSinkUnavailable` 和 `fileSinkError` 表示实际失败。日志系统自身的文件错误仅进内存，避免递归写入；原始磁盘文件可能缺少最有价值的落盘故障说明。
- 文件失效/被缓存清理后会尝试重开，最多连续自动恢复 3 次，实际记录成功刷新后才重置次数。不能建议增加无界恢复循环。
- 文件按 UTF-8 字节达到约 2 MB 后轮转，当前加两份历史共约 6 MB；在完整记录之后轮转，每份可能超出一条记录。总字节数不是精确硬上限，也不包含手动快照。
- 关闭“在本机保留诊断日志”会删除自动轮转文件，保留导出快照；清空内存只清缓冲。**在建议切换落盘开关重试前，先保存/分享现有材料**，避免删除证据。
- 每次导出保留最近 5 份自动数字命名的快照，始终保留本次导出；不要把这些快照当额外轮转历史重新递归收集。
- “分享日志失败，已保存的快照仍可使用”与导出失败不同。先核对快照是否已生成，再决定补取方式。
- Web 不启用文件输出。原生平台启动时在 DI 前按保存的开关初始化落盘并补写已有警告/错误；设置读取失败时仍可能只有内存。DI 沿用启动缓冲，启动恢复页可以导出它。

需要检查磁盘日志是否丢失时，先排除筛选、轮转、手动清理、缓存回收与导出重叠；“写过多少行就一定在当前文件看到多少行”只在容量和保留窗口足够时成立。

## 隐私与源码核对

消息、异常、堆栈和导出历史都会脱敏，但旧版或外部平台材料仍可能包含个人信息。引用只保留必要片段，不要求完整密码、token、Cookie、学号或表单正文；`FormatException` 不带原始 source 属于有意保护诊断边界。

关键实现和行为测试：

- [app_logger.dart](../../../../lib/utils/app_logger.dart)：格式、分类、内存容量、文本导出、脱敏、状态字段。
- [app_logger_file_sink.dart](../../../../lib/utils/app_logger_file_sink.dart)：队列、轮转、恢复、历史快照导出与裁剪。
- [app_error_reporter.dart](../../../../lib/utils/app_error_reporter.dart)、[log_persistence.dart](../../../../lib/utils/log_persistence.dart)：全局异常、截断、启动落盘。
- [log_viewer_page.dart](../../../../lib/pages/dev/logs/log_viewer_page.dart)、[log_persistence_tile.dart](../../../../lib/pages/dev/logs/log_persistence_tile.dart)、[startup_error_app.dart](../../../../lib/pages/startup_error_app.dart)：用户入口和导出反馈。
- [app_logger_file_sink_test.dart](../../../../test/app_logger_file_sink_test.dart)、[app_logger_test.dart](../../../../test/app_logger_test.dart)：跨启动导出、轮转、开关竞态、故障恢复和快照保留。
- [log_viewer_test.dart](../../../../test/log_viewer_test.dart)、[startup_error_logs_test.dart](../../../../test/startup_error_logs_test.dart)、[app_error_handlers_test.dart](../../../../test/app_error_handlers_test.dart)、[image_error_log_test.dart](../../../../test/image_error_log_test.dart)：筛选、启动取证、全局异常、图片去重。
