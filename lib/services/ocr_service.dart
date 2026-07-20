import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:scu_ocr_lite/scu_ocr_lite.dart' as ocr_lite;

class OcrService {
  static ocr_lite.OcrService? _instance;

  static Future<void> init() async {
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
  }

  static Future<String> performOcr(Uint8List imageBytes) async {
    await init();
    return _instance!.recognizeAsync(imageBytes);
  }
}
