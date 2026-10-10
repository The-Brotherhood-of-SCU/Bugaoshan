import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:scu_ocr_lite/scu_ocr_lite.dart' as ocr_lite;

/// 本地验证码 OCR。
///
/// scu_ocr_lite 的推理依赖 dart:isolate，Web 端运行时不受支持
/// （`Unsupported operation: dart:isolate is not supported`），
/// 因此 [isSupported] 在 Web 上恒为 false；调用方应先检查该标志再使用，
/// 未检查的调用会收到带说明的 [UnsupportedError] 而不是晦涩的底层报错。
class OcrService {
  static ocr_lite.OcrService? _instance;
  static Future<void>? _initFuture;

  /// 当前平台是否支持本地 OCR（Web 端不支持，验证码需手动输入）。
  static bool get isSupported => !kIsWeb;

  static Future<void> init() {
    if (!isSupported) {
      return Future.error(
        UnsupportedError('OcrService: Web 端不支持本地 OCR，已跳过初始化'),
      );
    }
    return _initFuture ??= _doInit();
  }

  static Future<void> _doInit() async {
    if (_instance != null) return;
    final service = ocr_lite.OcrService();
    final data = await rootBundle.load(
      'packages/scu_ocr_lite/assets/model.scuocr',
    );
    await service.initializeFromBytes(data.buffer.asUint8List());
    _instance = service;
  }

  static Future<void> dispose() async {
    _instance = null;
    _initFuture = null;
  }

  static Future<String> performOcr(Uint8List imageBytes) async {
    if (!isSupported) {
      throw UnsupportedError('OcrService: Web 端不支持本地 OCR，请手动输入验证码');
    }
    await init();
    return _instance!.recognizeAsync(imageBytes);
  }
}
