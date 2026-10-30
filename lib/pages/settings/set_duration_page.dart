import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/theme_shape.dart';

class SetDurationPage extends ConsumerStatefulWidget {
  const SetDurationPage({super.key});

  @override
  ConsumerState<SetDurationPage> createState() => _SetDurationPageState();
}

class _SetDurationPageState extends ConsumerState<SetDurationPage> {
  late int _tempAnimationTime; // 临时存储未确认的值
  bool _isAnimating = false; // 动画状态
  bool _shouldAnimate = true; // 控制动画循环的标志位

  @override
  void initState() {
    super.initState();
    _tempAnimationTime =
        ref.read(cardSizeAnimationDurationSettingProvider).inMilliseconds;

    // 启动预览动画
    _startAnimation();
  }

  @override
  void dispose() {
    _shouldAnimate = false; // 停止动画循环
    super.dispose();
  }

  Future<void> _startAnimation() async {
    while (_shouldAnimate && mounted) {
      await Future.delayed(Duration(milliseconds: _tempAnimationTime + 100));

      if (!_shouldAnimate || !mounted) break;

      setState(() {
        _isAnimating = true;
      });

      await Future.delayed(Duration(milliseconds: _tempAnimationTime + 100));

      if (!_shouldAnimate || !mounted) break;

      setState(() {
        _isAnimating = false;
      });
    }
  }

  void _updateAnimationTime(double value) {
    setState(() {
      _tempAnimationTime = value.round();
    });
  }

  void _confirmChanges() {
    ref.read(cardSizeAnimationDurationSettingProvider.notifier).update(
      Duration(milliseconds: _tempAnimationTime),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appLang = AppLocalizations.of(context)!;
    final enableDockAnim = ref.watch(enableDockSwitchAnimationSettingProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(appLang.animationDuration),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdaptiveGlassSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(appLang.enableDockSwitchAnimation),
              subtitle: Text(appLang.enableDockSwitchAnimationHint),
              value: enableDockAnim,
              onChanged: (v) => ref
                  .read(enableDockSwitchAnimationSettingProvider.notifier)
                  .update(v),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                appLang.currentAnimationDuration(_tempAnimationTime),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            AdaptiveGlassSlider(
              semanticLabel: appLang.animationDuration,
              value: _tempAnimationTime.toDouble(),
              min: 0,
              max: 1000,
              divisions: 20,
              label: '$_tempAnimationTime ms',
              onChanged: _updateAnimationTime,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),

            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppShapes.medium),
                ),
                child: Center(
                  child: AnimatedContainer(
                    width: _isAnimating ? 150 : 100,
                    height: _isAnimating ? 150 : 100,
                    decoration: BoxDecoration(
                      color: _isAnimating
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(
                        _isAnimating ? 30 : 10,
                      ),
                    ),
                    duration: Duration(milliseconds: _tempAnimationTime),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.flutter_dash,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                appLang.animationDurationHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: _confirmChanges,
                child: Text(appLang.confirmButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
