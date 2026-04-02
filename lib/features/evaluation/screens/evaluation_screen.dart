import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/firebase_service.dart';
import '../../history/screens/history_screen.dart';

class EvaluationScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final int totalSteps;
  final int completedSteps;
  final int timeTakenSeconds;

  const EvaluationScreen({
    super.key,
    required this.task,
    required this.totalSteps,
    required this.completedSteps,
    required this.timeTakenSeconds,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  bool _isSaving = true;
  bool _saved = false;

  double get _score =>
      (widget.completedSteps / widget.totalSteps) * 100;

  Color get _scoreColor {
    if (_score >= 80) return AppTheme.success;
    if (_score >= 50) return AppTheme.accent;
    return AppTheme.danger;
  }

  String get _grade {
    if (_score >= 90) return 'A+';
    if (_score >= 80) return 'A';
    if (_score >= 70) return 'B';
    if (_score >= 60) return 'C';
    return 'D';
  }

  String get _feedback {
    if (_score >= 90) return 'Outstanding performance!';
    if (_score >= 80) return 'Excellent work!';
    if (_score >= 70) return 'Good job!';
    if (_score >= 60) return 'Keep practicing!';
    return 'Needs more practice.';
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    final warnings =
        AppConstants.safetyWarnings[widget.task['component']] ?? [];

    await FirebaseService.saveTaskResult(
      taskId: widget.task['id'],
      taskTitle: widget.task['title'],
      component: widget.task['component'],
      totalSteps: widget.totalSteps,
      completedSteps: widget.completedSteps,
      timeTakenSeconds: widget.timeTakenSeconds,
      safetyWarnings: warnings,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _saved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.task['color'] as int);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Save status
            if (_isSaving)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange),
                    ),
                    SizedBox(width: 8),
                    Text('Saving result...',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 13)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done,
                        color: AppTheme.success, size: 16),
                    SizedBox(width: 8),
                    Text('Result saved to Firebase',
                        style: TextStyle(
                            color: AppTheme.success,
                            fontSize: 13)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Score circle
            Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withOpacity(0.1),
                border: Border.all(
                    color: _scoreColor, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_score.toInt()}%',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor),
                  ),
                  Text(
                    _grade,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(widget.task['title'],
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(_feedback,
                style: TextStyle(
                    fontSize: 15, color: _scoreColor,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),

            // Stats row
            Row(children: [
              _StatCard(
                  label: 'Steps Done',
                  value: '${widget.completedSteps}/${widget.totalSteps}',
                  icon: Icons.check_circle_outline,
                  color: color),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Time Taken',
                  value: _formatTime(widget.timeTakenSeconds),
                  icon: Icons.timer_outlined,
                  color: color),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Grade',
                  value: _grade,
                  icon: Icons.star_outline,
                  color: _scoreColor),
            ]),
            const SizedBox(height: 20),

            // Safety warnings reminder
            if ((AppConstants.safetyWarnings[
                        widget.task['component']] ??
                    [])
                .isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.danger.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.danger, size: 16),
                      SizedBox(width: 6),
                      Text('Safety Reminders',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    ...(AppConstants.safetyWarnings[
                                widget.task['component']] ??
                            [])
                        .map((w) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 3),
                              child: Text('• $w',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.danger)),
                            )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Improvement suggestions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline,
                        color: color, size: 16),
                    const SizedBox(width: 6),
                    Text('Improvement Tips',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  ..._getTips().map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('• $tip',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // View History button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('View My History'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color),
                  foregroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HistoryScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Back to home button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Back to Tasks'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.popUntil(
                    context, (route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getTips() {
    if (_score >= 90) {
      return [
        'Excellent! Try to beat your time next attempt.',
        'Help other students with this task.',
        'Move on to the next component.',
      ];
    } else if (_score >= 70) {
      return [
        'Review the steps you missed.',
        'Practice the sequence a few more times.',
        'Pay attention to tool orientation.',
      ];
    } else {
      return [
        'Re-read the safety warnings carefully.',
        'Practice each step slowly before moving on.',
        'Ask your instructor for guidance.',
        'Try the task again after reviewing the steps.',
      ];
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
