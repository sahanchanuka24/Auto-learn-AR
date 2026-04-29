// ================================================================
// MODULE 2: Student Task Recognition Based on Identified Component
// Research Project: Automobile Learning System
// Vehicle: Maruti Suzuki Alto 800L
// ================================================================
// Input:  Component ID from Module 1 + student action frames
// Output: Task name + current step number
// Technology: Conv1D TFLite + MediaPipe Hand Landmarks
// ================================================================

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
  static const int featureSize = 63;  // 21 landmarks × x,y,z
  static const double confidenceThreshold = 0.65;

  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/action_model.tflite',
      );

      final labelsJson = await rootBundle.loadString(
        'assets/models/action_labels.json',
      );
      _actionLabels = json.decode(labelsJson);

      final stepJson = await rootBundle.loadString(
        'assets/models/step_mapping.json',
      );
      _stepMapping = json.decode(stepJson);

      final compJson = await rootBundle.loadString(
        'assets/models/component_mapping.json',
      );
      _componentMapping = json.decode(compJson);

      _isLoaded = true;
      print('Module 2: Action model loaded! '
          'Actions: ${_actionLabels.length}');
      return true;
    } catch (e) {
      print('Module 2: Error loading model: $e');
      return false;
    }
  }

  // Add frame keypoints to buffer
  void addFrame(List<double> keypoints) {
    if (keypoints.length != featureSize) return;
    _frameBuffer.add(keypoints);
    if (_frameBuffer.length > sequenceLength) {
      _frameBuffer.removeAt(0);
    }
  }

  void addEmptyFrame() =>
      addFrame(List.filled(featureSize, 0.0));

  // MODULE 2 MAIN FUNCTION
  // Recognizes student action from component context
  ActionResult? recognizeAction(String currentComponent) {
    if (!_isLoaded || _interpreter == null) return null;
    if (_frameBuffer.length < sequenceLength) return null;

    try {
      // Build input [1, 30, 63]
      final input = [_frameBuffer.map((f) => f).toList()];
      final output = List.filled(42, 0.0).reshape([1, 42]);

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

      final actionName =
          _actionLabels[maxIndex.toString()] ?? 'unknown';
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
      print('Module 2: Recognition error: $e');
      return null;
    }
  }

  List<String> getActionsForComponent(String component) {
    final actions = _componentMapping[component];
    if (actions == null) return [];
    return List<String>.from(actions);
  }

  void clearBuffer() => _frameBuffer.clear();

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}

// OUTPUT of Module 2 → sent to Module 3
class ActionResult {
  final String actionName;
  final String component;
  final int stepNumber;   // Current step being performed
  final int totalSteps;   // Total steps in this task
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
  bool get isReliable => confidence >= 0.75;

  // Output sent to Module 3
  Map<String, dynamic> toTaskId() => {
    'task_id': '${component}_task',
    'component_id': component,
    'current_step': stepNumber,
    'total_steps': totalSteps,
    'action_detected': actionName,
    'confidence': confidence,
  };
}
