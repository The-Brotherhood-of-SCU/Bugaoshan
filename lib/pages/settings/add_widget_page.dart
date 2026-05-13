import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';

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

enum BatteryOptimizationStatus {
  checking,
  enabled,
  disabled,
}

class _AddWidgetContentState extends State<AddWidgetContent> {
  BatteryOptimizationStatus _status = BatteryOptimizationStatus.checking;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
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
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkBatteryOptimization();
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showDescription) ...[
          Text(
            localizations.addWidgetDesc,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
        BatteryOptimizationCard(
          status: _status,
          onRequestIgnore: _requestIgnoreBatteryOptimizations,
        ),
        const SizedBox(height: 16),
        _WidgetSizeCard(
          icon: Icons.widgets_outlined,
          title: localizations.widgetSizeSmall,
          description: localizations.widgetSizeSmallDesc,
          sizeLabel: '2×2',
          onPressed: () => _pinWidget(context, 'small'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 12),
        _WidgetSizeCard(
          icon: Icons.view_module_outlined,
          title: localizations.widgetSizeMedium,
          description: localizations.widgetSizeMediumDesc,
          sizeLabel: '4×2',
          onPressed: () => _pinWidget(context, 'medium'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 12),
        _WidgetSizeCard(
          icon: Icons.dashboard_outlined,
          title: localizations.widgetSizeLarge,
          description: localizations.widgetSizeLargeDesc,
          sizeLabel: '4×4',
          onPressed: () => _pinWidget(context, 'large'),
          pinLabel: localizations.pinWidgetButton,
        ),
        const SizedBox(height: 16),
        _HintCard(hint: localizations.pinWidgetHint),
      ],
    );
  }
}

class BatteryOptimizationCard extends StatelessWidget {
  final BatteryOptimizationStatus status;
  final VoidCallback onRequestIgnore;

  const BatteryOptimizationCard({
    super.key,
    required this.status,
    required this.onRequestIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final duration = getIt<AppConfigProvider>().cardSizeAnimationDuration.value;

    return AnimatedSize(
      duration: duration,
      child: switch (status) {
        BatteryOptimizationStatus.checking => _LoadingCard(localizations: localizations),
        BatteryOptimizationStatus.enabled => _OptimizationEnabledCard(
            localizations: localizations,
            colorScheme: colorScheme,
            onRequestIgnore: onRequestIgnore,
          ),
        BatteryOptimizationStatus.disabled => _OptimizationDisabledCard(
            localizations: localizations,
            colorScheme: colorScheme,
          ),
      },
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final AppLocalizations localizations;

  const _LoadingCard({required this.localizations});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              localizations.loading,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptimizationEnabledCard extends StatelessWidget {
  final AppLocalizations localizations;
  final ColorScheme colorScheme;
  final VoidCallback onRequestIgnore;

  const _OptimizationEnabledCard({
    required this.localizations,
    required this.colorScheme,
    required this.onRequestIgnore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.battery_alert,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.batteryOptimizationTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.batteryOptimizationDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: onRequestIgnore,
                    child: Text(localizations.batteryOptimizationButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptimizationDisabledCard extends StatelessWidget {
  final AppLocalizations localizations;
  final ColorScheme colorScheme;

  const _OptimizationDisabledCard({
    required this.localizations,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                localizations.batteryOptimizationAlreadyDisabled,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String hint;

  const _HintCard({required this.hint});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetSizeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String sizeLabel;
  final VoidCallback onPressed;
  final String pinLabel;

  const _WidgetSizeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.sizeLabel,
    required this.onPressed,
    required this.pinLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onPressed,
              child: Text(pinLabel),
            ),
          ],
        ),
      ),
    );
  }
}