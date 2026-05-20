import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class TappableErrorWidget extends StatelessWidget {
  const TappableErrorWidget({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onRetry,
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RetryableErrorWidget extends StatelessWidget {
  const RetryableErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.iconSize = 48,
  });

  final String message;
  final VoidCallback onRetry;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: iconSize,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GlassButton.custom(
            onTap: onRetry,
            width: 140,
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  l10n.gradesRetry,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
