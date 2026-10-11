import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 加载错误类型枚举。
enum LoadErrorType {
  sessionExpired,
  loadFailed,
  networkError,
  campusNetworkRequiredAtNight,
  campusNetworkRequired,
  rateLimited,
  ccylActivityLoadFailed,
  ccylBindFailed,
  notLoggedIn,

  /// 本科教务子系统拒绝已建立的统一认证会话（重认证自愈后仍被踢回登录页）：
  /// 多半该子系统没有此账号（研究生账号），重登录无法解决。
  undergradOnly,
}

/// 将 [LoadErrorType] 映射到本地化文案。
extension LoadErrorTypeL10n on LoadErrorType {
  String message(AppLocalizations l10n) => switch (this) {
    LoadErrorType.sessionExpired => l10n.sessionExpired,
    LoadErrorType.loadFailed => l10n.loadFailed,
    LoadErrorType.networkError => l10n.networkError,
    LoadErrorType.campusNetworkRequiredAtNight =>
      l10n.campusNetworkRequiredAtNight,
    LoadErrorType.campusNetworkRequired => l10n.campusNetworkRequired,
    LoadErrorType.rateLimited => l10n.planCompletionRateLimited,
    LoadErrorType.ccylActivityLoadFailed => l10n.ccylActivityLoadFailed,
    LoadErrorType.ccylBindFailed => l10n.ccylBindFailed,
    LoadErrorType.notLoggedIn => '',
    LoadErrorType.undergradOnly => l10n.undergradDataOnly,
  };
}

/// 由捕获到的 [UnauthenticatedException] 选择错误类型。
///
/// 本科教务（zhjw）的会话失效异常若带 undergradOnly 标记（见
/// [UnauthenticatedException]），按 [LoadErrorType.undergradOnly] 给
/// 针对性指引；其余情况沿用调用方原来的分类（[fallback]）。
LoadErrorType zhjwAuthErrorType(
  UnauthenticatedException error, {
  LoadErrorType fallback = LoadErrorType.sessionExpired,
}) => error.undergradOnly ? LoadErrorType.undergradOnly : fallback;

/// 「有缓存但后台刷新失败」场景的提示文案：会话类错误给针对性指引
/// （会话过期 → 重新登录重试；本科教务会话未建立 → 去研究生区），
/// 其余一律走调用方的通用失败文案（[fallback]）。
///
/// 与全量错误态的 [RetryableErrorWidget] 不同，这类场景旧数据还在展示，
/// 提示弱一些是可接受的，但不能把 undergradOnly 落到通用文案——那会
/// 丢掉「研究生账号请用研究生区」的关键指引。
String refreshFailureMessage(
  LoadErrorType type,
  AppLocalizations l10n, {
  required String fallback,
}) => switch (type) {
  LoadErrorType.sessionExpired => l10n.sessionExpired,
  LoadErrorType.undergradOnly => l10n.undergradDataOnly,
  _ => fallback,
};

/// 教务系统（23:00-次日6:00）校外访问关闭。
bool isZhjwClosedAtNight() {
  final hour = DateTime.now().hour;
  return hour >= 23 || hour < 6;
}

/// 在 catch 块中，根据当前时间判断是否需要显示校园网访问提示。
/// 返回 [LoadErrorType.campusNetworkRequiredAtNight]（夜间）或 [defaultType]（其它时段）。
LoadErrorType campusNetworkErrorType(LoadErrorType defaultType) {
  return isZhjwClosedAtNight()
      ? LoadErrorType.campusNetworkRequiredAtNight
      : defaultType;
}

/// 可重试的错误状态组件。
///
/// 支持两种构造方式：
/// - [RetryableErrorWidget]：传入 [LoadErrorType] 枚举，自动解析本地化文案。
/// - [RetryableErrorWidget.message]：传入原始 [String]（如 API 异常消息）。
class RetryableErrorWidget extends StatelessWidget {
  const RetryableErrorWidget({
    super.key,
    required LoadErrorType this.errorType,
    required this.onRetry,
    this.iconSize = 48,
  }) : message = null;

  const RetryableErrorWidget.message({
    super.key,
    required String this.message,
    required this.onRetry,
    this.iconSize = 48,
  }) : errorType = null;

  final LoadErrorType? errorType;
  final String? message;
  final VoidCallback onRetry;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayMessage = message ?? errorType!.message(l10n);
    // undergradOnly 的文案里含「本科账号请重新登录后重试」，补一个前往登录
    // 入口（导航方式与 LoginRequiredWidget 一致，统一走根导航器）。
    final isUndergradOnly = errorType == LoadErrorType.undergradOnly;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: iconSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              displayMessage,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
            if (isUndergradOnly) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // 与 LoginRequiredWidget 相同：统一在根导航器打开登录页，
                  // 避免平板/横屏弹窗场景下误关整个功能弹窗。
                  Navigator.of(logicRootContext).push(
                    MaterialPageRoute(builder: (_) => const ScuLoginPage()),
                  );
                },
                icon: const Icon(Icons.person),
                label: Text(l10n.goToLogin),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
