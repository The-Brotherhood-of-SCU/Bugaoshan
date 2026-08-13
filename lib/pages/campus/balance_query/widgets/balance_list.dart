import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/balance_query_provider.dart';
import 'balance_card.dart';

class BalanceList extends StatefulWidget {
  final BalanceQueryProvider provider;

  const BalanceList({super.key, required this.provider});

  @override
  State<BalanceList> createState() => _BalanceListState();
}

class _BalanceListState extends State<BalanceList> {
  @override
  void initState() {
    super.initState();
    // initState 发生在父级的 build 期间。推迟到首帧结束后再让 Provider
    // 更新 loading 状态，避免同步 notifyListeners 标记正在构建的父级。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Provider 自己决定是否命中 30 分钟缓存，列表不保存任何余额副本。
      widget.provider.ensureCurrentBalances();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final binding = widget.provider.currentBinding;
        if (binding == null) {
          return Center(child: Text(l10n.balanceQueryNoBinding));
        }

        final balanceKey =
            '${binding.schoolCode}_${binding.regCode}_${binding.unitCode}_${binding.roomNo}';
        return RefreshIndicator(
          onRefresh: () => _refreshAll(context),
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
                binding: binding,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshAll(BuildContext context) async {
    var failed = false;
    for (final type in [kBalanceTypeElectric, kBalanceTypeAc]) {
      try {
        await widget.provider.refreshBalance(type);
      } catch (e) {
        failed = true;
        debugPrint('Balance refresh error: $e');
      }
    }
    if (!failed || !context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
      }
    });
  }
}
