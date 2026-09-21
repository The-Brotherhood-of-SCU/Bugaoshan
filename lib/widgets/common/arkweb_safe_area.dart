import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bugaoshan/services/arkweb/viewport_metrics.dart';

/// 背景继续铺满窗口，仅向 SafeArea / AppBar / NavigationBar 提供避让尺寸。
class ArkWebSafeArea extends StatefulWidget {
  const ArkWebSafeArea({super.key, required this.child});

  final Widget child;

  @override
  State<ArkWebSafeArea> createState() => _ArkWebSafeAreaState();
}

class _ArkWebSafeAreaState extends State<ArkWebSafeArea> {
  Brightness? _lastBrightness;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ArkWebViewportMetrics?>(
      valueListenable: arkWebViewportMetrics,
      child: widget.child,
      builder: (context, metrics, child) {
        // 非 ArkWeb 平台，以及尚未提供 viewport 能力的旧容器，沿用原有布局。
        if (metrics == null) return child!;
        final brightness = Theme.of(context).brightness;
        if (_lastBrightness != brightness) {
          _lastBrightness = brightness;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(setArkWebSystemBarBrightness(brightness));
            }
          });
        }
        return MediaQuery(
          data: metrics.applyTo(MediaQuery.of(context)),
          child: child!,
        );
      },
    );
  }
}
