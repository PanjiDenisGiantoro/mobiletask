import 'package:flutter/material.dart';
import '../app_theme.dart';

enum ActivityType { sprint, task, recurring, bugTicket }

extension ActivityTypeX on ActivityType {
  String get label => switch (this) {
        ActivityType.sprint => 'Sprint',
        ActivityType.task => 'Task',
        ActivityType.recurring => 'Recurring',
        ActivityType.bugTicket => 'Bug Ticket',
      };

  Color get color => switch (this) {
        ActivityType.sprint => AppColors.info,
        ActivityType.task => AppColors.heroStart,
        ActivityType.recurring => AppColors.success,
        ActivityType.bugTicket => AppColors.error,
      };

  IconData get icon => switch (this) {
        ActivityType.sprint => Icons.speed_rounded,
        ActivityType.task => Icons.task_alt_rounded,
        ActivityType.recurring => Icons.repeat_rounded,
        ActivityType.bugTicket => Icons.bug_report_rounded,
      };
}
