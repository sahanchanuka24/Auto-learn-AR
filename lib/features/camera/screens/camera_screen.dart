import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/ml_detection_service.dart';
import '../../../data/services/action_recognition_service.dart';
import '../../../data/services/hand_keypoint_service.dart';
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

  // Services
  final FlutterTts _tts = FlutterTts();
  final MLDetectionService _mlService = MLDetectionService();
  final ActionRecognitionService _actionService =
      ActionRecognitionService();
  final HandKeypointService _handService = HandKeypointService();

  // State
  bool _modelLoaded = false;
  bool _actionModelLoaded = false;
  final List<bool> _completedSteps = [];
  final Stopwatch _stopwatch = Stopwatch();

  // Detection results
  String? _detectedLabel;
  double _detectedConfidence = 0.0;
  bool _componentMatched = false;

  // Action recognition results
  String? _currentAction;
  int _recognizedStepNumber = 0;
  double _actionConfidence = 0.0;
  bool _firstMatchSpoken = false;

  List<String> get _steps =>
      AppConstants.taskSteps[widget.task['component']] ?? [];

  @override
  void initState() {
    super.initState();
    _completedSteps
        .addAll(List.generate(_steps.length, (_) => false));
    _stopwatch.start();
    _initAll();
  }

  Future<void> _initAll() async {
    await _initTts();

    // Load both ML models
    final m1 = await _mlService.loadModel();
    final m2 = await _actionService.loadModel();
    await _handService.initialize();

    if (mounted) {
      setState(() {
        _modelLoaded = m1;
        _actionModelLoaded = m2;
      });
    }

    await _initCamera();
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
      );

      await _controller!.initialize();
      _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasPermission = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (_steps.isNotEmpty) {
          _speak('Step 1: ${_steps[0]}');
        }
      }
    } catch (e) {
      if (e is CameraException &&
          e.code == 'CameraAccessDenied') {
        if (mounted) setState(() => _hasPermission = false);
      }
    }
  }

  void _processFrame(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      // Module 1: Component Detection
      if (_modelLoaded) {
        final result =
            await _mlService.detectFromCameraImage(image, 0);
        if (mounted && result != null) {
          final matched = result.component ==
                  widget.task['component'] &&
              result.isReliable;
          setState(() {
            _detectedLabel = result.label;
            _detectedConfidence = result.confidence;
            _componentMatched = matched;
          });

          if (matched && !_firstMatchSpoken) {
            _firstMatchSpoken = true;
            _speak(
              '${widget.task["title"]} detected. '
              'Step 1: ${_steps[0]}',
            );
          }
        }
      }

      // Module 2: Action Recognition
      if (_actionModelLoaded) {
        final keypoints =
            await _handService.extractKeypoints(image);

        if (keypoints != null) {
          _actionService.addFrame(keypoints);
        } else {
          _actionService.addEmptyFrame();
        }

        final actionResult = _actionService.recognizeAction(
          widget.task['component'],
        );

        if (mounted && actionResult != null &&
            actionResult.isReliable) {
          setState(() {
            _currentAction = actionResult.displayName;
            _recognizedStepNumber = actionResult.stepNumber;
            _actionConfidence = actionResult.confidence;
          });

          // Auto-advance step if action matches
          if (actionResult.stepNumber == _currentStep + 1 &&
              !_completedSteps[_currentStep]) {
            _autoCompleteStep(actionResult.stepNumber - 1);
          }
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));
    _isDetecting = false;
  }

  void _autoCompleteStep(int stepIndex) {
    if (stepIndex >= _steps.length) return;
    setState(() => _completedSteps[stepIndex] = true);
    _speak('Step ${stepIndex + 1} completed automatically!');

    if (stepIndex < _steps.length - 1) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _currentStep = stepIndex + 1);
          _speak('Step ${_currentStep + 1}: '
              '${_steps[_currentStep]}');
        }
      });
    }
  }

  void _nextStep() {
    setState(() => _completedSteps[_currentStep] = true);
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _speak('Step ${_currentStep + 1}: ${_steps[_currentStep]}');
    } else {
      _stopwatch.stop();
      _speak('Task complete! Well done.');
      _showCompletionDialog();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _speak(_steps[_currentStep]);
    }
  }

  void _toggleAudio() {
    setState(() => _audioEnabled = !_audioEnabled);
    _audioEnabled ? _speak(_steps[_currentStep]) : _tts.stop();
  }

  void _showCompletionDialog() {
    final completedCount = _completedSteps.where((c) => c).length;
    final score = ((completedCount / _steps.length) * 100).toInt();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(((0.1) * 255).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Task Complete!',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Score: $score%',
                style: TextStyle(
                    fontSize: 16,
                    color: score >= 80
                        ? AppTheme.success
                        : AppTheme.accent,
                    fontWeight: FontWeight.w600)),
          ],
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
                    completedSteps: completedCount,
                    timeTakenSeconds:
                        _stopwatch.elapsed.inSeconds,
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
    _stopwatch.stop();
    _controller?.stopImageStream();
    _controller?.dispose();
    _mlService.dispose();
    _actionService.dispose();
    _handService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskColor = Color(widget.task['color'] as int);
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_hasPermission
          ? _buildPermissionDenied()
          : !_isInitialized
              ? _buildLoading()
              : _buildCameraView(taskColor),
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
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
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
    );
  }

  Widget _buildCameraView(Color taskColor) {
    return Stack(
      children: [
        // Camera feed
        Positioned.fill(child: CameraPreview(_controller!)),

        // Top bar
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
                  Colors.black.withAlpha(((0.85) * 255).round()),
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

                // AI status indicators
                Row(
                  children: [
                    _AiStatusBadge(
                      label: 'M1',
                      isOn: _modelLoaded,
                      tooltip: 'Component Detection',
                    ),
                    const SizedBox(width: 4),
                    _AiStatusBadge(
                      label: 'M2',
                      isOn: _actionModelLoaded,
                      tooltip: 'Action Recognition',
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Audio toggle
                GestureDetector(
                  onTap: _toggleAudio,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _audioEnabled
                          ? taskColor.withAlpha(((0.8) * 255).round())
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _audioEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: Colors.white, size: 18,
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
                    '${_currentStep + 1}/${_steps.length}',
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

        // Component detection badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 75,
          left: 16, right: 16,
          child: Column(
            children: [
              // Module 1 result
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _componentMatched
                        ? AppTheme.success.withAlpha(((0.9) * 255).round())
                        : Colors.black.withAlpha(((0.65) * 255).round()),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _componentMatched
                          ? AppTheme.success
                          : Colors.white30,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _componentMatched
                            ? Icons.check_circle
                            : Icons.search,
                        color: Colors.white, size: 13,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _detectedLabel != null
                            ? 'M1: $_detectedLabel '
                                '${(_detectedConfidence * 100).toStringAsFixed(0)}%'
                            : 'M1: Scanning component...',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Module 2 result
              if (_actionModelLoaded)
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _currentAction != null
                          ? Colors.purple.withAlpha(((0.8) * 255).round())
                          : Colors.black.withAlpha(((0.5) * 255).round()),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _currentAction != null
                            ? Colors.purple
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gesture,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          _currentAction != null
                              ? 'M2: ${_currentAction!} '
                                  '${(_actionConfidence * 100).toStringAsFixed(0)}%'
                              : 'M2: Watching actions...',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Scanning frame
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 260, height: 200,
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
                      ? AppTheme.success : taskColor),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _componentMatched
                          ? AppTheme.success.withAlpha(((0.85) * 255).round())
                          : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _componentMatched
                          ? 'Component detected!'
                          : 'Point camera at component',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Step progress dots
        Positioned(
          top: MediaQuery.of(context).padding.top + 80,
          right: 12,
          child: Column(
            children: List.generate(_steps.length, (i) {
              final isDone = _completedSteps[i];
              final isCurrent = i == _currentStep;
              final isRecognized = _recognizedStepNumber == i + 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppTheme.success
                      : isRecognized
                          ? Colors.purple
                          : isCurrent
                              ? taskColor
                              : Colors.black45,
                  border: Border.all(
                    color: isCurrent || isRecognized
                        ? (isRecognized ? Colors.purple : taskColor)
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
                            color: isCurrent || isRecognized
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

        // Bottom panel
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: 16, left: 16, right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha(((0.92) * 255).round()),
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
                    value: _completedSteps
                            .where((c) => c)
                            .length /
                        _steps.length,
                    backgroundColor: Colors.white24,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(taskColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_completedSteps.where((c) => c).length}'
                      ' of ${_steps.length} done',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11),
                    ),
                    // Timer
                    StreamBuilder(
                      stream: Stream.periodic(
                          const Duration(seconds: 1)),
                      builder: (context, _) {
                        final e = _stopwatch.elapsed;
                        return Text(
                          '${e.inMinutes.toString().padLeft(2, "0")}:'
                          '${(e.inSeconds % 60).toString().padLeft(2, "0")}',
                          style: TextStyle(
                              color: taskColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Current step
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: taskColor.withAlpha(((0.5) * 255).round())),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Step ${_currentStep + 1} of '
                            '${_steps.length}',
                            style: TextStyle(
                                color: taskColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          if (_currentAction != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple
                                    .withAlpha(((0.3) * 255).round()),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Text(
                                'AI detected action',
                                style: const TextStyle(
                                    color: Colors.purple,
                                    fontSize: 9),
                              ),
                            ),
                          ],
                        ],
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
                                    BorderRadius.circular(8)),
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
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: taskColor,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
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

// AI Status Badge widget
class _AiStatusBadge extends StatelessWidget {
  final String label;
  final bool isOn;
  final String tooltip;

  const _AiStatusBadge({
    required this.label,
    required this.isOn,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isOn
              ? Colors.green.withAlpha(((0.3) * 255).round())
              : Colors.orange.withAlpha(((0.3) * 255).round()),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isOn ? Colors.greenAccent : Colors.orange,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isOn ? Colors.greenAccent : Colors.orange,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final double size;
  final double thickness;
  final bool top;
  final bool left;
  const _Corner({required this.color, required this.size,
      required this.thickness, required this.top,
      required this.left});

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
