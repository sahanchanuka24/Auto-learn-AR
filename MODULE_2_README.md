# Module 2 — Student Task Recognition Based on Identified Component

## Research Project: Automobile Learning System
## Vehicle: Maruti Suzuki Alto 800L

## What This Module Does
- Receives component ID from Module 1
- Analyzes student action logs (taps, steps, touches)
- Matches actions with task patterns
- Predicts ongoing task using AI rule-based + ML classification
- Outputs task name and required steps

## Tasks Recognized
1. Air Filter Inspection & Replacement (8 actions)
2. Spark Plug Removal & Gap Inspection (9 actions)
3. 12V Battery Terminal Maintenance (10 actions)
4. Engine Oil Dipstick Check (8 actions)
5. Coolant Reservoir Inspection (7 actions)
Total: 42 action classes

## Technology Used
- Conv1D Neural Network (TFLite)
- MediaPipe Hand Landmark Detection
- AI Rule-Based Classification
- Pattern Recognition / Sequence Modeling

## Key Files
- lib/data/services/action_recognition_service.dart
- lib/data/services/hand_keypoint_service.dart
- assets/models/action_model.tflite
- assets/models/action_labels.json
- assets/models/step_mapping.json
- assets/models/component_mapping.json

## Model Details
- Architecture: Conv1D + GlobalAveragePooling
- Input: 30 frames × 63 keypoints (21 landmarks × xyz)
- Output: 42 action class probabilities
- Training accuracy: 90%+
- Dataset: Synthetic hand movement sequences

## How to Run
```bash
flutter pub get
flutter run -d emulator-5554
```

## Input/Output
Input:  { component_id: "spark_plug" } + student actions
Output: { task: "Spark Plug Removal", step: 3, total_steps: 9 }
