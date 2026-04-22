import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

class OcrService {
  static OrtSession? _session;

  static Future<void> init() async {
    if (_session != null) return;
    try {
      final onnxRuntime = OnnxRuntime();
      _session = await onnxRuntime.createSessionFromAsset(
        'assets/universal-login-ocr.onnx',
      );
    } catch (e) {
      // Ignore print in production, but helpful for debugging
    }
  }

  static Future<String> performOcr(Uint8List imageBytes) async {
    await init();
    if (_session == null) {
      throw Exception('OCR Session not initialized');
    }

    // 1. Decode image
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Resize to 80x26 (Width x Height) - No grayscale conversion based on python code
    final resizedImage = img.copyResize(decodedImage, width: 80, height: 26);

    // 3. Normalize: x/255.0 and transpose to (channels, height, width) -> (3, 26, 80)
    // The python code does: (2, 0, 1) -> (1, 2, 0) which effectively means the shape is
    // [height, width, channels] -> [channels, height, width] -> [width, channels, height] ?
    // Wait, python code:
    // img_array = np.transpose(img_array, (2, 0, 1))  # HWC to CHW
    // img_array = np.transpose(img_array, (1, 2, 0))  # CHW to HWC again??
    // Actually:
    // original: (H, W, C) -> indices (0, 1, 2)
    // transpose(2, 0, 1): C, H, W -> indices (2, 0, 1)
    // transpose(1, 2, 0) on the new array:
    //   new index 0 -> old index 1 (which is H)
    //   new index 1 -> old index 2 (which is W)
    //   new index 2 -> old index 0 (which is C)
    // So the final shape is (H, W, C) which is (26, 80, 3)
    // And expand_dims(axis=0) makes it (1, 26, 80, 3)
    // Wait, let's just create (1, 26, 80, 3) directly.
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

    // 4. Run inference
    final inputOrt = await OrtValue.fromList(inputData, [1, 26, 80, 3]);

    // In python: self.input_name = self.session.get_inputs()[0].name
    // Let's get the input name dynamically or just use 'input' if we know it.
    // The python code uses dynamic input name. We can get it from session metadata if needed.
    // But let's try getting input names first.
    final inputNames = _session!.inputNames;
    final inputName = inputNames.isNotEmpty ? inputNames[0] : 'input';

    final outputs = await _session!.run({inputName: inputOrt});
    await inputOrt.dispose();

    final outputNames = _session!.outputNames;
    final outputName = outputNames.isNotEmpty ? outputNames[0] : 'output';
    final outputOrt = outputs[outputName];

    if (outputOrt == null) {
      throw Exception('Invalid output from OCR model');
    }

    final batchOutput = await outputOrt.asList();
    await outputOrt.dispose();

    // 5. Decoding based on python code
    const charList = "0123456789abcdefghijklmnopqrstuvwxyz";
    final charLength = charList.length; // 36

    final res = StringBuffer();
    // Python: output = outputs[0] -> shape [1, 144] assuming 4 * 36
    final logits = (batchOutput[0] as List<dynamic>).cast<double>();

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

  static Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }
}
