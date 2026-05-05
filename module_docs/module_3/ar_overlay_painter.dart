// ================================================================
// MODULE 3: AR-Supported Task Verification and Instruction System
// Research Project: Automobile Learning System
// Vehicle: Maruti Suzuki Alto 800L
// ================================================================
// Input:  Component ID + Task ID + real-time camera feed
// Output: AR overlays + correctness score + audio guidance
// Technology: CustomPainter AR + TTS + Visual Comparison
// ================================================================

import 'package:flutter/material.dart';

// AR Overlay data model
class AROverlay {
  final String label;
  final Offset position;
  final Color color;
  final AROverlayType type;
  final double confidence;

  const AROverlay({
    required this.label,
    required this.position,
    required this.color,
    required this.type,
    this.confidence = 1.0,
  });
}

enum AROverlayType {
  arrow,
  label,
  highlight,
  warning,
  checkmark,
}

// Predefined AR overlays for each task step
class AROverlayConfig {
  static Map<String, List<AROverlay>> getOverlaysForStep(
    String component,
    int stepNumber,
  ) {
    final configs = {
      'air_filter': _airFilterOverlays,
      'spark_plug': _sparkPlugOverlays,
      'battery': _batteryOverlays,
      'engine_oil': _engineOilOverlays,
      'coolant': _coolantOverlays,
    };

    final componentOverlays = configs[component] ?? {};
    return componentOverlays;
  }

  static final Map<String, List<AROverlay>> _airFilterOverlays = {
    '1': [
      AROverlay(
        label: 'Air Filter Box →',
        position: Offset(0.5, 0.4),
        color: Colors.blue,
        type: AROverlayType.arrow,
      ),
    ],
    '2': [
      AROverlay(
        label: 'Unclip here',
        position: Offset(0.3, 0.35),
        color: Colors.orange,
        type: AROverlayType.highlight,
      ),
      AROverlay(
        label: 'Unclip here',
        position: Offset(0.7, 0.35),
        color: Colors.orange,
        type: AROverlayType.highlight,
      ),
    ],
    '3': [
      AROverlay(
        label: '↑ Lift cover',
        position: Offset(0.5, 0.3),
        color: Colors.green,
        type: AROverlayType.arrow,
      ),
    ],
  };

  static final Map<String, List<AROverlay>> _sparkPlugOverlays = {
    '1': [
      AROverlay(
        label: 'Plug wire →',
        position: Offset(0.5, 0.45),
        color: Colors.orange,
        type: AROverlayType.arrow,
      ),
    ],
    '2': [
      AROverlay(
        label: 'Twist & pull',
        position: Offset(0.5, 0.4),
        color: Colors.red,
        type: AROverlayType.highlight,
      ),
    ],
  };

  static final Map<String, List<AROverlay>> _batteryOverlays = {
    '1': [
      AROverlay(
        label: '12V Battery',
        position: Offset(0.5, 0.4),
        color: Colors.red,
        type: AROverlayType.label,
      ),
    ],
    '2': [
      AROverlay(
        label: '⚠ Negative first!',
        position: Offset(0.4, 0.35),
        color: Colors.red,
        type: AROverlayType.warning,
      ),
    ],
  };

  static final Map<String, List<AROverlay>> _engineOilOverlays = {
    '1': [
      AROverlay(
        label: 'Yellow dipstick →',
        position: Offset(0.5, 0.45),
        color: Colors.yellow,
        type: AROverlayType.arrow,
      ),
    ],
    '2': [
      AROverlay(
        label: '↑ Pull out',
        position: Offset(0.5, 0.35),
        color: Colors.green,
        type: AROverlayType.arrow,
      ),
    ],
  };

  static final Map<String, List<AROverlay>> _coolantOverlays = {
    '1': [
      AROverlay(
        label: 'Coolant bottle →',
        position: Offset(0.5, 0.4),
        color: Colors.teal,
        type: AROverlayType.arrow,
      ),
    ],
    '2': [
      AROverlay(
        label: 'Check MIN/MAX',
        position: Offset(0.6, 0.45),
        color: Colors.blue,
        type: AROverlayType.highlight,
      ),
    ],
  };
}

// AR Painter — draws overlays on camera feed
class AROverlayPainter extends CustomPainter {
  final List<AROverlay> overlays;
  final double animationValue;
  final bool componentDetected;

