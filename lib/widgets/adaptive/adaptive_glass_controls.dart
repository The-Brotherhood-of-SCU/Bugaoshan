import 'dart:async';

import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 所有自适应控件共用一次能力查询，包括同时创建的设置列表项。
class LiquidGlassCapabilities {
  LiquidGlassCapabilities._();

  static const _channel = MethodChannel('bugaoshan/liquid_glass');
  static Future<bool>? _supported;

  static Future<bool> isSupported() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return SynchronousFuture(false);
    }
    return _supported ??= _checkSupport();
  }

  static Future<bool> _checkSupport() async {
    try {
      return await _channel
              .invokeMethod<bool>('isSupported')
              .timeout(const Duration(seconds: 2)) ==
          true;
    } catch (error) {
      AppLog.w('AdaptiveGlassControl', 'Native glass unavailable: $error');
      return false;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _supported = null;
  }
}

/// Apple 原生开关；选中值和回调始终由 Flutter 的当前状态提供。
class AdaptiveGlassSwitch extends StatelessWidget {
  const AdaptiveGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => _AdaptiveGlassControl(
    kind: _GlassControlKind.toggle,
    label: semanticLabel,
    value: value,
    enabled: onChanged != null,
    tint: activeColor,
    onChanged: onChanged,
    fallback: Semantics(
      label: semanticLabel,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeColor,
      ),
    ),
  );
}

/// 原生开关与 Flutter ListTile 配对，旧平台保留 SwitchListTile 行为。
class AdaptiveGlassSwitchListTile extends StatelessWidget {
  const AdaptiveGlassSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.semanticLabel,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final ListTileControlAffinity controlAffinity;
  final String? semanticLabel;
  final Color? activeColor;

  String get _label {
    if (semanticLabel != null) return semanticLabel!;
    final title = this.title;
    if (title is Text) {
      return title.semanticsLabel ??
          title.data ??
          title.textSpan?.toPlainText() ??
          '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => _AdaptiveGlassControl(
    kind: _GlassControlKind.toggle,
    label: _label,
    value: value,
    enabled: onChanged != null,
    tint: activeColor,
    onChanged: onChanged,
    fallback: SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      contentPadding: contentPadding,
      dense: dense,
      controlAffinity: controlAffinity,
      activeThumbColor: activeColor,
    ),
    nativeBuilder: (context, control) {
      final affinity = controlAffinity == ListTileControlAffinity.platform
          ? ListTileTheme.of(context).controlAffinity ??
                ListTileControlAffinity.trailing
          : controlAffinity;
      final leading = affinity == ListTileControlAffinity.leading;
      return ListTile(
        title: title,
        subtitle: subtitle,
        leading: leading ? control : secondary,
        trailing: leading ? secondary : control,
        contentPadding: contentPadding,
        dense: dense,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged!(!value),
      );
    },
  );
}

/// 系统滑块自行处理玻璃拇指、刻度吸附与拖动动效；Flutter 管理业务值。
class AdaptiveGlassSlider extends StatelessWidget {
  const AdaptiveGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final String semanticLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) => _AdaptiveGlassControl(
    kind: _GlassControlKind.slider,
    label: semanticLabel,
    value: value,
    min: min,
    max: max,
    divisions: divisions,
    valueLabel: label,
    enabled: onChanged != null && max > min,
    tint: activeColor,
    inactiveColor: inactiveColor,
    onSliderChanged: onChanged,
    onChangeStart: onChangeStart,
    onChangeEnd: onChangeEnd,
    fallback: Semantics(
      label: semanticLabel,
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
      ),
    ),
  );
}

enum _GlassControlKind { toggle, slider }

class _AdaptiveGlassControl extends StatefulWidget {
  const _AdaptiveGlassControl({
    required this.kind,
    required this.label,
    required this.value,
    required this.enabled,
    required this.fallback,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.valueLabel,
    this.inactiveColor,
    this.onSliderChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.tint,
    this.onChanged,
    this.nativeBuilder,
  });

  final _GlassControlKind kind;
  final String label;
  final Object value;
  final double min;
  final double max;
  final int? divisions;
  final String? valueLabel;
  final Color? inactiveColor;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;
  final Color? tint;
  final ValueChanged<bool>? onChanged;
  final Widget fallback;
  final Widget Function(BuildContext context, Widget control)? nativeBuilder;

  @override
  State<_AdaptiveGlassControl> createState() => _AdaptiveGlassControlState();
}

