import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';

class SelectedFile {
  const SelectedFile({required this.name, required this.path});

  final String name;
  final String? path;
}

/// 标准 Flutter 的默认实现。其他宿主在调用共享 main 前注入适配器，
/// 共享源码无需导入宿主专有插件，也无需为此修改上游 Pub 清单和锁。
class PlatformAdapter {
  static PlatformAdapter instance = PlatformAdapter();

  bool get isOhos => false;

  bool get supportsNativeControls => false;

  Future<OpenResult> openFile(String path) => OpenFilex.open(path);

  Future<List<SelectedFile>> pickFiles({
    required List<String> allowedExtensions,
  }) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    return files
        .map((file) => SelectedFile(name: file.name, path: file.path))
        .toList();
  }

  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (kIsWeb) return {};
    final deviceInfo = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await deviceInfo.androidInfo;
      return {
        'brand': info.brand,
        'model': info.model,
        'device': info.device,
        'manufacturer': info.manufacturer,
        'supported32BitAbis': info.supported32BitAbis.join(', '),
        'supported64BitAbis': info.supported64BitAbis.join(', '),
        'supportedAbis': info.supportedAbis.join(', '),
        'isPhysicalDevice': info.isPhysicalDevice.toString(),
      };
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final info = await deviceInfo.iosInfo;
      return {
        'name': info.name,
        'model': info.model,
        'localizedModel': info.localizedModel,
        'systemName': info.systemName,
        'systemVersion': info.systemVersion,
        'isPhysicalDevice': info.isPhysicalDevice.toString(),
      };
    }
    return {};
  }

  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) => FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    dialogTitle: dialogTitle,
  );

  /// false 表示取消；权限拒绝保持 Gal 的异常语义。
  Future<bool> saveImage(Uint8List bytes, {String? name}) async {
    if (!await Gal.requestAccess()) {
      throw GalException(
        type: GalExceptionType.accessDenied,
        platformException: PlatformException(code: 'ACCESS_DENIED'),
        stackTrace: StackTrace.current,
      );
    }
    if (name == null) {
      await Gal.putImageBytes(bytes);
    } else {
      await Gal.putImageBytes(bytes, name: name);
    }
    return true;
  }

  Widget createNativeControl({
    required String viewType,
    required TextDirection layoutDirection,
    required Map<String, Object> creationParams,
    required ValueChanged<int> onPlatformViewCreated,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) => throw UnsupportedError('This host has no additional native controls.');
}
