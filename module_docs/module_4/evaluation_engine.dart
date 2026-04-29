// ================================================================
// MODULE 4: Practical Evaluation & Safety Feedback
// Research Project: Automobile Learning System
// Vehicle: Maruti Suzuki Alto 800L
// ================================================================
// Input:  Component ID + Task ID + completed steps + time taken
// Output: Performance score + safety warnings + improvement tips
// Technology: AI Scoring System + Safety Rule Engine + Firebase
// ================================================================

class EvaluationEngine {

  // ---- SAFETY RULE ENGINE ----
  // Checks safety rules for each component
  static List<SafetyAlert> checkSafetyRules(
    String component,
    List<String> stepsCompleted,
    Map<String, bool> stepCorrectness,
  ) {
    final alerts = <SafetyAlert>[];
    final rules = _safetyRules[component] ?? [];

    for (final rule in rules) {
      final violated = rule.checkViolation(
        stepsCompleted, stepCorrectness);
      if (violated) {
        alerts.add(SafetyAlert(
          rule: rule.rule,
          severity: rule.severity,
          component: component,
        ));
      }
    }

    return alerts;
  }

  static final Map<String, List<SafetyRule>> _safetyRules = {
    'battery': [
      SafetyRule(
        rule: 'High voltage risk — always remove metal '
            'jewelry before working on battery',
        severity: SafetySeverity.critical,
        checkViolation: (steps, correct) => false,
      ),
      SafetyRule(
        rule: 'NEGATIVE terminal must be disconnected FIRST '
            'to prevent short circuit',
        severity: SafetySeverity.critical,
        checkViolation: (steps, correct) {
          // Check if positive was disconnected before negative
          final posStep = steps.indexOf('BA_04_loosen_positive');
          final negStep = steps.indexOf('BA_02_loosen_negative');
          if (posStep >= 0 && negStep >= 0) {
            return posStep < negStep; // Positive before negative = violation
          }
          return false;
        },
      ),
      SafetyRule(
        rule: 'Battery acid is corrosive — wear gloves '
            'and eye protection',
        severity: SafetySeverity.high,
        checkViolation: (steps, correct) => false,
      ),
    ],
    'spark_plug': [
      SafetyRule(
        rule: 'Engine must be completely COLD — '
            'hot plugs cause severe burns',
        severity: SafetySeverity.critical,
        checkViolation: (steps, correct) => false,
      ),
      SafetyRule(
        rule: 'Do not overtighten spark plug — '
            'can crack the cylinder head',
        severity: SafetySeverity.high,
        checkViolation: (steps, correct) => false,
      ),
    ],
    'coolant': [
      SafetyRule(
        rule: 'NEVER open radiator/reservoir cap on HOT engine '
            '— explosion risk from pressurized steam',
        severity: SafetySeverity.critical,
        checkViolation: (steps, correct) => false,
      ),
      SafetyRule(
        rule: 'Coolant is TOXIC — keep away from '
            'children and animals',
        severity: SafetySeverity.high,
        checkViolation: (steps, correct) => false,
      ),
    ],
    'engine_oil': [
      SafetyRule(
        rule: 'Hot oil causes serious burns — '
            'wait for engine to cool completely',
        severity: SafetySeverity.high,
        checkViolation: (steps, correct) => false,
      ),
    ],
    'air_filter': [
      SafetyRule(
        rule: 'Do not run engine without air filter fitted — '
            'causes engine damage',
        severity: SafetySeverity.medium,
        checkViolation: (steps, correct) => false,
      ),
    ],
  };

