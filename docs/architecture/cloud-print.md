# 图书馆打印与扫描

入口在校园页「云打印」，可加入自定义底部导航，本科生和研究生均可见。页面使用 `SwipePageView` 展示上传队列、打印任务与扫描文档。

## 认证与依赖

`ScuAuth → CloudPrintAuth → CloudPrintApiService → CloudPrintProvider → CloudPrintPage`，在 `injector.dart` 手动注册。此功能按需认证，不加入 `AuthCoordinator` 全站预热，避免打印站故障阻塞其他功能。

`CloudPrintAuth` 使用根认证的同一 CookieClient：先 POST `/api/client/Auth/Check`，需要登录时 GET `/api/client/Auth/SSoPage` 获取 JSON 中的 `result` 链接，再手动跟随 libic/CAS 回跳。只允许打印站同源和 HTTPS 的 `libic.scu.edu.cn`、`id.scu.edu.cn`，最后要求 Auth/Check 同时返回 `code=0` 和非空 SessionId。不向打印 IP 转发 SCU Bearer 或密码，不记录登录链接中的票据。

回跳链路按浏览器语义协商响应：打印站 `/api/` 请求 `Accept: application/json`，SSoPage 与 libic/CAS 的页面跳转请求 `text/html`，两者都带应用 User-Agent。此前整条链统一请求 JSON，SSO 页面按网页导航协商返回，登录判为失败。每次认证请求只记录方法、主机、路径和状态码；查询串（可能含 CAS 票据）、请求体与 Cookie 一律不入日志。

并发认证合并为一次，缓存绑定根 principal 与 CookieClient；根身份变化会失效。Provider 通过会话代数屏蔽登出、换号后的旧列表、上传、文件选择器与下载回调。队列仅保留在当前应用会话，退出页面后仍可返回查看，应用重启后不恢复上传队列。

## 批量上传

文件选择器支持多选，按本地路径去重；不同目录的同名文件允许分别加入。支持 PDF、图片、TXT、Office 等官网接受的格式，空文件和不支持的后缀不会排队。每项保存独立设置，默认 **A4、黑白、长边双面、全部页、1 份**。统一设置应用于待上传和失败项，也可逐文件覆盖。

协议字段：`szPath` 文件，`dwColor=1/2` 黑白/彩色，`dwPaperId=9/8/-1` A4/A3/原纸型，`dwDuplex=1/2/3` 单面/长边/短边，`dwCopies` 份数，`dwFrom/dwTo=0/0` 全部页或连续页范围，以及 `BackURL`。multipart 按文件流发送，已知 Content-Length，中文名使用兼容网页的 UTF-8 `filename="…"`。

队列串行提交，显示每项进度和结果。进度 100% 代表文件流已读出，页面此时显示「文档处理中」，直到服务器确认。停止按钮只停止后续文件，当前请求会等待结果。明确失败项可单独或批量重新排队，成功项不会自动重传。

上传 POST `/api/client/CloudPrint/Upload` **只能用 `CookieClient.sendOnce`**，不能套 `retryOnUnauthenticated`，也不能用会在 ClientException 后重发的普通 send。POST 后仅允许 301/302/303 跳至同源打印任务页；307/308、超时、连接中断、缺少回跳结果、HTTP 401/403 或 `code=4` 都属于「上传结果待核对」。这些错误可能发生在服务器接收文件之后，不允许自动重试。原上传请求的 413 是明确拒绝，其他回跳异常不会冒充此类明确失败。

回跳 `code=0` 表示接受，再比较上传前后 `/api/client/PrintJob/Get` 的任务 ID 和文件名。任务核对暂不可用时仍保留「已上传」并提示核对；不降级成可以重试的失败。结果不确定时暂停批次，用户查看任务后显式确认未生成任务才可重新排队。打印任务只提取文档元数据，不保存姓名、卡号、账号和服务器内部文件路径。上传只创建待打印任务，实际打印仍需在图书馆终端完成。

## 扫描文档

用户先在图书馆机器完成扫描，本功能读取 `/api/client/Scan/Get`，按日期倒序显示。`dwStatus & 256 != 0` 表示过期，禁用下载与批量选择。下载为 GET `/api/client/Scan/Download?dwJobId=…`；支持多选下载/分享、单项打开与分享、下载进度和失败重试。批次逐项处理，某个文件失败不会丢弃其他成功结果。

扫描件保存在应用文档目录的 `Bugaoshan/scans/<账号摘要>/`，服务端文件名会去除路径分隔符等无效字符。下载先写临时文件，校验响应与完整长度后再生成完成文件；HTML/JSON 错误不能保存成扫描件。只对安全的读取请求恢复认证一次。分享复用 `shareMultipleFiles`，包含 Windows 路径适配与 iPad 弹出锚点。

登出/换号清空页面缓存和选择，不向新账号展示旧下载路径；已经下载到磁盘的扫描件仍保留，用户可通过系统文件管理或应用清理删除。功能不远程操作扫描仪，不包含复印、付款、实际打印或删除服务器文件。

## 验证边界

`cloud_print_test.dart` 覆盖字段、SSO/账号切换、multipart 中文文件名、一次提交、异常分类、批量停止与重试、扫描下载和过期状态。`cloud_print_page_test.dart` 覆盖多选文件、逐项设置、登录入口、窄屏布局、扫描全选和不确定结果确认。

协议依据为现有 SCU-CLI 调查与图书馆公开网页当前接口；未把第三方 HTML/JS 副本加入仓库。自动化测试使用模拟 HTTP 响应、本地文件和 Flutter Widget 环境，不能代替真实校园账号、终端打印、扫描设备或各手机平台分享面板的验收。已在华为 MatePad 11.5（Android 12）用真实账号验收批量选择、逐文件页范围、默认设置、上传建单与打印任务列表读取；终端打印、扫描设备和各平台分享面板仍需在对应硬件上验收。
