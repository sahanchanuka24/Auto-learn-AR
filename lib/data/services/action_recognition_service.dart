import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ActionRecognitionService {
  Interpreter? _interpreter;
  Map<String, dynamic> _actionLabels = {};
  Map<String, dynamic> _stepMapping = {};
  Map<String, dynamic> _componentMapping = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Sequence buffer — stores last 30 frames
  final List<List<double>> _frameBuffer = [];
  static const int sequenceLength = 30;
  static const int featureSize = 63;
  static const double confidenceThreshold = 0.65;

  Future<bool> loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/action_model.tflite',
      );

      // Load action labels
      final labelsJson = await rootBundle.loadString(
        'assets/models/action_labels.json',
      );
      _actionLabels = json.decode(labelsJson);

      // Load step mapping
      final stepJson = await rootBundle.loadString(
        'assets/models/step_mapping.json',
      );
      _stepMapping = json.decode(stepJson);

      // Load component mapping
      final compJson = await rootBundle.loadString(
        'assets/models/component_mapping.json',
      );
      _componentMapping = json.decode(compJson);

      _isLoaded = true;
      print('Action Recognition model loaded!');
      print('Actions: ${_actionLabels.length}');
      return true;
    } catch (e) {
      print('Error loading action model: $e');
      _isLoaded = false;
      return false;
    }
  }

  // Add a new frame to the buffer
  // keypoints = 21 hand landmarks × 3 (x,y,z) = 63 values
  void addFrame(List<double> keypoints) {
    if (keypoints.length != featureSize) return;

    _frameBuffer.add(keypoints);

    // Keep only last 30 frames
    if (_frameBuffer.length > sequenceLength) {
      _frameBuffer.removeAt(0);
    }
  }

  // Add empty frame when no hand detected
  void addEmptyFrame() {
    addFrame(List.filled(featureSize, 0.0));
  }

  // Run action recognition on current buffer
  ActionResult? recognizeAction(String currentComponent) {
    if (!_isLoaded || _interpreter == null) return null;
    if (_frameBuffer.length < sequenceLength) return null;

    try {
      // Build input tensor [1, 30, 63]
      final input = [_frameBuffer.map((f) => f).toList()];

      // Output tensor [1, 42]
      final output = List.filled(42, 0.0).reshape([1, 42]);

      // Run inference
      _interpreter!.run(input, output);

      final scores = List<double>.from(output[0]);

      // Find best prediction
      double maxScore = 0;
      int maxIndex = 0;
      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      if (maxScore < confidenceThreshold) return null;

      final actionName = _actionLabels[maxIndex.toString()] ?? 'unknown';

      // Check if action belongs to current component
      final stepInfo = _stepMapping[actionName];
      if (stepInfo == null) return null;

      final actionComponent = stepInfo['component'] as String;
      if (actionComponent != currentComponent) return null;

      return ActionResult(
        actionName: actionName,
        component: actionComponent,
        stepNumber: stepInfo['step_number'] as int,
        totalSteps: stepInfo['total_steps'] as int,
        confidence: maxScore,
      );
    } catch (e) {
      print('Action recognition error: $e');
      return null;
    }
  }

  // Get all actions for a component in order
  List<String> getActionsForComponent(String component) {
    final actions = _componentMapping[component];
    if (actions == null) return [];
    return List<String>.from(actions);
  }

  // Clear the frame buffer
  void clearBuffer() {
    _frameBuffer.clear();
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}

class ActionResult {
  final String actionName;
  final String component;
  final int stepNumber;
  final int totalSteps;
  final double confidence;

  ActionResult({
    required this.actionName,
    required this.component,
    required this.stepNumber,
    required this.totalSteps,
    required this.confidence,
  });

  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  String get displayName =>
      actionName.replaceAll('_', ' ').replaceAll(
          RegExp(r'^[A-Z]{2}_\d{2}_'), '');

  bool get isReliable => confidence >= 0.75;

  @override
  String toString() =>
      'Action: $actionName | Step: $stepNumber | '
      'Confidence: $confidencePercent';
}