class _AdaptiveGlassControlState extends State<_AdaptiveGlassControl> {
  static const _viewType = 'bugaoshan/liquid_glass_control';
  bool _supported = false;
  bool _updateScheduled = false;
  bool _sliderEditing = false;
  MethodChannel? _viewChannel;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSupport());
  }

  Future<void> _checkSupport() async {
    final supported = await LiquidGlassCapabilities.isSupported();
    if (mounted && supported) setState(() => _supported = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveGlassControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.kind != oldWidget.kind) {
      _sliderEditing = false;
    }
    _scheduleUpdate();
  }

  double get _textScale =>
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

  Map<String, Object> _parameters() {
    final theme = Theme.of(context);
    return {
      'kind': widget.kind == _GlassControlKind.slider ? 'slider' : 'switch',
      'label': widget.label,
      'value': widget.value,
      'enabled': widget.enabled,
      if (widget.kind == _GlassControlKind.slider) ...{
        'min': widget.min,
        'max': widget.max,
        if (widget.divisions != null) 'divisions': widget.divisions!,
        if (widget.valueLabel != null) 'valueLabel': widget.valueLabel!,
        if (widget.inactiveColor != null)
          'inactiveTint': widget.inactiveColor!.toARGB32(),
      },
      'tint': (widget.tint ?? theme.colorScheme.primary).toARGB32(),
      'brightness': theme.brightness.name,
      'reduceMotion': MediaQuery.disableAnimationsOf(context),
      'highContrast': MediaQuery.highContrastOf(context),
      'textScale': _textScale,
      'direction': Directionality.of(context).name,
    };
  }

  void _onPlatformViewCreated(int id) {
    if (!mounted || !_supported) return;
    _viewChannel?.setMethodCallHandler(null);
    _viewChannel = MethodChannel('$_viewType/$id')
      ..setMethodCallHandler(_handleNativeCall);
    // 创建期间 Flutter 状态可能已变化，立即同步当前完整配置。
    _scheduleUpdate();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (!mounted || !_supported || !widget.enabled) return;
    if (widget.kind == _GlassControlKind.toggle &&
        call.method == 'change' &&
        call.arguments is bool &&
        call.arguments != widget.value) {
      widget.onChanged?.call(call.arguments as bool);
      _scheduleUpdate();
    } else if (widget.kind == _GlassControlKind.slider &&
        call.arguments is num) {
      final raw = (call.arguments as num).toDouble();
      if (!raw.isFinite ||
          raw < widget.min - 0.0001 ||
          raw > widget.max + 0.0001) {
        return;
      }
      var value = raw.clamp(widget.min, widget.max);
      final divisions = widget.divisions;
      if (divisions != null && widget.max > widget.min) {
        value =
            widget.min +
            ((value - widget.min) / (widget.max - widget.min) * divisions)
                    .round() *
                (widget.max - widget.min) /
                divisions;
      }
      switch (call.method) {
        case 'changeStart':
          if (!_sliderEditing) {
            _sliderEditing = true;
            widget.onChangeStart?.call(value);
          }
        case 'change':
          if ((value - (widget.value as double)).abs() > 0.000001) {
            widget.onSliderChanged?.call(value);
          }
          _scheduleUpdate();
        case 'changeEnd':
          if (_sliderEditing) {
            _sliderEditing = false;
            widget.onChangeEnd?.call(value);
            _scheduleUpdate();
          }
      }
    }
  }

  void _scheduleUpdate() {
    if (_viewChannel == null || _updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted && _supported) unawaited(_updateNative());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _updateNative() async {
    final channel = _viewChannel;
    if (channel == null) return;
    try {
      await channel
          .invokeMethod<void>('update', _parameters())
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      AppLog.w('AdaptiveGlassControl', 'Native control update failed: $error');
      if (mounted && identical(channel, _viewChannel)) {
        channel.setMethodCallHandler(null);
        _viewChannel = null;
        setState(() => _supported = false);
      }
    }
  }

  @override
  void dispose() {
    _viewChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return widget.fallback;

    final nativeView = defaultTargetPlatform == TargetPlatform.macOS
        ? AppKitView(
            viewType: _viewType,
            layoutDirection: Directionality.of(context),
            creationParams: _parameters(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : UiKitView(
            viewType: _viewType,
            layoutDirection: Directionality.of(context),
            creationParams: _parameters(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
            // 控件区域内的点击交给 UIKit，避免父 ListTile 同时翻转开关。
            // 纵向拖动仍参与外层 Flutter 列表的手势竞争。
            gestureRecognizers: {
              Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
              Factory<HorizontalDragGestureRecognizer>(
                HorizontalDragGestureRecognizer.new,
              ),
            },
          );
    final control = widget.kind == _GlassControlKind.toggle
        ? SizedBox(width: 64, height: 44, child: nativeView)
        : SizedBox(
            height: 48,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: nativeView,
            ),
          );
    return widget.nativeBuilder?.call(context, control) ?? control;
  }
}
