import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String logoUrl;
  final String deadlineLabel;
  final Color deadlineColor;
  final double progress;
  final int totalTasks;
  final int doneTasks;
  final List<Color> memberColors;
  final int teamCount;
  final String dueDate;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const ProjectCard({
    super.key,
    required this.title,
    this.logoUrl = '',
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.progress,
    required this.totalTasks,
    required this.doneTasks,
    required this.memberColors,
    required this.teamCount,
    required this.dueDate,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: c.isDark
            ? const []
            : [
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
                  color: deadlineColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  deadlineLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deadlineColor,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite ? const Color(0xFFF59E0B) : AppColors.grey400,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildLogo(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$doneTasks/$totalTasks Tasks',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
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
              backgroundColor: c.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.heroStart,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildAvatarStack(),
              const SizedBox(width: 6),
              Text(
                '$teamCount orang',
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: c.textFaint),
              const SizedBox(width: 4),
              Text(
                dueDate,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.heroStart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: logoUrl.isEmpty
          ? const Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: 16)
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(),
              errorWidget: (_, _, _) => const Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: 16),
            ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: (memberColors.length * 14.0) + 14,
      height: 24,
      child: Stack(
        children: List.generate(memberColors.length, (i) {
          return Positioned(
            left: i * 14.0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: memberColors[i],
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(Icons.person, size: 12, color: Colors.white),
            ),
          );
        }),
      ),
    );
  }
}

/// Kartu proyek untuk tampilan grid (responsif, kolom menyesuaikan lebar
/// layar lewat [SliverGridDelegateWithMaxCrossAxisExtent]) — gambar proyek
/// jadi elemen utama, fallback ke ikon kalau tidak ada gambar.
class ProjectGridCard extends StatelessWidget {
  final String title;
  final String logoUrl;
  final String deadlineLabel;
  final Color deadlineColor;
  final double progress;
  final int totalTasks;
  final int doneTasks;
  final int teamCount;
  final String dueDate;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const ProjectGridCard({
    super.key,
    required this.title,
    this.logoUrl = '',
    required this.deadlineLabel,
    required this.deadlineColor,
    required this.progress,
    required this.totalTasks,
    required this.doneTasks,
    required this.teamCount,
    required this.dueDate,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 84,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                logoUrl.isEmpty
                    ? Container(
                        color: AppColors.heroStart.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: const Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: 32),
                      )
                    : CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.heroStart.withValues(alpha: 0.08)),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.heroStart.withValues(alpha: 0.12),
                          alignment: Alignment.center,
                          child: const Icon(Icons.folder_copy_rounded, color: AppColors.primary700, size: 32),
                        ),
                      ),
                if (onToggleFavorite != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onToggleFavorite,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 4),
                          ],
                        ),
                        child: Icon(
                          isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 18,
                          color: isFavorite ? const Color(0xFFF59E0B) : AppColors.grey500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: deadlineColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    deadlineLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: deadlineColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900, height: 1.2),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.grey100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.heroStart),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$doneTasks/$totalTasks',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.grey700),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.heroStart),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 12, color: AppColors.grey400),
                    const SizedBox(width: 2),
                    Text('$teamCount', style: const TextStyle(fontSize: 10.5, color: AppColors.grey700)),
                    const Spacer(),
                    const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.grey400),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        dueDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.grey700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
