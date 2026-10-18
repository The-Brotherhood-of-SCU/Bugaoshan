# 诊断与代码定位

按现象读取相关部分。路径均相对于仓库根；使用用户版本核对实际符号，路径不是跨版本不变的接口。

## 认证与校园服务

权威边界见 [authentication.md](../../../../docs/architecture/authentication.md) 和根 `AGENTS.md`。按实际依赖追踪，不假定所有子系统按日志先后串行登录。

| 现象/线索 | 实现入口 | 有价值的验证 |
| --- | --- | --- |
| 统一认证、验证码、token 刷新、`bindSession` | `lib/services/auth/scu_auth.dart`、`cookie_client.dart`、`lib/providers/scu_auth_provider.dart` | `test/scu_auth_test.dart`、`cookie_client_test.dart` |
| 登录后部分校园服务失败、依赖预热、账号切换 | `lib/services/auth/auth_coordinator.dart`、对应 `*_auth.dart`、`lib/injection/injector.dart` | `test/auth_coordinator_test.dart`、对应子系统认证测试 |
| 成绩/教务/缴费等会话过期 | 对应 API/Provider 与 `lib/services/api/api_request.dart` | 对应 API/Provider 测试、`test/api_request_logging_test.dart`、`looks_like_login_page_test.dart` |
| 第二课堂重复认证、报名或业务错误 | `lib/services/auth/ccyl_auth.dart`、`lib/services/api/ccyl_api_service.dart`、`lib/services/ccyl/ccyl_service.dart` | `test/ccyl_auth_generation_test.dart`、`ccyl_auth_principal_test.dart`、`ccyl_api_retry_test.dart` |
| 报修的独立 token、工单或表单 | `lib/services/auth/zhhq_auth.dart`、`lib/services/api/zhhq_api_service.dart`、`lib/providers/zhhq_repair_provider.dart` | `test/zhhq_api_service_test.dart`、`zhhq_repair_provider_test.dart` |
| 办事大厅表单、HTML 响应、提交失败 | `lib/services/auth/service_auth.dart`、`lib/services/api/service_api_service.dart`、`lib/pages/campus/service_hall/` | `test/service_api_service_test.dart`、`service_form_controller_test.dart` |

关键判读：

- `ScuAuth` 登录成功不代表每个子系统可用。`AuthCoordinator` 按依赖图预热；无依赖模块可并行，PayApp 依赖 WFW。失败应按实际依赖判断影响面，不能把一项失败扩大为整个账号失效。
- 公共 `retryOnUnauthenticated()` 在首次 `UnauthenticatedException` 后记 `WARN`、失效并重试一次；后续成功可能没有落盘成功行。只有落盘片段不足以确定最终失败，应核对内存、页面结果和下一条请求。
- 普通网络、解析或业务错误不自动等于会话过期。HTTP 状态、业务错误码、登录跳转与解析失败要分别取证，不能见到 HTML 或 JSON 解码失败就建议重新登录。
- 第二课堂只捕获明确的 `CcylAuthExpiredException` 恢复并重试一次；普通 `CcylException` 不应重放。报名、提交工单和表单等有副作用操作，排查优先用已有材料、只读查询或 mock，实际重放按用户授权执行。
- 账号切换问题需核对 principal、generation、异步结果回写和缓存归属。日志已脱敏时，用事件顺序和状态变化判断，不要求还原真实账号。
- 报修业务使用自己的 tokenKey；不能仅因 SCU 当前会话不可用就断言已有报修 token 不可用。核对具体错误码及该版本实现。

## 课表、小组件和平台行为

