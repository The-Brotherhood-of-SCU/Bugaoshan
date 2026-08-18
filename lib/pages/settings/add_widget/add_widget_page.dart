import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/models/widget_size.dart';
import 'package:bugaoshan/theme_shape.dart';

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
  final TargetPlatform? debugPlatformOverride;

  const AddWidgetContent({
    super.key,
    this.showDescription = true,
    this.debugPlatformOverride,
  });

  @override
  State<AddWidgetContent> createState() => _AddWidgetContentState();
}

class _AddWidgetContentState extends State<AddWidgetContent>
    with WidgetsBindingObserver {
  /// 提交 pin 请求后,等待该时长再做"弹窗是否出现"的判定
  static const _pinVerifyDelay = Duration(seconds: 5);

  BatteryOptimizationStatus _status = BatteryOptimizationStatus.checking;

  /// pin 请求已提交但尚未确认结果
  bool _pinPending = false;

  /// pin 请求提交后应用是否 pause 过(系统确认弹窗出现时应用通常会被 pause)
  bool _pausedSincePin = false;

  /// pin 请求提交前桌面上已有的小组件 id 快照
  Set<int> _widgetIdsBeforePin = {};

  Timer? _pinVerifyTimer;
  StreamSubscription<String>? _pinSuccessSub;

  TargetPlatform get _platform =>
      widget.debugPlatformOverride ?? defaultTargetPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pinSuccessSub = getIt<WidgetUpdateService>().onWidgetPinned.listen((_) {
      _onPinConfirmed();
    });
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    _pinVerifyTimer?.cancel();
    _pinSuccessSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _pinPending) {
      _pausedSincePin = true;
    }
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimization();
      _verifyPinAfterResume();
    }
  }

  Future<void> _checkBatteryOptimization() async {
    if (_platform != TargetPlatform.android) {
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
          await service.syncWidgetShowTomorrow(v);
        } catch (e, st) {
          debugPrint('WidgetUpdate toggle failed: $e');
          debugPrint('$st');
        }
      },
    );
  }

  void _syncWidgetAppearance(AppConfigProvider appConfig) {
    unawaited(
      getIt<WidgetUpdateService>().syncWidgetAppearance(
        colorStyle: appConfig.widgetColorStyle.value,
        density: appConfig.widgetDensity.value,
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    AppLocalizations localizations,
    AppConfigProvider appConfig,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.widgetAppearanceTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localizations.widgetAppearanceDescription,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(localizations.widgetColorStyle, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<WidgetColorStyle>(
                segments: [
                  ButtonSegment(
                    value: WidgetColorStyle.colorful,
                    icon: const Icon(Icons.palette_outlined),
                    label: Text(localizations.widgetColorful),
                  ),
                  ButtonSegment(
                    value: WidgetColorStyle.monochrome,
                    icon: const Icon(Icons.tonality_outlined),
                    label: Text(localizations.widgetMonochrome),
                  ),
                ],
                selected: {appConfig.widgetColorStyle.value},
                onSelectionChanged: (selection) {
                  appConfig.widgetColorStyle.value = selection.single;
                  _syncWidgetAppearance(appConfig);
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(localizations.widgetDensity, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<WidgetDensity>(
                segments: [
                  ButtonSegment(
                    value: WidgetDensity.standard,
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: Text(localizations.widgetDensityStandard),
                  ),
                  ButtonSegment(
                    value: WidgetDensity.compact,
                    icon: const Icon(Icons.density_small_outlined),
                    label: Text(localizations.widgetDensityCompact),
                  ),
                ],
                selected: {appConfig.widgetDensity.value},
                onSelectionChanged: (selection) {
                  appConfig.widgetDensity.value = selection.single;
                  _syncWidgetAppearance(appConfig);
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations.widgetSystemAppearanceHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pinWidget(BuildContext context, WidgetSize size) async {
    final localizations = AppLocalizations.of(context)!;
    final service = getIt<WidgetUpdateService>();
    // 快照当前桌面已有的小组件 id,用于后续 diff 验证真实添加结果
    final beforeIds = await service.getPinnedWidgetIds();
    if (!context.mounted) return;
    // 注意: 返回值 true 仅表示"请求已提交",不代表用户确认添加
    // (部分 ROM 未授予「创建桌面快捷方式」权限时会静默拦截,不弹任何窗口)
    final submitted = await service.pinWidget(size.toPinArgument());
    if (!context.mounted) return;
    if (!submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.pinWidgetNotSupported)),
      );
      return;
    }
    _widgetIdsBeforePin = beforeIds;
    _pinPending = true;
    _pausedSincePin = false;
    _pinVerifyTimer?.cancel();
    _pinVerifyTimer = Timer(_pinVerifyDelay, _verifyPinResult);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizations.pinWidgetRequested)));
  }

  /// 桌面上是否出现了 pin 请求之前不存在的新小组件
  Future<bool> _hasNewWidgetOnHome() async {
    final now = await getIt<WidgetUpdateService>().getPinnedWidgetIds();
    return now.difference(_widgetIdsBeforePin).isNotEmpty;
  }

  /// 确认小组件真正添加成功(原生成功回调或 ids diff 验证通过)
  void _onPinConfirmed() {
    if (!_pinPending) return;
    _pinVerifyTimer?.cancel();
    _pinPending = false;
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizations.pinWidgetSuccess)));
    // 让新添加的小组件立刻加载课程数据
    getIt<WidgetUpdateService>().updateWidgetData(force: true);
  }

  /// pin 请求提交一段时间后的判定:
  /// - ids 增加 → 添加成功;
  /// - ids 未增加且期间应用从未 pause(系统弹窗根本没出现) → 判定被权限拦截,弹引导;
  /// - ids 未增加但 pause 过 → 弹窗已展示,交给 resume 兜底处理。
  Future<void> _verifyPinResult() async {
    if (!_pinPending) return;
    if (await _hasNewWidgetOnHome()) {
      _onPinConfirmed();
      return;
    }
    if (!mounted || !_pinPending) return;
    if (_pausedSincePin) return;
    _pinPending = false;
    _showPinBlockedDialog();
  }

  /// 从系统弹窗/设置页返回时的兜底验证:
  /// ids 增加 → 成功;否则视为用户主动取消,静默清除(不打扰)。
  Future<void> _verifyPinAfterResume() async {
    if (!_pinPending) return;
    if (await _hasNewWidgetOnHome()) {
      _onPinConfirmed();
      return;
    }
    if (!mounted || !_pinPending) return;
    if (_pausedSincePin) {
      _pinVerifyTimer?.cancel();
      _pinPending = false;
    }
  }

  void _showPinBlockedDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(localizations.pinWidgetFailedTitle),
          content: Text(localizations.pinWidgetFailedDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(localizations.pinWidgetDismiss),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                getIt<WidgetUpdateService>().openAppSettings();
              },
              child: Text(localizations.pinWidgetOpenSettings),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final isAndroid = _platform == TargetPlatform.android;
    final isApple =
        _platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS;

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.widgetShowTomorrow,
        appConfig.widgetColorStyle,
        appConfig.widgetDensity,
      ]),
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
            if (isAndroid) ...[
              BatteryOptimizationCard(
                status: _status,
                onRequestIgnore: _requestIgnoreBatteryOptimizations,
              ),
              const SizedBox(height: 16),
            ],
            if (isApple) ...[
              StyledCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.widgets_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _platform == TargetPlatform.iOS
                              ? localizations.addWidgetIosHint
                              : localizations.addWidgetMacHint,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Consolidated single card with size choices (Android only)
            if (isAndroid) _WidgetPickerCard(onPin: _pinWidget),
            if (isAndroid) const SizedBox(height: 16),
            if (_platform == TargetPlatform.iOS) ...[
              _buildAppearanceCard(context, localizations, appConfig),
              const SizedBox(height: 16),
            ],
            _buildShowTomorrowSwitch(context, localizations),
            if (isAndroid) ...[
              const SizedBox(height: 16),
              HintCard(hint: localizations.pinWidgetHint),
            ],
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
    return StyledCard(
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
