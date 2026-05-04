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
        await widget.provider.queryElectricInfo();
        await widget.provider.queryAcInfo();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(
            key: ValueKey('electric_$balanceKey'),
            provider: widget.provider,
            balanceType: 2,
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
            balanceType: 1,
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
