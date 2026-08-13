import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_trend_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class BalanceCard extends StatefulWidget {
  final BalanceQueryProvider provider;
  final int balanceType;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String unit;
  final RoomBinding binding;

  const BalanceCard({
    super.key,
    required this.provider,
    required this.balanceType,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.unit,
    required this.binding,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _privacyHidden = true;

  Future<void> _forceRefresh() async {
    try {
      await widget.provider.refreshBalance(widget.balanceType);
    } catch (_) {
      // Provider 保存错误状态，卡片会随 ListenableBuilder 重建。
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = widget.provider.balanceStateFor(widget.balanceType);
    final info = state.value;
    final isWaitingForSwitch = widget.provider.isSwitching && !state.hasValue;
    final isLoading = state.isLoading || isWaitingForSwitch;

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _privacyHidden = !_privacyHidden),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _privacyHidden
                                    ? widget.binding.displayName
                                          .split(' ')
                                          .take(2)
                                          .join(' ')
                                    : widget.binding.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _privacyHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (info != null)
                        IconButton(
                          icon: const Icon(Icons.insights_outlined),
                          tooltip: l10n.balanceTrend,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BalanceTrendPage(
                                provider: widget.provider,
                                balanceType: widget.balanceType,
                                title: widget.title,
                                themeColor: widget.iconColor,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _forceRefresh,
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 32),
            AnimatedSize(
              duration: appConfigService.cardSizeAnimationDuration.value,
              curve: appCurve,
              child: state.error != null
                  ? Center(
                      child: Text(
                        l10n.loadFailed,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : info == null
                  ? _loadingBody(context, l10n)
                  : _contentBody(
                      context,
                      l10n,
                      info.balance,
                      info.roomNo,
                      info.price,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBody(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Text(
                l10n.balance,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.loading,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                widget.unit,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _infoRow(context, l10n.roomNumber, '—'),
        _infoRow(context, l10n.pricePerUnit, '—'),
      ],
    );
  }

  Widget _contentBody(
    BuildContext context,
    AppLocalizations l10n,
    String balance,
    String roomNo,
    String price,
  ) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Text(
                l10n.balance,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                balance,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                widget.unit,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _infoRow(context, l10n.roomNumber, _privacyHidden ? '***' : roomNo),
        _infoRow(context, l10n.pricePerUnit, l10n.pricePerUnitValue(price)),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
