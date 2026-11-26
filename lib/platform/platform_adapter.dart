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

  Future<int?> getOhosApiVersion() async => null;

  /// 当前宿主是否提供原生控件（iOS/macOS 的 UIKit/AppKit 平台视图，OHOS 的 CPF 平台视图）。
  bool get supportsNativeControls =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// 当前宿主是否为指定种类提供原生实现。
  ///
  /// [kind] 与创建参数里的 `kind` 字段一致（`switch` / `slider`）。
  bool supportsNativeControlKind(String kind) => supportsNativeControls;

  /// 原生开关的可视高度；各宿主原生控件尺寸不同，由适配器统一给出。
  double get nativeControlToggleHeight => 44;

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
    if (!await Gal.requestPermission()) {
      throw GalException(
        type: GalExceptionType.permissionDenied,
        platformException: PlatformException(code: 'PERMISSION_DENIED'),
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

  /// 按宿主平台创建原生控件。
  ///
  /// 调用方应先用 [supportsNativeControls] / [supportsNativeControlKind] 判断能力；
  /// 不支持的宿主会抛 [UnsupportedError]。
  Widget createNativeControl({
    required String viewType,
    required TextDirection layoutDirection,
    required Map<String, Object> creationParams,
    required ValueChanged<int> onPlatformViewCreated,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) {
    const creationParamsCodec = StandardMessageCodec();
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        // macOS 沿用既有行为：不注入外部手势识别器。
        return AppKitView(
          viewType: viewType,
          layoutDirection: layoutDirection,
          creationParams: creationParams,
          creationParamsCodec: creationParamsCodec,
          onPlatformViewCreated: onPlatformViewCreated,
        );
      case TargetPlatform.iOS:
        // 控件区域内的点击交给 UIKit，避免父 ListTile 同时翻转开关。
        return UiKitView(
          viewType: viewType,
          layoutDirection: layoutDirection,
          creationParams: creationParams,
          creationParamsCodec: creationParamsCodec,
          onPlatformViewCreated: onPlatformViewCreated,
          gestureRecognizers: gestureRecognizers,
        );
      default:
        throw UnsupportedError('This host has no additional native controls.');
    }
  }
}
