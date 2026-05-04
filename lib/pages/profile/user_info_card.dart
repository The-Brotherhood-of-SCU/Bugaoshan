import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/profile/profile_labels_notifier.dart';

class UserInfoCard extends StatelessWidget {
  final ProfileLabelsNotifier labelsNotifier;
  final VoidCallback onRetry;
  final bool isLoggedIn;

  const UserInfoCard({
    super.key,
    required this.labelsNotifier,
    required this.onRetry,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final primaryColor = theme.colorScheme.primary;

    Widget child;
    VoidCallback? onTap;

    if (!isLoggedIn) {
      child = Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Text(
            localizations.loginToViewUserInfo,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      onTap = null;
    } else if (labelsNotifier.loading) {
      child = _buildLoadingContent(theme, localizations);
      onTap = null;
    } else if (labelsNotifier.error) {
      child = _buildErrorContent(theme, localizations, primaryColor);
      onTap = onRetry;
    } else {
      final labels = labelsNotifier.labels;
      if (labels == null || labels.isEmpty) {
        return const SizedBox.shrink();
      }
      child = _buildLabelsContent(theme, primaryColor, localizations, labels);
      onTap = onRetry;
    }

    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }
    return card;
  }

  Widget _buildLoadingContent(ThemeData theme, AppLocalizations localizations) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          localizations.userInfoLoading,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(
    ThemeData theme,
    AppLocalizations localizations,
    Color primaryColor,
  ) {
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            localizations.userInfoLoadFailed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          localizations.userInfoRetry,
          style: theme.textTheme.bodySmall?.copyWith(color: primaryColor),
        ),
      ],
    );
  }

  Widget _buildLabelsContent(
    ThemeData theme,
    Color primaryColor,
    AppLocalizations localizations,
    List<Map<String, dynamic>> labels,
  ) {
    String localizeLabel(String apiName) {
      return switch (apiName) {
        '图书借阅量' => localizations.labelBookBorrowCount,
        '校园卡余额' => localizations.labelCampusCardBalance,
        '网费余额' => localizations.labelNetworkFeeBalance,
        _ => apiName,
      };
    }

    return Row(
      children: labels.map((label) {
        final apiName = label['name'] as String? ?? '';
        final name = localizeLabel(apiName);
        final value = label['value'];
        final valueStr = value is num ? value.toString() : value.toString();
        final isLast = label == labels.last;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12),
            child: Column(
              children: [
                Text(
                  valueStr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
