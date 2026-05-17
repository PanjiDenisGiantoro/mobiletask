import 'package:flutter/material.dart';
import '../app_theme.dart';

enum TaskPriority { high, medium, low }

class TaskTile extends StatelessWidget {
  final String title;
  final String project;
  final TaskPriority priority;
  final String dueDate;
  final bool isDone;
  final ValueChanged<bool?> onChanged;

  const TaskTile({
    super.key,
    required this.title,
    required this.project,
    required this.priority,
    required this.dueDate,
    required this.isDone,
    required this.onChanged,
  });

  Color get _priorityColor => switch (priority) {
        TaskPriority.high   => AppColors.error,
        TaskPriority.medium => AppColors.warning,
        TaskPriority.low    => AppColors.success,
      };

  String get _priorityLabel => switch (priority) {
        TaskPriority.high   => 'High',
        TaskPriority.medium => 'Medium',
        TaskPriority.low    => 'Low',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            onChanged: onChanged,
            activeColor: AppColors.primary600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey900,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.grey400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  project,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _priorityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _priorityColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dueDate,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.grey400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
