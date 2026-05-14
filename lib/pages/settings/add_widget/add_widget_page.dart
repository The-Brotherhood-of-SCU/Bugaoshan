import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/widget_update_service.dart';

import 'battery_optimization_card.dart';
import 'hint_card.dart';
import 'widget_size_card.dart';

class AddWidgetPage extends StatelessWidget {
  const AddWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.addWidgetPageTitle),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: AddWidgetContent(),
      ),
    );
  }
}

class AddWidgetContent extends StatefulWidget {
  final bool showDescription;

  const AddWidgetContent({super.key, this.showDescription = true});

  @override
  State<AddWidgetContent> createState() => _AddWidgetContentState();
}

class _AddWidgetContentState extends State<AddWidgetContent> with WidgetsBindingObserver {
  BatteryOptimizationStatus _status = BatteryOptimizationStatus.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimization();
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) {
      setState(() => _status = BatteryOptimizationStatus.disabled);
      return;
    }
    final service = getIt<WidgetUpdateService>();
    final isIgnoring = await service.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() {
        _status = isIgnoring ? BatteryOptimizationStatus.disabled : BatteryOptimizationStatus.enabled;
      });
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    final service = getIt<WidgetUpdateService>();
    await service.requestIgnoreBatteryOptimizations();
  }

  Future<void> _pinWidget(BuildContext context, String size) async {
    final localizations = AppLocalizations.of(context)!;
    final service = getIt<WidgetUpdateService>();
    final success = await service.pinWidget(size);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? localizations.pinWidgetSuccess
              : localizations.pinWidgetNotSupported,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showDescription) ...[
          Text(
            localizations.addWidgetDesc,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
        BatteryOptimizationCard(
          status: _status,
          onRequestIgnore: _requestIgnoreBatteryOptimizations,
        ),
        const SizedBox(height: 16),
        WidgetSizeCard(
          icon: Icons.widgets_outlined,
          title: localizations.widgetSizeSmall,
          description: localizations.widgetSizeSmallDesc,
          sizeLabel: '2×2',
          onPressed: () => _pinWidget(context, 'small'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 12),
        WidgetSizeCard(
          icon: Icons.view_module_outlined,
          title: localizations.widgetSizeMedium,
          description: localizations.widgetSizeMediumDesc,
          sizeLabel: '4×2',
          onPressed: () => _pinWidget(context, 'medium'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 12),
        WidgetSizeCard(
          icon: Icons.dashboard_outlined,
          title: localizations.widgetSizeLarge,
          description: localizations.widgetSizeLargeDesc,
          sizeLabel: '4×4',
          onPressed: () => _pinWidget(context, 'large'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 16),
        HintCard(hint: localizations.pinWidgetHint),
      ],
    );
  }
}
