# Module 1 — Vision-Based Engine Component Identification

## Research Project: Automobile Learning System
## Vehicle: Maruti Suzuki Alto 800L

## What This Module Does
- Takes real-time camera frames as input
- Detects which engine component is visible
- Uses CNN/ML Kit to identify the component
- Outputs component name and confidence score
- Sends component ID to Module 2

## Components Detected
1. Air Filter (air_filter)
2. Spark Plug (spark_plug)
3. 12V Battery (battery)
4. Engine Oil Dipstick (engine_oil)
5. Coolant Reservoir (coolant)

## Technology Used
- Google ML Kit Image Labeling
- TFLite Custom CNN Model
- Flutter Camera Plugin
- Computer Vision

## Key Files
- lib/data/services/ml_detection_service.dart
- lib/features/camera/screens/camera_screen.dart
- assets/models/alto_model.tflite
- assets/models/labels.txt

## Model Details
- Input: Camera frame (real-time)
- Output: Component label + confidence score
- Minimum confidence threshold: 60%
- Model type: Image Classification CNN

## How to Run
```bash
flutter pub get
flutter run -d emulator-5554
```

## Input/Output
Input:  Real-time camera image frame
Output: { component: "spark_plug", confidence: 0.87 }
