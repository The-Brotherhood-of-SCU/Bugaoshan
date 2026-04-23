import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class OcrService {
  static Interpreter? _interpreter;

  static Future<void> init() async {
    if (_interpreter != null) return;

    _interpreter = await Interpreter.fromAsset(
      'assets/universal-login-ocr.tflite',
      options: InterpreterOptions()..threads = 2,
    );
  }

  static Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
  }

  static Float32List _preprocessImage(Uint8List imageBytes) {
    // 1. Decode image
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Resize to 80x26 (Width x Height)
    final resizedImage = (decodedImage.width == 80 && decodedImage.height == 26)
        ? decodedImage
        : img.copyResize(decodedImage, width: 80, height: 26);

    // 3. Normalize: x/255.0 and reshape for TFLite model
    // The ONNX model used [1, 26, 80, 3] which the converter treated as NCHW (N=1, C=26, H=80, W=3).
    // TFLite uses NHWC, so the converted shape is [1, 80, 3, 26] (N=1, H=80, W=3, C=26).
    // We must populate the array in the order expected by TFLite: x(H), channel(W), y(C).
    final inputData = Float32List(1 * 80 * 3 * 26);
    int index = 0;
    for (int x = 0; x < 80; x++) {
      for (int c = 0; c < 3; c++) {
        for (int y = 0; y < 26; y++) {
          final pixel = resizedImage.getPixel(x, y);
          if (c == 0) {
            inputData[index++] = pixel.r / 255.0;
          } else if (c == 1) {
            inputData[index++] = pixel.g / 255.0;
          } else {
            inputData[index++] = pixel.b / 255.0;
          }
        }
      }
    }
    return inputData;
  }

  static String _decodeLogits(List<double> logits) {
    // 5. Decoding based on python code
    const charList = "0123456789abcdefghijklmnopqrstuvwxyz";
    final charLength = charList.length; // 36

    final res = StringBuffer();

    for (int i = 0; i < 4; i++) {
      int maxIndex = 0;
      double maxProb = logits[i * charLength];
      for (int j = 1; j < charLength; j++) {
        final currentProb = logits[i * charLength + j];
        if (currentProb > maxProb) {
          maxProb = currentProb;
          maxIndex = j;
        }
      }
      res.write(charList[maxIndex]);
    }

    return res.toString();
  }

  static Future<String> performOcr(Uint8List imageBytes) async {
    await init();
    if (_interpreter == null) {
      throw Exception('OCR Interpreter not initialized');
    }

    // 1. 将耗时的图像解码、预处理以及张量准备放在后台 Isolate 执行
    final tensors = await Isolate.run(() {
      final data = _preprocessImage(imageBytes);
      return {
        'input': data.reshape([1, 80, 3, 26]),
        'output': List.filled(144, 0.0).reshape([1, 144]),
      };
    });

    // 2. 在主线程进行推理
    var input = tensors['input']!;
    var output = tensors['output']!;

    _interpreter!.run(input, output);

    final logits = output[0].cast<double>();
    return _decodeLogits(logits);
  }
}
