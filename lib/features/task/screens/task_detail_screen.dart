import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../camera/screens/camera_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final Map<String, dynamic> task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final steps    = AppConstants.taskSteps[task['component']] ?? [];
    final warnings = AppConstants.safetyWarnings[task['component']] ?? [];
    final color    = Color(task['color'] as int);

    return Scaffold(
      appBar: AppBar(title: Text(task['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warnings.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.danger.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.danger, size: 18),
                      SizedBox(width: 6),
                      Text('Safety Warnings',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ]),
                    const SizedBox(height: 8),
                    ...warnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $w',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.danger,
                                  height: 1.5)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(children: [
              _InfoChip(
                  icon: Icons.timer_outlined,
                  label: task['duration'],
                  color: color),
              const SizedBox(width: 10),
              _InfoChip(
                  icon: Icons.bar_chart,
                  label: task['difficulty'],
                  color: color),
            ]),
            const SizedBox(height: 20),
            const Text('Required Steps',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((e) => _StepTile(
                number: e.key + 1, text: e.value, color: color)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start AR Task'),
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CameraScreen(task: task),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final String text;
  final Color color;
  const _StepTile(
      {required this.number, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
