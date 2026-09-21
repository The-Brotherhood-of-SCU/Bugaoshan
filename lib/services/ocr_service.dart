import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:scu_ocr_lite/scu_ocr_lite.dart' as ocr_lite;

class OcrService {
  static ocr_lite.OcrService? _instance;
  static Future<void>? _initFuture;

  static Future<void> init() {
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
    await init();
    // 依赖库的 recognizeAsync 使用 Isolate.run，Flutter Web 不支持。
    // Web 复用同一份本地模型直接识别，原生平台仍在 isolate 中执行。
    if (kIsWeb) return _instance!.recognize(imageBytes);
    return _instance!.recognizeAsync(imageBytes);
  }
}
