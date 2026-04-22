import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

class OcrService {
  static OrtSession? _session;

  static Future<void> init() async {
    if (_session != null) return;

    final onnxRuntime = OnnxRuntime();
    final options = OrtSessionOptions(
      intraOpNumThreads: 2,
      interOpNumThreads: 1,
      providers: [OrtProvider.CPU],
      useArena: true,
    );

    _session = await onnxRuntime.createSessionFromAsset(
      'assets/universal-login-ocr.onnx',
      options: options,
    );
  }

  static Future<void> dispose() async {
    await _session?.close();
    _session = null;
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

    // 3. Normalize: x/255.0 and transpose to (channels, height, width) -> (3, 26, 80)
    final inputData = Float32List(1 * 26 * 80 * 3);
    int index = 0;
    for (int y = 0; y < 26; y++) {
      for (int x = 0; x < 80; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // Normalize each channel
        inputData[index++] = pixel.r / 255.0;
        inputData[index++] = pixel.g / 255.0;
        inputData[index++] = pixel.b / 255.0;
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
    if (_session == null) throw Exception('OCR Session not initialized');

    // 1. 将耗时的图像解码和预处理放在后台 Isolate 执行
    final inputData = await Isolate.run(() => _preprocessImage(imageBytes));

    // 2. 在主线程进行推理
    final inputOrt = await OrtValue.fromList(inputData, [1, 26, 80, 3]);
    Map<String, OrtValue>? outputs;

    try {
      final inputNames = _session!.inputNames;
      final inputName = inputNames.isNotEmpty ? inputNames[0] : 'input';

      outputs = await _session!.run({inputName: inputOrt});

      final outputNames = _session!.outputNames;
      final outputName = outputNames.isNotEmpty ? outputNames[0] : 'output';
      final outputOrt = outputs[outputName];

      if (outputOrt == null) {
        throw Exception('Invalid output from OCR model');
      }

      final logits = (await outputOrt.asFlattenedList()).cast<double>();
      return _decodeLogits(logits);
    } finally {
      // 仅释放每次推理产生的临时张量，Session 被保留
      await inputOrt.dispose();
      if (outputs != null) {
        for (final tensor in outputs.values) {
          await tensor.dispose();
        }
      }
    }
  }
}