  AROverlayPainter({
    required this.overlays,
    required this.animationValue,
    this.componentDetected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final overlay in overlays) {
      final x = overlay.position.dx * size.width;
      final y = overlay.position.dy * size.height;

      switch (overlay.type) {
        case AROverlayType.arrow:
          _drawArrow(canvas, Offset(x, y), overlay);
          break;
        case AROverlayType.label:
          _drawLabel(canvas, Offset(x, y), overlay);
          break;
        case AROverlayType.highlight:
          _drawHighlight(canvas, Offset(x, y), overlay, size);
          break;
        case AROverlayType.warning:
          _drawWarning(canvas, Offset(x, y), overlay);
          break;
        case AROverlayType.checkmark:
          _drawCheckmark(canvas, Offset(x, y), overlay);
          break;
      }
    }

    // Draw scanning frame
    _drawScanningFrame(canvas, size);
  }

  void _drawArrow(Canvas canvas, Offset pos,
      AROverlay overlay) {
    final paint = Paint()
      ..color = overlay.color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Animated arrow
    final arrowLength = 40.0 + (animationValue * 10);
    canvas.drawLine(
      Offset(pos.dx - arrowLength / 2, pos.dy),
      Offset(pos.dx + arrowLength / 2, pos.dy),
      paint,
    );

    // Arrowhead
    final arrowPaint = Paint()
      ..color = overlay.color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(pos.dx + arrowLength / 2, pos.dy)
      ..lineTo(pos.dx + arrowLength / 2 - 12, pos.dy - 8)
      ..lineTo(pos.dx + arrowLength / 2 - 12, pos.dy + 8)
      ..close();
    canvas.drawPath(path, arrowPaint);

    _drawLabel(canvas, Offset(pos.dx, pos.dy - 20), overlay);
  }

  void _drawLabel(Canvas canvas, Offset pos,
      AROverlay overlay) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: overlay.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pos.dx - textPainter.width / 2 - 8,
        pos.dy - textPainter.height / 2 - 4,
        textPainter.width + 16,
        textPainter.height + 8,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = overlay.color.withAlpha(((0.8) * 255).round()),
    );

    textPainter.paint(
      canvas,
      Offset(
        pos.dx - textPainter.width / 2,
        pos.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawHighlight(Canvas canvas, Offset pos,
      AROverlay overlay, Size size) {
    final paint = Paint()
      ..color = overlay.color.withAlpha(((0.3 + animationValue * 0.2) * 255).round())
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, 30 + animationValue * 5, paint);

    final borderPaint = Paint()
      ..color = overlay.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
        pos, 30 + animationValue * 5, borderPaint);

    _drawLabel(
        canvas, Offset(pos.dx, pos.dy - 45), overlay);
  }

  void _drawWarning(Canvas canvas, Offset pos,
      AROverlay overlay) {
    final paint = Paint()
      ..color = Colors.red.withAlpha(((0.9) * 255).round())
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(pos.dx, pos.dy - 20)
      ..lineTo(pos.dx - 18, pos.dy + 12)
      ..lineTo(pos.dx + 18, pos.dy + 12)
      ..close();
    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - 10),
    );

    _drawLabel(
        canvas, Offset(pos.dx, pos.dy + 30), overlay);
  }

  void _drawCheckmark(Canvas canvas, Offset pos,
      AROverlay overlay) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(pos.dx - 12, pos.dy)
      ..lineTo(pos.dx - 4, pos.dy + 10)
      ..lineTo(pos.dx + 12, pos.dy - 10);
    canvas.drawPath(path, paint);
  }

  void _drawScanningFrame(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withAlpha(((0.5 + animationValue * 0.3) * 255).round())
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const margin = 60.0;
    const cornerSize = 24.0;
    final rect = Rect.fromLTWH(
      margin, margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );

    // Corner brackets
    final corners = [
      [rect.topLeft, Offset(1, 0), Offset(0, 1)],
      [rect.topRight, Offset(-1, 0), Offset(0, 1)],
      [rect.bottomLeft, Offset(1, 0), Offset(0, -1)],
      [rect.bottomRight, Offset(-1, 0), Offset(0, -1)],
    ];

    for (final corner in corners) {
      final origin = corner[0];
      final hDir = corner[1];
      final vDir = corner[2];

      canvas.drawLine(
        origin,
        origin + hDir * cornerSize,
        paint,
      );
      canvas.drawLine(
        origin,
        origin + vDir * cornerSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AROverlayPainter old) =>
      old.animationValue != animationValue ||
      old.overlays != overlays;
}
