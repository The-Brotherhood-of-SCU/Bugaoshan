import 'dart:async';
import 'dart:ui';
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

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: w != null && h != null ? Size(w, h) : null,
        center: x == null || y == null,
        minimumSize: const Size(800, 600),
      ),
    );

    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }

    windowManager.addListener(service);
    await windowManager.show();
    return service;
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