  // ---- AI SCORING SYSTEM ----
  static EvaluationReport generateReport({
    required String component,
    required String taskId,
    required int totalSteps,
    required int completedSteps,
    required int timeTakenSeconds,
    required List<String> completedActionNames,
    required Map<String, bool> stepCorrectness,
  }) {
    // Base score from steps completed
    double score = (completedSteps / totalSteps) * 100;

    // Time bonus/penalty
    final expectedTime = _expectedTimes[component] ?? 600;
    if (timeTakenSeconds < expectedTime * 0.8) {
      score = (score + 5).clamp(0, 100); // Bonus for fast
    } else if (timeTakenSeconds > expectedTime * 1.5) {
      score = (score - 5).clamp(0, 100); // Penalty for slow
    }

    // Safety violations penalty
    final safetyAlerts = checkSafetyRules(
      component, completedActionNames, stepCorrectness);
    final criticalViolations = safetyAlerts
        .where((a) => a.severity == SafetySeverity.critical)
        .length;
    score = (score - (criticalViolations * 15)).clamp(0, 100);

    // Grade calculation
    final grade = _calculateGrade(score);
    final feedback = _generateFeedback(score, completedSteps,
        totalSteps, safetyAlerts);
    final tips = _generateTips(score, component,
        completedSteps, totalSteps);

    return EvaluationReport(
      component: component,
      taskId: taskId,
      score: score.toInt(),
      grade: grade,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      timeTakenSeconds: timeTakenSeconds,
      safetyAlerts: safetyAlerts,
      feedback: feedback,
      improvementTips: tips,
    );
  }

  static final Map<String, int> _expectedTimes = {
    'air_filter':  600,  // 10 minutes
    'spark_plug':  900,  // 15 minutes
    'battery':     1200, // 20 minutes
    'engine_oil':  300,  // 5 minutes
    'coolant':     300,  // 5 minutes
  };

  static String _calculateGrade(double score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    return 'D';
  }

  static String _generateFeedback(
    double score,
    int completed,
    int total,
    List<SafetyAlert> alerts,
  ) {
    if (alerts.any((a) => a.severity == SafetySeverity.critical)) {
      return 'Safety violation detected. Please review '
          'safety procedures before attempting again.';
    }
    if (score >= 90) return 'Outstanding! Perfect execution.';
    if (score >= 80) return 'Excellent work! Well done.';
    if (score >= 70) return 'Good job! Minor improvements needed.';
    if (score >= 60) return 'Satisfactory. Practice more.';
    return 'Needs significant improvement. Review the steps.';
  }

  static List<String> _generateTips(
    double score,
    String component,
    int completed,
    int total,
  ) {
    final tips = <String>[];
    if (completed < total) {
      tips.add('Complete all ${total - completed} remaining steps');
    }
    if (score < 80) {
      tips.add('Review the step sequence before next attempt');
      tips.add('Pay attention to tool orientation and placement');
    }
    if (score >= 80) {
      tips.add('Try to improve your completion time');
      tips.add('Help other students with this procedure');
    }

    // Component-specific tips
    final componentTips = {
      'battery': 'Always remember: NEGATIVE terminal first',
      'spark_plug': 'Use correct torque when reinstalling plug',
      'coolant': 'Always check engine is cold before opening',
      'engine_oil': 'Check oil level twice for accuracy',
      'air_filter': 'Hold filter to light to check blockage',
    };
    if (componentTips.containsKey(component)) {
      tips.add(componentTips[component]!);
    }

    return tips;
  }
}

// Data models for Module 4
class SafetyRule {
  final String rule;
  final SafetySeverity severity;
  final bool Function(List<String>, Map<String, bool>) checkViolation;

  const SafetyRule({
    required this.rule,
    required this.severity,
    required this.checkViolation,
  });
}

enum SafetySeverity { critical, high, medium, low }

class SafetyAlert {
  final String rule;
  final SafetySeverity severity;
  final String component;

  const SafetyAlert({
    required this.rule,
    required this.severity,
    required this.component,
  });
}

class EvaluationReport {
  final String component;
  final String taskId;
  final int score;
  final String grade;
  final int completedSteps;
  final int totalSteps;
  final int timeTakenSeconds;
  final List<SafetyAlert> safetyAlerts;
  final String feedback;
  final List<String> improvementTips;

  const EvaluationReport({
    required this.component,
    required this.taskId,
    required this.score,
    required this.grade,
    required this.completedSteps,
    required this.totalSteps,
    required this.timeTakenSeconds,
    required this.safetyAlerts,
    required this.feedback,
    required this.improvementTips,
  });

  // Output saved to Firebase
  Map<String, dynamic> toFirestore() => {
    'component': component,
    'taskId': taskId,
    'score': score,
    'grade': grade,
    'completedSteps': completedSteps,
    'totalSteps': totalSteps,
    'timeTakenSeconds': timeTakenSeconds,
    'safetyViolations': safetyAlerts.length,
    'feedback': feedback,
    'improvementTips': improvementTips,
  };
}
