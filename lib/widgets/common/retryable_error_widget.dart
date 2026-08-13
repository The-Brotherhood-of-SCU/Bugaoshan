import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

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
  };
}

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
          ],
        ),
      ),
    );
  }
}
