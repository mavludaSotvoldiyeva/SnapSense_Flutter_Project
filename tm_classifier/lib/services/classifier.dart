import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class Prediction {
  const Prediction(this.label, this.confidence);
  final String label;
  final double confidence;
}

List<String> parseLabels(String raw) => [
  for (final line in raw.split('\n'))
    if (line.trim().isNotEmpty)
      line.trim().replaceFirst(RegExp(r'^\d+\s+'), ''),
];

class Classifier {
  Classifier._(this._interpreter, this.labels);
  final Interpreter _interpreter;
  final List<String> labels;
  int get inputSize => _interpreter.getInputTensor(0).shape[1];

  static Future<Classifier> load() async {
    final interpreter = await Interpreter.fromAsset('assets/model/model_unquant.tflite');
    try {
      final labels = parseLabels(await rootBundle.loadString('assets/model/labels.txt'));
      if (labels.length != interpreter.getOutputTensor(0).shape.last) {
        throw StateError('The label count does not match the model output.');
      }
      return Classifier._(interpreter, labels);
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  List<Prediction> classify(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('This file is not a readable image.');
    final square = img.copyResizeCropSquare(img.bakeOrientation(decoded), size: inputSize);
    final input = [
      List.generate(inputSize, (y) => List.generate(inputSize, (x) {
        final p = square.getPixel(x, y);
        return [p.r / 127.5 - 1.0, p.g / 127.5 - 1.0, p.b / 127.5 - 1.0];
      })),
    ];
    final output = [List<double>.filled(labels.length, 0.0)];
    _interpreter.run(input, output);
    return [for (var i = 0; i < labels.length; i++) Prediction(labels[i], output[0][i])]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  void close() => _interpreter.close();
}
