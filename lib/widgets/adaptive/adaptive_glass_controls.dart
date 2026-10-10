import 'dart:async';
import 'dart:math' as math;

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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
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

/// iOS 26+ 原生玻璃按钮，其余环境保留调用方提供的 Material 按钮。
///
/// [fallback] 同时用于测量尺寸，调用方应为其提供相同的动作和禁用状态。
class AdaptiveGlassButton extends StatelessWidget {
  const AdaptiveGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.fallback,
    this.symbol,
    this.prominent = false,
    this.tint,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget fallback;
  final String? symbol;
  final bool prominent;
  final Color? tint;
  final bool loading;

  @override
  Widget build(BuildContext context) => _AdaptiveGlassControl(
    kind: _GlassControlKind.button,
    label: label,
    symbol: symbol,
    value: false,
    enabled: onPressed != null,
    loading: loading,
    prominent: prominent,
    tint: tint,
    onActivate: onPressed,
    fallback: ExcludeFocus(
      excluding: onPressed == null || loading,
      child: IgnorePointer(
        ignoring: onPressed == null || loading,
        child: fallback,
      ),
    ),
  );
}

/// iOS 原生 UISwitch；选中值和回调始终由 Flutter 的当前状态提供。
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

enum _GlassControlKind { button, toggle }

class _AdaptiveGlassControl extends StatefulWidget {
  const _AdaptiveGlassControl({
    required this.kind,
    required this.label,
    required this.value,
    required this.enabled,
    required this.fallback,
    this.symbol,
    this.loading = false,
    this.prominent = false,
    this.tint,
    this.onActivate,
    this.onChanged,
    this.nativeBuilder,
  });

  final _GlassControlKind kind;
  final String label;
  final String? symbol;
  final bool value;
  final bool enabled;
  final bool loading;
  final bool prominent;
  final Color? tint;
  final VoidCallback? onActivate;
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
    _scheduleUpdate();
  }

  double get _textScale =>
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

  BoxConstraints _buttonConstraints() {
    // UIKit 按钮使用 17pt semibold，不能只依赖 Material 的 14pt 度量。
    // 这些最小值补齐原生内容空间，fallback 仍可要求更大的布局尺寸。
    final labelPainter = TextPainter(
      text: TextSpan(
        text: widget.label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(_textScale),
      maxLines: 1,
    )..layout();
    final iconSpace = widget.symbol != null || widget.loading ? 32.0 : 0.0;
    final constraints = BoxConstraints(
      minWidth: math
          .max(44, labelPainter.width + iconSpace + 24)
          .ceilToDouble(),
      minHeight: math
          .max(44, math.max(17 * _textScale, labelPainter.height) + 16)
          .ceilToDouble(),
    );
    labelPainter.dispose();
    return constraints;
  }

  Map<String, Object> _parameters() {
    final theme = Theme.of(context);
    return {
      'kind': widget.kind == _GlassControlKind.button ? 'button' : 'switch',
      'label': widget.label,
      if (widget.symbol != null) 'symbol': widget.symbol!,
      'value': widget.value,
      'enabled': widget.enabled && !widget.loading,
      'loading': widget.loading,
      'style': widget.prominent ? 'prominent' : 'regular',
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
    if (!mounted || !_supported || !widget.enabled || widget.loading) return;
    if (widget.kind == _GlassControlKind.button &&
        call.method == 'activate' &&
        call.arguments == null) {
      widget.onActivate?.call();
    } else if (widget.kind == _GlassControlKind.toggle &&
        call.method == 'change' &&
        call.arguments is bool &&
        call.arguments != widget.value) {
      widget.onChanged?.call(call.arguments as bool);
      // Flutter 是受控值的来源，回调未接受新值时也恢复原生开关状态。
      _scheduleUpdate();
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

    final nativeView = UiKitView(
      viewType: _viewType,
      layoutDirection: Directionality.of(context),
      creationParams: _parameters(),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
      // 控件区域内的点击交给 UIKit，避免父 ListTile 同时翻转开关。
      // 纵向拖动仍参与外层 Flutter 列表的手势竞争。
      gestureRecognizers: {
        Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        if (widget.kind == _GlassControlKind.toggle)
          Factory<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
          ),
      },
    );
    final Widget control;
    if (widget.kind == _GlassControlKind.toggle) {
      control = SizedBox(width: 64, height: 44, child: nativeView);
    } else {
      control = ConstrainedBox(
        constraints: _buttonConstraints(),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 隐藏的 Flutter 按钮只负责尺寸；其 Opacity 与原生视图是兄弟。
            // 不能把 Opacity、Clip 或重复语义节点放到原生材质的祖先上。
            ExcludeFocus(
              child: ExcludeSemantics(
                child: Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: widget.fallback,
                ),
              ),
            ),
            Positioned.fill(child: nativeView),
          ],
        ),
      );
    }
    return widget.nativeBuilder?.call(context, control) ?? control;
  }
}
