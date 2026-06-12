import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/models/widget_size.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

import 'battery_optimization_card.dart';
import 'hint_card.dart';

class AddWidgetPage extends StatelessWidget {
  const AddWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.addWidgetPageTitle)),
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

class _AddWidgetContentState extends State<AddWidgetContent>
    with WidgetsBindingObserver {
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
        _status = isIgnoring
            ? BatteryOptimizationStatus.disabled
            : BatteryOptimizationStatus.enabled;
      });
    }
  }

  Future<void> _requestIgnoreBatteryOptimizations() async {
    final service = getIt<WidgetUpdateService>();
    await service.requestIgnoreBatteryOptimizations();
  }

  Widget _buildShowTomorrowSwitch(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    final appConfig = getIt<AppConfigProvider>();
    return SwitchListTile(
      title: Text(localizations.widgetShowTomorrowAfterEnd),
      value: appConfig.widgetShowTomorrow.value,
      onChanged: (v) async {
        appConfig.widgetShowTomorrow.value = v;
        final service = getIt<WidgetUpdateService>();
        try {
          await service.updateWidgetData(force: true);
        } catch (e, st) {
          debugPrint('WidgetUpdate toggle failed: $e');
          debugPrint('$st');
        }
      },
    );
  }

  Future<void> _pinWidget(BuildContext context, WidgetSize size) async {
    final localizations = AppLocalizations.of(context)!;
    final service = getIt<WidgetUpdateService>();
    final success = await service.pinWidget(size.toPinArgument());
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
    final appConfig = getIt<AppConfigProvider>();

    return ListenableBuilder(
      listenable: appConfig.widgetShowTomorrow,
      builder: (context, _) {
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
            // Consolidated single card with size choices
            _WidgetPickerCard(onPin: _pinWidget),
            const SizedBox(height: 16),
            _buildShowTomorrowSwitch(context, localizations),
            const SizedBox(height: 16),
            HintCard(hint: localizations.pinWidgetHint),
          ],
        );
      },
    );
  }
}

class _WidgetPickerCard extends StatefulWidget {
  final Future<void> Function(BuildContext, WidgetSize) onPin;

  const _WidgetPickerCard({required this.onPin});

  @override
  State<_WidgetPickerCard> createState() => _WidgetPickerCardState();
}

class _WidgetPickerCardState extends State<_WidgetPickerCard> {
  WidgetSize _selected = WidgetSize.small;
  bool _isPinning = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppShapes.medium),
                  ),
                  child: Icon(
                    Icons.widgets_outlined,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.addWidgetPageTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.addWidgetDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RadioGroup<WidgetSize>(
              groupValue: _selected,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selected = value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<WidgetSize>(
                    value: WidgetSize.small,
                    title: Text(l10n.widgetSizeSmall),
                    subtitle: Text(l10n.widgetSizeSmallDesc),
                  ),
                  RadioListTile<WidgetSize>(
                    value: WidgetSize.medium,
                    title: Text(l10n.widgetSizeMedium),
                    subtitle: Text(l10n.widgetSizeMediumDesc),
                  ),
                  RadioListTile<WidgetSize>(
                    value: WidgetSize.large,
                    title: Text(l10n.widgetSizeLarge),
                    subtitle: Text(l10n.widgetSizeLargeDesc),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _isPinning
                        ? null
                        : () async {
                            setState(() => _isPinning = true);
                            try {
                              await widget.onPin(context, _selected);
                            } finally {
                              if (mounted) setState(() => _isPinning = false);
                            }
                          },
                    child: _isPinning
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.pinWidgetButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
