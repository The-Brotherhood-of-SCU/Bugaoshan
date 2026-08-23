# Bugaoshan 工程文档

本目录只保存需要长期维护的架构说明和设计决策。功能介绍、构建方式和贡献流程分别以仓库根目录的 `README.md`、`CONTRIBUTING.md` 和 `AGENTS.md` 为准。

## 当前架构

当前架构文档描述代码现在如何工作，必须随实现变更同步更新。

| 文档 | 范围 | 状态 |
|---|---|---|
| [认证架构](architecture/authentication.md) | SCU 根认证、子系统认证、重试、会话隔离和 DI | 当前实现 |
| [通知 WebView 架构](architecture/notice-webview.md) | 三类通知来源、JS bridge、附件下载和平台边界 | 当前实现 |
| [Linux 分发架构](architecture/linux-distribution.md) | 本地构建、WPE 边界、Flatpak、AUR 和 Debian 状态 | 当前实现 |
| [Sentry 错误收集与问题反馈](architecture/sentry-feedback.md) | DSN 注入、错误链路、反馈表单、附件与 CI 配置 | 当前实现 |

## 设计决策

已接受的长期设计决策记录在 [`decisions/`](decisions/README.md)。ADR 说明为什么选择某个方向，不重复维护完整代码结构。

## 维护规则

1. 架构文档与代码冲突时以代码为准，并在同一变更中修正文档。
2. ADR 一旦接受，只修正事实错误；方向改变时新增 ADR，并把旧 ADR 标记为已取代。
3. 临时实施清单、已完成的迁移步骤和可由 Git 直接还原的变更摘要不单独保留。
4. 文档使用仓库相对链接，不写本机绝对路径或易失效的代码行号。
5. 新增文档前先判断它属于“当前实现”“设计决策”还是现有开发指南，避免多处维护同一事实。
