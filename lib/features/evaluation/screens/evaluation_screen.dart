import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class EvaluationScreen extends StatelessWidget {
  final Map<String, dynamic> task;
  final int totalSteps;
  final int completedSteps;

  const EvaluationScreen({
    super.key,
    required this.task,
    required this.totalSteps,
    required this.completedSteps,
  });

  double get _score => (completedSteps / totalSteps) * 100;

  Color get _scoreColor {
    if (_score >= 80) return AppTheme.success;
    if (_score >= 50) return AppTheme.accent;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(task['color'] as int);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _scoreColor.withOpacity(0.1),
                border: Border.all(color: _scoreColor, width: 4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${_score.toInt()}%',
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor)),
                  Text(
                    _score >= 80 ? 'Excellent!' :
                    _score >= 50 ? 'Good' : 'Needs Work',
                    style: TextStyle(
                        fontSize: 14, color: _scoreColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(task['title'],
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('$completedSteps of $totalSteps steps completed',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            Row(children: [
              _StatCard(
                  label: 'Steps Done',
                  value: '$completedSteps',
                  icon: Icons.check_circle_outline,
                  color: color),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Total Steps',
                  value: '$totalSteps',
                  icon: Icons.list_alt,
                  color: color),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Score',
                  value: '${_score.toInt()}%',
                  icon: Icons.star_outline,
                  color: _scoreColor),
            ]),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Back to Tasks'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: color),
                onPressed: () => Navigator.popUntil(
                    context, (route) => route.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
