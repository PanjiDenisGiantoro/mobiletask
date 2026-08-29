import 'package:flutter/material.dart';
import '../app_theme.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String category;
  final double progress;
  final int totalTasks;
  final int doneTasks;
  final List<Color> memberColors;
  final String dueDate;
  final Color categoryColor;

  const ProjectCard({
    super.key,
    required this.title,
    required this.category,
    required this.progress,
    required this.totalTasks,
    required this.doneTasks,
    required this.memberColors,
    required this.dueDate,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.more_horiz, color: AppColors.grey400, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.grey900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$doneTasks/$totalTasks Tasks',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey700,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.heroStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.grey100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.heroStart,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildAvatarStack(),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.grey400),
              const SizedBox(width: 4),
              Text(
                dueDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: (memberColors.length * 20.0) + 8,
      height: 28,
      child: Stack(
        children: List.generate(memberColors.length, (i) {
          return Positioned(
            left: i * 20.0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: memberColors[i],
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(Icons.person, size: 14, color: Colors.white),
            ),
          );
        }),
      ),
    );
  }
}
