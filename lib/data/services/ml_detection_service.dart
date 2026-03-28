import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class MLDetectionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Maps Teachable Machine label names to your task component IDs
  static const Map<String, String> labelToComponent = {
    'air_filter':  'air_filter',
    'spark_plug':  'spark_plug',
    'battery':     'battery',
    'engine_oil':  'engine_oil',
    'coolant':     'coolant',
    // Common variations
    'Air_filter':  'air_filter',
    'Spark_plug':  'spark_plug',
    'Battery':     'battery',
    'Engine_oil':  'engine_oil',
    'Coolant':     'coolant',
  };

  Future<bool> loadModel() async {
    try {
      print('Loading TFLite model...');

      _interpreter = await Interpreter.fromAsset(
        'assets/models/alto_model.tflite',
      );

      final labelsRaw = await rootBundle.loadString(
        'assets/models/labels.txt',
      );

      _labels = labelsRaw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          // Teachable Machine adds "0 air_filter" prefix — remove number
          .map((l) => l.contains(' ') ? l.split(' ').last : l)
          .toList();

      _isLoaded = true;
      print('Model loaded! Labels: $_labels');
      return true;
    } catch (e) {
      print('Error loading model: $e');
      _isLoaded = false;
      return false;
    }
  }

  DetectionResult? classify(Uint8List rgbBytes, int width, int height) {
    if (!_isLoaded || _interpreter == null) return null;

    try {
      // Resize to 224x224 and normalize to [0,1]
      final input = _resizeAndNormalize(rgbBytes, width, height, 224, 224);

      // Output shape: [1, numClasses]
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1];
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _interpreter!.run(input, output);

      final scores = List<double>.from(output[0]);

      // Find best result
      double maxScore = 0;
      int maxIndex = 0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      if (maxIndex >= _labels.length) return null;

      final label = _labels[maxIndex];
      final component = labelToComponent[label] ?? label.toLowerCase();

      return DetectionResult(
        label: label,
        component: component,
        confidence: maxScore,
        allScores: Map.fromIterables(
          _labels,
          scores,
        ),
      );
    } catch (e) {
      print('Classification error: $e');
      return null;
    }
  }

  List _resizeAndNormalize(
    Uint8List bytes,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
  ) {
    final input = List.generate(
      1,
      (_) => List.generate(
        dstHeight,
        (y) => List.generate(
          dstWidth,
          (x) {
            // Map destination pixel to source pixel
            final srcX = (x * srcWidth / dstWidth).floor();
            final srcY = (y * srcHeight / dstHeight).floor();
            final idx = (srcY * srcWidth + srcX) * 3;

            if (idx + 2 < bytes.length) {
              return [
                bytes[idx] / 255.0,
                bytes[idx + 1] / 255.0,
                bytes[idx + 2] / 255.0,
              ];
            }
            return [0.0, 0.0, 0.0];
          },
        ),
      ),
    );
    return input;
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}

class DetectionResult {
  final String label;
  final String component;
  final double confidence;
  final Map<String, double> allScores;

  DetectionResult({
    required this.label,
    required this.component,
    required this.confidence,
    required this.allScores,
  });

  // Only trust if above 70% confidence
  bool get isReliable => confidence >= 0.70;

  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  @override
  String toString() =>
      'DetectionResult(label: $label, confidence: $confidencePercent)';
}
