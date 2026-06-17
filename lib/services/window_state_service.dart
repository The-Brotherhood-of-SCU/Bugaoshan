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
    Offset? clampedPosition;
    if (position != null && size != null) {
      clampedPosition = await _clampToScreen(position, size);
    }

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: size,
        center: clampedPosition == null,
        minimumSize: const Size(300, 300),
      ),
    );

    if (clampedPosition != null) {
      await windowManager.setPosition(clampedPosition);
    }

    windowManager.addListener(service);
    await windowManager.show();
    return service;
  }

  /// Returns the original [pos] if the window is already on-screen, or a
  /// clamped position that keeps the window inside the nearest display.
  /// Returns `null` if screen info is unavailable (caller should center).
  static Future<Offset?> _clampToScreen(Offset pos, Size size) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isEmpty) return pos;

      final windowRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

      // Already mostly visible on any display — keep as-is.
      for (final display in displays) {
        final screenRect = _displayRect(display);
        final intersection = screenRect.intersect(windowRect);
        if (intersection.width > 100 && intersection.height > 50) {
          return pos;
        }
      }

      // Off-screen or barely visible: pick the best target display.
      // Prefer the display with the largest overlap (handles the case where
      // the window slid slightly off the edge of its original display).
      // Fall back to the display whose center is closest.
      final windowCenter = windowRect.center;
      Display? best;
      double bestArea = 0;
      Display? fallback;
      double fallbackDist = double.infinity;
      for (final display in displays) {
        final screenRect = _displayRect(display);
        final intersection = screenRect.intersect(windowRect);
        final area = intersection.isEmpty
            ? 0.0
            : intersection.width * intersection.height;
        if (area > bestArea) {
          bestArea = area;
          best = display;
        }
        final dist = (screenRect.center - windowCenter).distance;
        if (dist < fallbackDist) {
          fallbackDist = dist;
          fallback = display;
        }
      }
      final target = best ?? fallback;
      if (target == null) return pos;

      final screen = _displayRect(target);
      // If the window is larger than the screen, pin to screen origin.
      final maxX = screen.right - size.width;
      final maxY = screen.bottom - size.height;
      final clampedX = maxX >= screen.left
          ? pos.dx.clamp(screen.left, maxX)
          : screen.left;
      final clampedY = maxY >= screen.top
          ? pos.dy.clamp(screen.top, maxY)
          : screen.top;
      return Offset(clampedX, clampedY);
    } catch (_) {
      // If screen_retriever fails, accept the saved position.
      return pos;
    }
  }

  static Rect _displayRect(Display display) {
    return Rect.fromLTWH(
      display.visiblePosition?.dx ?? 0,
      display.visiblePosition?.dy ?? 0,
      display.visibleSize?.width ?? display.size.width,
      display.visibleSize?.height ?? display.size.height,
    );
  }

  void _save() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _saveNow);
  }

  Future<void> _saveNow() async {
    try {
      final pos = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await _prefs.setDouble(_keyX, pos.dx);
      await _prefs.setDouble(_keyY, pos.dy);
      await _prefs.setDouble(_keyW, size.width);
      await _prefs.setDouble(_keyH, size.height);
    } catch (_) {
      // Best-effort save.
    }
  }

  @override
  void onWindowClose() {
    _debounce?.cancel();
    _saveNow();
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }

  @override
  void onWindowMoved() => _save();

  @override
  void onWindowResized() => _save();
}
