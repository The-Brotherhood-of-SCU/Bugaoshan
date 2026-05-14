import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

enum BatteryOptimizationStatus {
  checking,
  enabled,
  disabled,
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
