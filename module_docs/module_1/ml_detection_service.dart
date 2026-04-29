// ================================================================
// MODULE 1: Vision-Based Engine Component Identification
// Research Project: Automobile Learning System
// Vehicle: Maruti Suzuki Alto 800L
// ================================================================
// Input:  Real-time camera frame
// Output: Component name + confidence score
// Technology: Google ML Kit + TFLite CNN
// ================================================================

import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';

class MLDetectionService {
  ImageLabeler? _labeler;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Maps ML Kit labels to your 5 component IDs
  static const Map<String, String> keywordToComponent = {
    // Air filter keywords
    'air': 'air_filter',
    'filter': 'air_filter',
    'intake': 'air_filter',
    'ventilation': 'air_filter',

    // Spark plug keywords
    'spark': 'spark_plug',
    'plug': 'spark_plug',
    'ignition': 'spark_plug',
    'cylinder': 'spark_plug',

    // Battery keywords
    'battery': 'battery',
    'electric': 'battery',
    'voltage': 'battery',
    'terminal': 'battery',

    // Engine oil keywords
    'oil': 'engine_oil',
    'dipstick': 'engine_oil',
    'lubricant': 'engine_oil',
    'gauge': 'engine_oil',

    // Coolant keywords
    'coolant': 'coolant',
    'radiator': 'coolant',
    'reservoir': 'coolant',
    'liquid': 'coolant',
  };

  // Load the ML model
  Future<bool> loadModel() async {
    try {
      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      _labeler = ImageLabeler(options: options);
      _isLoaded = true;
      print('Module 1: ML Kit loaded successfully');
      return true;
    } catch (e) {
      print('Module 1: Error loading ML Kit: $e');
      return false;
    }
  }

  // MODULE 1 MAIN FUNCTION
  // Detects engine component from camera frame
  Future<DetectionResult?> detectFromCameraImage(
    CameraImage image,
    int rotation,
  ) async {
    if (!_isLoaded || _labeler == null) return null;

    try {
      final inputImage = _buildInputImage(image, rotation);
      if (inputImage == null) return null;

      // Run ML Kit inference
      final labels = await _labeler!.processImage(inputImage);
      if (labels.isEmpty) return null;

      // Match labels to components
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

      // Return top label even if not matched
      return DetectionResult(
        label: labels.first.label,
        component: 'unknown',
        confidence: labels.first.confidence,
      );
    } catch (e) {
      print('Module 1: Detection error: $e');
      return null;
    }
  }

  InputImage? _buildInputImage(CameraImage image, int rotation) {
    try {
      final format = InputImageFormatValue.fromRawValue(
          image.format.raw);
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
      return null;
    }
  }

  void dispose() {
    _labeler?.close();
    _isLoaded = false;
  }
}

// OUTPUT of Module 1 → sent to Module 2
class DetectionResult {
  final String label;      // Raw ML Kit label
  final String component;  // Mapped component ID
  final double confidence; // Detection confidence 0-1

  DetectionResult({
    required this.label,
    required this.component,
    required this.confidence,
  });

  // Only trust if above 60% confidence
  bool get isMatched => component != 'unknown';
  bool get isReliable => confidence >= 0.6 && isMatched;
  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  // Output sent to Module 2
  Map<String, dynamic> toComponentId() => {
    'component_id': component,
    'component_name': label,
    'confidence': confidence,
    'is_reliable': isReliable,
  };
}
