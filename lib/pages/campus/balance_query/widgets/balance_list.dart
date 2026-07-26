import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'balance_card.dart';

class BalanceList extends StatefulWidget {
  final BalanceQueryProvider provider;

  const BalanceList({super.key, required this.provider});

  @override
  State<BalanceList> createState() => BalanceListState();
}

class BalanceListState extends State<BalanceList> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final binding = widget.provider.currentBinding;

    if (binding == null) {
      return Center(child: Text(l10n.balanceQueryNoBinding));
    }

    final balanceKey =
        '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';

    return RefreshIndicator(
      onRefresh: () async {
        // 两次查询相互独立，任一失败都不影响另一次；捕获异常避免逃逸为未处理错误。
        var failed = false;
        for (final query in [
          widget.provider.queryElectricInfo,
          widget.provider.queryAcInfo,
        ]) {
          try {
            await query();
          } catch (e) {
            failed = true;
            debugPrint('Balance refresh error: $e');
          }
        }
        if (failed && mounted) {
          // 等待 RefreshIndicator 完成后再展示 SnackBar，避免与列表手势冲突
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
            }
          });
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(
            key: ValueKey('electric_$balanceKey'),
            provider: widget.provider,
            balanceType: kBalanceTypeElectric,
            icon: Icons.electric_bolt,
            iconColor: Colors.amber,
            title: l10n.electricityFee,
            unit: l10n.unitKwh,
            onRefresh: () => widget.provider.queryElectricInfo(),
            binding: binding,
          ),
          const SizedBox(height: 12),
          BalanceCard(
            key: ValueKey('ac_$balanceKey'),
            provider: widget.provider,
            balanceType: kBalanceTypeAc,
            icon: Icons.ac_unit,
            iconColor: Colors.lightBlue,
            title: l10n.acFee,
            unit: l10n.unitKwh,
            onRefresh: () => widget.provider.queryAcInfo(),
            binding: binding,
          ),
        ],
      ),
    );
  }
}
