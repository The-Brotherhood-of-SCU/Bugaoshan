# 学生邮箱架构

校园邮箱是独立的 Coremail 账号，不接入 `ScuAuth` 或 `AuthCoordinator`。

## 接入方式

- `lib/pages/campus/email/` 使用 Flutter 组件展示绑定、收件箱、邮件详情、附件和写信页面，不加载网页邮箱。
- `lib/services/email/email_service.dart` 使用 IMAP over TLS 收信、SMTP over TLS 发信。列表只读取 envelope，点开邮件时再取正文和附件信息；附件按需下载。
- 账号、密码或客户端授权码、服务器参数以单个 JSON 值写入 `SecureStorageProvider`。解绑时删除该值并断开连接。邮件正文不另做本地缓存。
- HTML 邮件只提取纯文本，不执行脚本，也不加载远程图片。
- Web 目标使用说明页；原生页面通过条件导出提供给支持 `dart:io` 的目标。

默认主机 `uni-edu.icoremail.net` 是根据 `stu.scu.edu.cn` 的公开 MX 记录、Coremail 服务欢迎语，以及 993 / 465 端口的 TLS 证书验证结果选定的。学生邮箱官网登录页链接的客户端设置附件目前无法从开发环境读取，因此默认值仍需用真实学生账号验证。绑定页允许用户修改主机和端口，连接时会验证 IMAP 和 SMTP 登录后再保存账号。不要通过跳过证书验证来连接 `mail.stu.scu.edu.cn`，该域名在邮件端口返回的证书与主机名不匹配。

Coremail 的二次验证或安全策略可能要求先在网页邮箱完成验证，再生成「客户端专用密码」用于 IMAP/SMTP。绑定页提供打开官网按钮，并按 IMAP 登录、收件箱读取、SMTP 登录三阶段显示失败位置；服务器原始响应不直接展示，以免泄露账号信息。未取得真实学生账号验证结果前，不能将认证失败直接归因为新设备验证。

`enough_mail` 固定在 2.1.6，以兼容项目的 `encrypt` / `pointycastle` 3 依赖。该版本要求旧版 `intl`，而 Flutter 固定 `intl` 0.20.2，因此 `pubspec.yaml` 对 `intl` 做定向覆盖；升级邮件库时应重新检查这组约束。

当前页面提供单收件人纯文本发信、多个附件选择与移除、最近邮件分页、读信、附件下载和系统打开。发信附件在内存中按 MIME 类型编码后随 multipart/mixed 邮件发送；后台新邮件通知、邮件夹管理和富文本编辑未实现。
