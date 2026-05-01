import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class SetDurationPage extends StatefulWidget {
  const SetDurationPage({super.key});

  @override
  State<SetDurationPage> createState() => _SetDurationPageState();
}

class _SetDurationPageState extends State<SetDurationPage> {
  late int _tempAnimationTime; // 临时存储未确认的值
  bool _isAnimating = false; // 动画状态
  bool _shouldAnimate = true; // 控制动画循环的标志位

  @override
  void initState() {
    super.initState();
    // 初始化当前动画时长为配置中的值
    _tempAnimationTime =
        appConfigService.cardSizeAnimationDuration.value.inMilliseconds;

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
      // 等待500ms后开始动画
      await Future.delayed(Duration(milliseconds: _tempAnimationTime + 100));

      if (!_shouldAnimate || !mounted) break;

      setState(() {
        _isAnimating = true;
      });

      // 等待动画时长 + 500ms后结束动画
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

  final appConfigService = getIt<AppConfigProvider>();

  void _confirmChanges() {
    appConfigService.cardSizeAnimationDuration.value = Duration(
      milliseconds: _tempAnimationTime,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appLang = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(appLang.animationDuration),
        actions: [
          TextButton(
            onPressed: _confirmChanges,
            child: Text(
              appLang.confirm,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                appLang.currentAnimationDuration(_tempAnimationTime),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            Slider(
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
                  borderRadius: BorderRadius.circular(12),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
