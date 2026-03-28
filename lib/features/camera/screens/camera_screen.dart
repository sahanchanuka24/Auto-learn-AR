import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/ml_detection_service.dart';
import '../../evaluation/screens/evaluation_screen.dart';

class CameraScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  const CameraScreen({super.key, required this.task});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _hasPermission = true;
  int _currentStep = 0;
  bool _audioEnabled = true;
  bool _isDetecting = false;
  bool _modelLoaded = false;

  final FlutterTts _tts = FlutterTts();
  final MLDetectionService _mlService = MLDetectionService();
  final List<bool> _completedSteps = [];

  // Detection results
  String? _detectedLabel;
  String? _detectedComponent;
  double _detectedConfidence = 0.0;
  bool _componentMatched = false;
  bool _firstMatchSpoken = false;

  List<String> get _steps =>
      AppConstants.taskSteps[widget.task['component']] ?? [];

  @override
  void initState() {
    super.initState();
    _completedSteps.addAll(
        List.generate(_steps.length, (_) => false));
    _initAll();
  }

  Future<void> _initAll() async {
    await _initTts();
    await _initCamera();
    final loaded = await _mlService.loadModel();
    if (mounted) setState(() => _modelLoaded = loaded);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    if (!_audioEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasPermission = true;
        });

        // Speak first step after short delay
        await Future.delayed(const Duration(seconds: 1));
        if (_steps.isNotEmpty) {
          _speak('Starting ${widget.task["title"]}. '
              'Step 1: ${_steps[0]}');
        }
      }
    } catch (e) {
      if (e is CameraException &&
          e.code == 'CameraAccessDenied') {
        if (mounted) setState(() => _hasPermission = false);
      }
    }
  }

  // Process each camera frame through ML model
  void _processFrame(CameraImage image) async {
    if (_isDetecting || !_modelLoaded) return;
    _isDetecting = true;

    try {
      // Convert YUV420 to simple byte array
      final bytes = _yuv420toRgbBytes(image);

      final result = _mlService.classify(
        bytes,
        image.width,
        image.height,
      );

      if (mounted && result != null) {
        final matched =
            result.component == widget.task['component'] &&
            result.isReliable;

        setState(() {
          _detectedLabel = result.label;
          _detectedComponent = result.component;
          _detectedConfidence = result.confidence;
          _componentMatched = matched;
        });

        // Speak when correct component first detected
        if (matched && !_firstMatchSpoken) {
          _firstMatchSpoken = true;
          await _speak(
            '${result.label} detected. '
            'Begin step 1: ${_steps[0]}',
          );
        }
      }
    } catch (e) {
      // Silent fail — keep camera running
    }

    // Wait before next detection to save battery
    await Future.delayed(const Duration(milliseconds: 600));
    _isDetecting = false;
  }

  // Convert YUV420 camera frame to RGB bytes
  Uint8List _yuv420toRgbBytes(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final width = image.width;
    final height = image.height;
    final rgb = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex =
            (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uPlane.bytesPerPixel!;

        final yVal = yBytes[yIndex];
        final uVal = uBytes[uvIndex] - 128;
        final vVal = vBytes[uvIndex] - 128;

        final r = (yVal + 1.402 * vVal).clamp(0, 255).toInt();
        final g = (yVal - 0.344136 * uVal - 0.714136 * vVal)
            .clamp(0, 255)
            .toInt();
        final b = (yVal + 1.772 * uVal).clamp(0, 255).toInt();

        final rgbIndex = (y * width + x) * 3;
        rgb[rgbIndex] = r;
        rgb[rgbIndex + 1] = g;
        rgb[rgbIndex + 2] = b;
      }
    }
    return rgb;
  }

  void _nextStep() {
    setState(() => _completedSteps[_currentStep] = true);

    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _firstMatchSpoken = false;
      });
      _speak('Step ${_currentStep + 1}: ${_steps[_currentStep]}');
    } else {
      _speak('Excellent! You have completed all steps for '
          '${widget.task["title"]}.');
      _showCompletionDialog();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _speak('Step ${_currentStep + 1}: ${_steps[_currentStep]}');
    }
  }

  void _toggleAudio() {
    setState(() => _audioEnabled = !_audioEnabled);
    if (_audioEnabled) {
      _speak(_steps[_currentStep]);
    } else {
      _tts.stop();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppTheme.success),
          SizedBox(width: 8),
          Text('Task Complete!'),
        ]),
        content: Text(
          'You completed all ${_steps.length} steps for '
          '${widget.task["title"]}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Tasks'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EvaluationScreen(
                    task: widget.task,
                    totalSteps: _steps.length,
                    completedSteps:
                        _completedSteps.where((c) => c).length,
                  ),
                ),
              );
            },
            child: const Text('See Results'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _controller?.stopImageStream();
    _controller?.dispose();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_hasPermission
          ? _buildPermissionDenied()
          : !_isInitialized
              ? _buildLoading()
              : _buildCameraView(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Starting camera...',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt,
                color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text('Camera Access Required',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initCamera,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final taskColor = Color(widget.task['color'] as int);
    return Stack(
      children: [
        // 1. Full screen camera
        Positioned.fill(child: CameraPreview(_controller!)),

        // 2. Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16, right: 16, bottom: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _tts.stop();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.task['title'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      Text(widget.task['subtitle'],
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11)),
                    ],
                  ),
                ),

                // Model status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _modelLoaded
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _modelLoaded
                            ? Icons.memory
                            : Icons.hourglass_empty,
                        color: _modelLoaded
                            ? Colors.greenAccent
                            : Colors.orange,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _modelLoaded ? 'AI ON' : 'Loading AI',
                        style: TextStyle(
                          color: _modelLoaded
                              ? Colors.greenAccent
                              : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Audio toggle
                GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _audioEnabled
                          ? taskColor.withOpacity(0.8)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _audioEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Step counter
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: taskColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1}/${_steps.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. AI Detection badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 75,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _componentMatched
                    ? AppTheme.success.withOpacity(0.9)
                    : Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _componentMatched
                      ? AppTheme.success
                      : Colors.white30,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _componentMatched
                        ? Icons.check_circle
                        : _modelLoaded
                            ? Icons.search
                            : Icons.hourglass_bottom,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _detectedLabel != null
                        ? '$_detectedLabel  '
                            '${(_detectedConfidence * 100).toStringAsFixed(0)}%'
                        : _modelLoaded
                            ? 'Scanning for component...'
                            : 'Loading AI model...',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. Scanning frame — turns green when matched
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 260,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: _componentMatched
                    ? AppTheme.success
                    : taskColor,
                width: _componentMatched ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                ..._buildCorners(
                    _componentMatched
                        ? AppTheme.success
                        : taskColor),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _componentMatched
                          ? AppTheme.success.withOpacity(0.85)
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _componentMatched
                          ? 'Component detected!'
                          : 'Point camera at component',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 5. Step progress dots (right side)
        Positioned(
          top: MediaQuery.of(context).padding.top + 80,
          right: 12,
          child: Column(
            children: List.generate(_steps.length, (i) {
              final isDone = _completedSteps[i];
              final isCurrent = i == _currentStep;
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppTheme.success
                      : isCurrent
                          ? taskColor
                          : Colors.black45,
                  border: Border.all(
                    color: isCurrent
                        ? taskColor
                        : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 13)
                      : Text('${i + 1}',
                          style: TextStyle(
                            color: isCurrent
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          )),
                ),
              );
            }),
          ),
        ),

        // 6. Bottom panel
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.92),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _completedSteps.where((c) => c).length /
                        _steps.length,
                    backgroundColor: Colors.white24,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(taskColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_completedSteps.where((c) => c).length}'
                      ' of ${_steps.length} steps done',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      '${((_completedSteps.where((c) => c).length /
                              _steps.length) * 100).toInt()}%',
                      style: TextStyle(
                          color: taskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Current step instruction box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: taskColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_audioEnabled)
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 10, top: 2),
                          child: Icon(Icons.graphic_eq,
                              color: taskColor, size: 18),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step ${_currentStep + 1} '
                              'of ${_steps.length}',
                              style: TextStyle(
                                  color: taskColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _steps[_currentStep],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Navigation buttons
                Row(
                  children: [
                    if (_currentStep > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back,
                              size: 15, color: Colors.white70),
                          label: const Text('Previous',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _previousStep,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _currentStep < _steps.length - 1
                              ? Icons.check
                              : Icons.emoji_events,
                          size: 15,
                        ),
                        label: Text(
                          _currentStep < _steps.length - 1
                              ? 'Mark Done & Next'
                              : 'Complete Task',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: taskColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _nextStep,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners(Color color) {
    const double size = 22;
    const double thickness = 3;
    return [
      Positioned(top: 0, left: 0,
          child: _Corner(color: color, size: size,
              thickness: thickness, top: true, left: true)),
      Positioned(top: 0, right: 0,
          child: _Corner(color: color, size: size,
              thickness: thickness, top: true, left: false)),
      Positioned(bottom: 0, left: 0,
          child: _Corner(color: color, size: size,
              thickness: thickness, top: false, left: true)),
      Positioned(bottom: 0, right: 0,
          child: _Corner(color: color, size: size,
              thickness: thickness, top: false, left: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  final bool top;
  final bool left;

  const _Corner({
    required this.color, required this.size,
    required this.thickness, required this.top, required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color, thickness: thickness,
            top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  _CornerPainter({required this.color, required this.thickness,
      required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}
