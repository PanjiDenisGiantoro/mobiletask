import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'activity_type.dart';

enum TaskPriority { urgent, high, medium, low }

class TaskTile extends StatelessWidget {
  final String title;
  final String project;
  final TaskPriority priority;
  final String dueDate;
  final bool isDone;
  final ValueChanged<bool?> onChanged;
  final ActivityType? type;
  final Uint8List? photo;

  const TaskTile({
    super.key,
    required this.title,
    required this.project,
    required this.priority,
    required this.dueDate,
    required this.isDone,
    required this.onChanged,
    this.type,
    this.photo,
  });

  Color get _priorityColor => switch (priority) {
        TaskPriority.urgent => AppColors.error,
        TaskPriority.high   => AppColors.error,
        TaskPriority.medium => AppColors.warning,
        TaskPriority.low    => AppColors.success,
      };

  String get _priorityLabel => switch (priority) {
        TaskPriority.urgent => 'Urgent',
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
            color: Colors.black.withValues(alpha: 0.04),
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
            activeColor: AppColors.heroStart,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(photo!, width: 34, height: 34, fit: BoxFit.cover),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
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
                if (type != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type!.icon, size: 11, color: type!.color),
                      const SizedBox(width: 3),
                      Text(
                        type!.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: type!.color,
                        ),
                      ),
                    ],
                  )
                else
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
                  color: _priorityColor.withValues(alpha: 0.1),
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
