import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';

class MLDetectionService {
  ImageLabeler? _labeler;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  static const Map<String, String> keywordToComponent = {
    'air': 'air_filter',
    'filter': 'air_filter',
    'intake': 'air_filter',
    'ventilation': 'air_filter',
    'spark': 'spark_plug',
    'plug': 'spark_plug',
    'ignition': 'spark_plug',
    'cylinder': 'spark_plug',
    'battery': 'battery',
    'electric': 'battery',
    'voltage': 'battery',
    'terminal': 'battery',
    'oil': 'engine_oil',
    'dipstick': 'engine_oil',
    'lubricant': 'engine_oil',
    'gauge': 'engine_oil',
    'coolant': 'coolant',
    'radiator': 'coolant',
    'reservoir': 'coolant',
    'liquid': 'coolant',
  };

  Future<bool> loadModel() async {
    try {
      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      _labeler = ImageLabeler(options: options);
      _isLoaded = true;
      debugPrint('ML Kit loaded successfully');
      return true;
    } catch (e) {
      debugPrint('Error loading ML Kit: $e');
      return false;
    }
  }

  Future<DetectionResult?> detectFromCameraImage(
    CameraImage image,
    int rotation,
  ) async {
    if (!_isLoaded || _labeler == null) return null;

    try {
      final inputImage = _buildInputImage(image, rotation);
      if (inputImage == null) return null;

      final labels = await _labeler!.processImage(inputImage);
      if (labels.isEmpty) return null;

      for (final label in labels) {
        final labelLower = label.label.toLowerCase();
        for (final entry in keywordToComponent.entries) {
          if (labelLower.contains(entry.key)) {
            return DetectionResult(
              label: label.label,
              component: entry.value,
              confidence: label.confidence,
            );
          }
        }
      }

      return DetectionResult(
        label: labels.first.label,
        component: 'unknown',
        confidence: labels.first.confidence,
      );
    } catch (e) {
      debugPrint('Detection error: $e');
      return null;
    }
  }

  InputImage? _buildInputImage(CameraImage image, int rotation) {
    try {
      final format = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      if (format == null) return null;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: InputImageRotationValue.fromRawValue(rotation)
              ?? InputImageRotation.rotation0deg,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('InputImage build error: $e');
      return null;
    }
  }

  void dispose() {
    _labeler?.close();
    _isLoaded = false;
  }
}

class DetectionResult {
  final String label;
  final String component;
  final double confidence;

  DetectionResult({
    required this.label,
    required this.component,
    required this.confidence,
  });

  bool get isMatched => component != 'unknown';
  bool get isReliable => confidence >= 0.6 && isMatched;

  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';
}