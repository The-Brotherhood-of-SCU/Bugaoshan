import 'package:flutter/services.dart';

/// Service for switching app icons at runtime.
///
/// Uses a custom MethodChannel [bugaoshan/dynamic_icon] to communicate with
/// the Android native implementation in [MainActivity.kt].
///
/// This replaces the [dynamic_app_icon_flutter_plus] package with a
/// lightweight implementation that correctly handles the namespace vs
/// applicationId mismatch (debug builds add a .debug suffix to applicationId
/// but component class names resolve from the Gradle namespace).
class DynamicIconService {
  static const MethodChannel _channel = MethodChannel('bugaoshan/dynamic_icon');

  /// Returns the list of available alternate icon names.
  static Future<List<String>> getAvailableIcons() async {
    final list = await _channel.invokeMethod<List<dynamic>>(
      'getAvailableIcons',
    );
    return list?.cast<String>() ?? [];
  }

  /// Returns the currently active alternate icon name, or `null` for the default icon.
  static Future<String?> getCurrentIconName() async {
    return await _channel.invokeMethod<String?>('getCurrentIconName');
  }

  /// Switch to the given [iconName], or restore the default icon if `null`.
  static Future<void> setAlternateIconName(String? iconName) async {
    await _channel.invokeMethod('setAlternateIconName', {'iconName': iconName});
  }
}