| 现象 | 入口与验证方向 |
| --- | --- |
| 编辑、复制、导入后数据异常 | `lib/providers/course_provider.dart`、`lib/services/database_service.dart` 和对应页面/解析器；查 `test/course_*`、`schedule_import_sheet_test.dart` |
| 小组件未更新、隐私或显示设置不一致 | `lib/services/widget_update_service.dart` 与对应平台的 `android/`、`ios/`、`macos/` 实现；查 `test/widget_update_service_test.dart`，必要时真机验证 |
| 课前提醒或实时活动 | `lib/services/reminder/reminder_service.dart`、`lib/services/reminder/live_activity_service.dart`、`lib/services/reminder/live_activity_coordinator.dart` 与平台实现；查对应测试和开发者页面探针 |
| 通知空白、附件下载或 WebView 失败 | `lib/widgets/webview/`、`lib/pages/campus/notice/`、`lib/services/download_manager.dart`、`assets/js/`；查 `test/webview_notice_handlers_test.dart`、`download_manager_test.dart` |
| 原生方法调用、图标、存储、窗口失败 | 从 `PlatformException` 的 code/message 和调用 tag 定位 Dart 入口，再核对相应平台实现、权限与系统环境 |

- 区分数据源、选中的课表/学期、北京时间/设备时区和课程周数口径，再判断展示错误；不要只凭一张小组件截图修改公共周次计算。
- Flutter 层记录“已请求同步”或原生通道返回，不保证系统已展示新的小组件/实时活动。结合平台侧结果；系统调度、权限和用户关闭功能应与应用错误分别描述。
- 不从一台设备推导所有平台。mock MethodChannel、普通 widget test 或测试文件存在，只能证明相应逻辑；需要设备的行为应说明待验证平台。
- 图片日志按来源去重，WebView 与附件有自己的 cookie/下载链路；先读对应模块而非套用统一认证结论。

## 启动与日志系统自身

启动错误先看 `main.dart`、`lib/injection/injector.dart`、`lib/pages/startup_error_app.dart`、`lib/utils/log_persistence.dart`，再按堆栈定位失败依赖。`AppLog.bootstrapLogger` 在 DI 前记录，DI 沿用同一实例；恢复页能保存历史与内存日志，不能只建议用户重新打开正常开发者页。

`FlutterError.*`、`PlatformDispatcher`、`Isolate` 是捕获边界。定位业务堆栈、首个错误和此前状态；不能把 `setupGlobalErrorHandlers()` 本身当成业务崩溃原因。全局兜底不覆盖原生进程崩溃或操作系统终止。

落盘故障、导出重复或缺记录先按 [日志证据说明](log-evidence.md) 排除保留策略和材料范围，再读 `app_logger_file_sink.dart` 的串行操作、恢复和丢弃逻辑。日志系统的错误不应通过吞掉原业务异常或修改业务重试来掩盖。

## 修复建议与交接

- 改恢复/重试方案前先搜索已有机制，`git log -S` / `git blame` 核对禁用或被替代逻辑的来历。用户提出的“自动重启”“全部重新登录”不直接等于正确修复层级。
- 保持服务分层、账号隔离、异常传播和用户数据边界。真实捕获异常用 `AppLog.e` 或认证 logger，附 `error` 与 `stackTrace`；可恢复路径可记 `WARN`。`guard` 记录后重抛，不负责新增重试。
- 测试优先验证失败与恢复的外部行为，不用日志文案匹配代替行为验证。认证恢复还应覆盖失败隔离和不重复提交；日志修复覆盖实际文件内容/顺序/保留范围。
- 给开发者的复现用例使用脱敏或合成数据。`test/service_capture_calibration_test.dart` 的真实抓包 fixture 不入库，缺失导致跳过不代表接口行为已验证。
- 本地验证应遵守根 `AGENTS.md` 的工具链与测试隔离要求；未运行、被跳过、仅 mock 或需要真机的部分都如实说明。
- 调查同类 issue 时核对版本、症状和实际证据；不可访问时说明限制，不编造已有结论或据此拒绝问题。

为修复者交接时，提供用户目标、实际/预期结果、报告版本、复现步骤、关键原始记录及来源、已核实调用链、待验证假设和最小回归场景。把假设与已经证实的事实分开，保留可能推翻当前判断的证据。
