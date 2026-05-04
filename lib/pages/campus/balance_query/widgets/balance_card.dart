import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'package:bugaoshan/services/balance_query_service.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class BalanceCard extends StatefulWidget {
  final BalanceQueryProvider provider;
  final int balanceType;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String unit;
  final Future<RoomInfo> Function() onRefresh;
  final RoomBinding binding;

  const BalanceCard({
    super.key,
    required this.provider,
    required this.balanceType,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.unit,
    required this.onRefresh,
    required this.binding,
  });

  @override
  State<BalanceCard> createState() => BalanceCardState();
}

class BalanceCardState extends State<BalanceCard> {
  bool _isLoading = false;
  String? _error;
  RoomInfo? _localInfo; // 本地持有数据，不依赖父级传入

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onSwitchCompleted);
    _loadBalance();
  }

  @override
  void didUpdateWidget(BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        '${oldWidget.binding.schoolCode}_${oldWidget.binding.regCode}_${oldWidget.binding.unitCode}_${oldWidget.binding.roomNo}';
    final newKey =
        '${widget.binding.schoolCode}_${widget.binding.regCode}_${widget.binding.unitCode}_${widget.binding.roomNo}';
    if (oldKey != newKey) {
      _localInfo = null;
      _loadBalance();
    }
  }

  void _onSwitchCompleted() {
    if (_localInfo == null && !_isLoading && !widget.provider.isSwitching) {
      _loadBalance();
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onSwitchCompleted);
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (_localInfo != null) return;

    if (widget.provider.isSwitching) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await widget.onRefresh();
      if (mounted) {
        setState(() {
          _localInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Balance load error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _localInfo = null;
    });
    await _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
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
                    borderRadius: BorderRadius.circular(12),
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
                      Text(
                        widget.binding.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _forceRefresh,
                  ),
              ],
            ),
            const Divider(height: 32),
            AnimatedSize(
              duration: appConfigService.cardSizeAnimationDuration.value,
              curve: appCurve,
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    )
                  : _localInfo == null
                  ? Center(child: Text(l10n.loading))
                  : Column(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                l10n.balance,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _localInfo!.balance,
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              Text(
                                widget.unit,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _infoRow(l10n.roomNumber, _localInfo!.roomNo),
                        _infoRow(l10n.pricePerUnit, '${_localInfo!.price} 元/度'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
