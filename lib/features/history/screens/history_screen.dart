import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/firebase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final results = await FirebaseService.getUserResults();
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} '
          '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Recently';
    }
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.success;
    if (score >= 60) return AppTheme.accent;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadResults,
          ),
        ],
      ),
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 80,
              color: AppTheme.textSecondary.withAlpha(((0.3) * 255).round())),
          const SizedBox(height: 16),
          const Text('No results yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Complete a task to see your results here',
            style: TextStyle(
                fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Calculate summary stats
    final totalTasks = _results.length;
    final avgScore = _results.isEmpty
        ? 0
        : (_results.map((r) => r['score'] as int).reduce(
                    (a, b) => a + b) /
                totalTasks)
            .round();
    final bestScore = _results.isEmpty
        ? 0
        : _results
            .map((r) => r['score'] as int)
            .reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            _SummaryItem(
                label: 'Total Tasks',
                value: '$totalTasks',
                icon: Icons.assignment_turned_in),
            _SummaryItem(
                label: 'Avg Score',
                value: '$avgScore%',
                icon: Icons.bar_chart),
            _SummaryItem(
                label: 'Best Score',
                value: '$bestScore%',
                icon: Icons.emoji_events),
          ]),
        ),
        const SizedBox(height: 16),

        const Text('Recent Results',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),

        ..._results.map((result) {
          final score = result['score'] as int;
          final color = _scoreColor(score);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Score circle
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(((0.1) * 255).round()),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: Text('$score%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ),
                const SizedBox(width: 12),

                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result['taskTitle'] ?? 'Task',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${result['completedSteps']}/'
                        '${result['totalSteps']} steps  •  '
                        '${_formatTime(result['timeTakenSeconds'] ?? 0)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(result['completedAt']),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),

                // Grade badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(((0.1) * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    score >= 90
                        ? 'A+'
                        : score >= 80
                            ? 'A'
                            : score >= 70
                                ? 'B'
                                : score >= 60
                                    ? 'C'
                                    : 'D',
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 11)),
      ]),
    );
  }
}
