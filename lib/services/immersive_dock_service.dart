import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 底栏标签项（与 ArkTS 侧 DockTabInfo 字段对齐）
class DockTabInfo {
  final String id;
  final String label;
  final String icon;
  final bool badge;

  const DockTabInfo({
    required this.id,
    required this.label,
    required this.icon,
    this.badge = false,
  });

  Map<String, Object> toMap() => {
    'id': id,
    'label': label,
    'icon': icon,
    'badge': badge,
  };
}

/// 悬浮底栏占位扩展：读取 app 层 MediaQuery 注入的底栏占位高度
/// （padding.bottom 超出系统 viewPadding.bottom 的部分即底栏占位）。
/// 显式设置 padding 的滚动视图可叠加此值，实现「内容可延伸到底栏下方，
/// 滚动到底时停留在底栏上方」的限位效果；底栏隐藏时自动为 0。
extension ImmersiveDockInset on BuildContext {
  double get immersiveDockInset {
    final mq = MediaQuery.of(this);
    return (mq.padding.bottom - mq.viewPadding.bottom).clamp(
      0.0,
      double.infinity,
    );
  }
}

/// 原生沉浸光感悬浮底栏桥接（系统级，Dart 侧统一收口）。
///
/// 仅在 HarmonyOS（ohos）平台生效：把底栏配置（标签、选中态、材质参数）
/// 推送给 ArkUI 侧的 NativeImmersiveDock（系统级 ImmersiveMaterial 材质），
/// 并接收原生底栏的点击事件切换页面。
///
/// 系统级行为（与具体页面 UI 解耦）：
/// - [routeObserver] 挂在 MaterialApp.navigatorObservers 上，首页被二级
///   页面覆盖时自动隐藏底栏，返回后自动恢复（见 [setCovered]）。
/// - [dockVisible] 全局通知底栏当前是否可见，app 层据此为滚动内容增加
///   底部限位（内容可滚到底栏上方，不会被遮挡）。
/// - 推送带内容去重：配置未变化时不走平台通道，避免点击切换时的卡顿。
class ImmersiveDockService {
  ImmersiveDockService._();

  static final ImmersiveDockService instance = ImmersiveDockService._();
  static const MethodChannel _channel = MethodChannel('bugaoshan/immersive_dock');

  /// 底栏可见时给滚动内容预留的底部限位高度（逻辑像素，
  /// 对应 ArkUI 侧底栏 64vp + 底部间距 26vp）
  static const double dockBottomSpace = 96;

  /// 全局路由监听：注册到 MaterialApp.navigatorObservers，
  /// 首页（RouteAware）据此感知二级页面覆盖
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// 原生底栏当前是否可见（启用且未被二级页面覆盖）
  final ValueNotifier<bool> dockVisible = ValueNotifier(false);

  /// 是否为 HarmonyOS 平台
  static bool get isOhos => !kIsWeb && Platform.operatingSystem == 'ohos';

  /// 原生底栏点击回调（参数为标签下标），首页使用
  void Function(int index)? onDockTap;

  /// 页面级覆盖激活时的点击回调（二级页面自己的底栏），优先于 [onDockTap]
  void Function(int index)? onOverrideTap;

  bool _initialized = false;
  bool _covered = false;
  Map<String, Object>? _pendingArgs;
  String? _lastPayload;

  /// 页面级底栏覆盖：二级页面接管原生胶囊底栏时推送的标签配置。
  /// 非 null 时原生侧继续显示胶囊（covered 被压为 false），
  /// 但渲染的是页面自己的标签组。
  List<DockTabInfo>? _overrideTabs;
  int _overrideSelected = 0;

  Future<void> init() async {
    if (!isOhos || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDockTap' && call.arguments is int) {
        final index = call.arguments as int;
        if (_overrideTabs != null) {
          onOverrideTap?.call(index);
        } else {
          onDockTap?.call(index);
        }
      }
    });
  }

  /// 推送底栏配置到原生侧（自动去重，相同配置不重复走通道）
  Future<void> sync({
    required bool enabled,
    required List<DockTabInfo> tabs,
    required int selectedIndex,
    required int style,
    required bool colorInvert,
    required bool interactive,
  }) async {
    if (!isOhos) return;
    await init();
    _pendingArgs = {
      'enabled': enabled,
      'tabs': tabs.map((t) => t.toMap()).toList(),
      'selectedIndex': selectedIndex,
      'style': style,
      'colorInvert': colorInvert,
      'interactive': interactive,
    };
    await _push();
  }

  /// 首页是否被二级页面覆盖：覆盖时隐藏底栏，恢复时按缓存配置重新显示
  void setCovered(bool covered) {
    if (!isOhos || _covered == covered) return;
    _covered = covered;
    _lastPayload = null; // 强制重推
    _push();
  }

  /// 二级页面接管原生沉浸光感胶囊底栏：推送页面自己的标签配置，
  /// 原生胶囊（系统级 ImmersiveMaterial 材质）保持显示并渲染这套标签。
  /// 材质参数（style/colorInvert/interactive）沿用首页设置页的全局配置。
  /// 返回首页前调用 [clearOverride] 恢复。
  Future<void> overrideDock({
    required List<DockTabInfo> tabs,
    required int selectedIndex,
  }) async {
    if (!isOhos) return;
    await init();
    _overrideTabs = tabs;
    _overrideSelected = selectedIndex;
    // 极端情况下首页尚未 sync 过（深链直达二级页），补一份默认基座配置
    _pendingArgs ??= {
      'enabled': true,
      'tabs': const <Object>[],
      'selectedIndex': 0,
      'style': 2,
      'colorInvert': true,
      'interactive': true,
    };
    await _push();
  }

  /// 清除页面级覆盖，恢复首页底栏配置
  void clearOverride() {
    if (!isOhos || _overrideTabs == null) return;
    _overrideTabs = null;
    onOverrideTap = null;
    _push();
  }

  Future<void> _push() async {
    final args = _pendingArgs;
    if (args == null) return;
    final baseTabs = args['tabs']! as List<Object>;
    final enabled = args['enabled']! as bool &&
        (baseTabs.isNotEmpty || _overrideTabs != null);
    final overridden = _overrideTabs != null;
    final effective = <String, Object>{
      ...args,
      'tabs': overridden
          ? _overrideTabs!.map((t) => t.toMap()).toList()
          : baseTabs,
      'selectedIndex': overridden ? _overrideSelected : args['selectedIndex']!,
      'enabled': enabled,
      // 页面级覆盖时胶囊继续显示页面的标签组，不受 covered 隐藏影响
      'covered': overridden ? false : _covered,
    };
    final payload = jsonEncode(effective);
    // dockVisible 只表达「首页底栏可见」：页面级覆盖时仍视为不可见，
    // 避免 app 层底部限位与页面自己的限位重复注入
    dockVisible.value = enabled && !_covered && !overridden;
    if (payload == _lastPayload) return;
    _lastPayload = payload;
    try {
      await _channel.invokeMethod('updateDock', effective);
    } catch (e) {
      debugPrint('ImmersiveDockService.sync error: $e');
    }
  }
}
