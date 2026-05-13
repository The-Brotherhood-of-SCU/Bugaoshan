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
    // Re-check after returning from settings
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkBatteryOptimization();
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
        AnimatedSize(
          duration: getIt<AppConfigProvider>().cardSizeAnimationDuration.value,
          child: switch (_status) {
            BatteryOptimizationStatus.checking => _buildLoadingCard(colorScheme, localizations),
            BatteryOptimizationStatus.enabled => _buildOptimizationsEnabledCard(colorScheme, localizations),
            BatteryOptimizationStatus.disabled => _buildOptimizationsDisabledCard(colorScheme, localizations),
          },
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
        Card(
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
                    localizations.pinWidgetHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(ColorScheme colorScheme, AppLocalizations localizations) {
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

  Widget _buildOptimizationsEnabledCard(ColorScheme colorScheme, AppLocalizations localizations) {
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
                    onPressed: _requestIgnoreBatteryOptimizations,
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

  Widget _buildOptimizationsDisabledCard(ColorScheme colorScheme, AppLocalizations localizations) {
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