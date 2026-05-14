import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowStateService with WindowListener {
  static const String _keyX = 'window_x';
  static const String _keyY = 'window_y';
  static const String _keyW = 'window_w';
  static const String _keyH = 'window_h';

  final SharedPreferences _prefs;
  Timer? _debounce;

  WindowStateService(this._prefs);

  static Future<WindowStateService> create(SharedPreferences prefs) async {
    final service = WindowStateService(prefs);

    await windowManager.ensureInitialized();

    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    final w = prefs.getDouble(_keyW);
    final h = prefs.getDouble(_keyH);
    final size = w != null && h != null ? Size(w, h) : null;
    final position = x != null && y != null ? Offset(x, y) : null;

    // Validate saved position against current screen layout.
    // If the display configuration changed (resolution lowered, monitor
    // unplugged), the window could appear off-screen.
    final validPosition = position != null &&
        size != null &&
        await _isPositionOnScreen(position, size);

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: size,
        center: !validPosition,
        minimumSize: const Size(400, 400),
      ),
    );

    if (validPosition) {
      await windowManager.setPosition(position);
    }

    windowManager.addListener(service);
    await windowManager.show();
    return service;
  }

  /// Returns true if at least a significant portion of the window is visible
  /// on any connected display. Uses [screenRetriever] to get per-display
  /// positions from native APIs, correctly handling multi-monitor setups
  /// and resolution changes.
  static Future<bool> _isPositionOnScreen(Offset pos, Size size) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) return true;

      final windowRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
      for (final display in displays) {
        final screenRect = Rect.fromLTWH(
          display.visiblePosition?.dx ?? 0,
          display.visiblePosition?.dy ?? 0,
          display.visibleSize?.width ?? display.size.width,
          display.visibleSize?.height ?? display.size.height,
        );
        final intersection = screenRect.intersect(windowRect);
        if (intersection.width > 100 && intersection.height > 50) {
          return true;
        }
      }
      return false;
    } catch (_) {
      // If screen_retriever fails, accept the saved position.
      return true;
    }
  }

  void _save() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await _prefs.setDouble(_keyX, pos.dx);
      await _prefs.setDouble(_keyY, pos.dy);
      await _prefs.setDouble(_keyW, size.width);
      await _prefs.setDouble(_keyH, size.height);
    });
  }

  @override
  void onWindowMoved() => _save();

  @override
  void onWindowResized() => _save();
}
