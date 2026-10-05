import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import 'add_task_form_sheet.dart';
import '../theme/app_theme.dart';
import '../data/task_repository.dart';
import '../widgets/skeleton_list.dart';
import '../widgets/task_tile.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'High', 'Medium', 'Low'];

  List<TaskEntry> get _tasks => TaskRepository.instance.tasks;

  List<TaskEntry> get _filtered {
    if (_selectedFilter == 'All') return _tasks;
    final map = {'High': TaskPriority.high, 'Medium': TaskPriority.medium, 'Low': TaskPriority.low};
    return _tasks.where((t) {
      // Prioritas urgent dikelompokkan ke filter High.
      if (_selectedFilter == 'High') return t.priority == TaskPriority.high || t.priority == TaskPriority.urgent;
      return t.priority == map[_selectedFilter];
    }).toList();
  }

  int get _doneCount => _tasks.where((t) => t.done).length;

  bool get _loading => PhStore.instance.syncing && _tasks.isEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    TaskRepository.instance.addListener(_onTasksChanged);
    PhStore.instance.addListener(_onTasksChanged);
    if (!PhStore.instance.synced) PhStore.instance.sync();
  }

  void _onTasksChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> action) async {
    try {
      await action;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    TaskRepository.instance.removeListener(_onTasksChanged);
    PhStore.instance.removeListener(_onTasksChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'To Do'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProgressBanner(),
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? const SkeletonList()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(false),
                      _buildTaskList(true),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          heroTag: 'tasks_fab',
          onPressed: () => showAddTaskFormSheet(context),
          backgroundColor: AppColors.heroStart,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProgressBanner() {
    final total = _tasks.length;
    final progress = _doneCount / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_doneCount of $total tasks done',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700)),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.heroStart)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.grey100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.heroStart),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      color: AppColors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final selected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: selected ? AppColors.heroStart : AppColors.grey100,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : AppColors.grey700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList(bool showDone) {
    final list = _filtered.where((t) => t.done == showDone).toList();

    if (list.isEmpty) {
      final error = PhStore.instance.syncError;
      return RefreshIndicator(
        onRefresh: PhStore.instance.sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 120),
          children: [
            Icon(
              showDone ? Icons.check_circle_outline : Icons.task_outlined,
              size: 56,
              color: AppColors.grey400,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error ?? (showDone ? 'No completed tasks yet' : 'All tasks done!'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey700, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: PhStore.instance.sync,
      child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100,
      ),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final task = list[i];
        return Slidable(
          key: ValueKey(task),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => _run(PhStore.instance.deleteTask(task)),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline_rounded,
                label: 'Hapus',
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/task/${task.id}'),
            child: TaskTile(
              title: task.title,
              project: task.project,
              priority: task.priority,
              dueDate: task.due,
              isDone: task.done,
              type: task.type,
              photo: task.photo,
              onChanged: (val) =>
                  _run(PhStore.instance.setTaskStatus(task, (val ?? false) ? 'done' : 'todo')),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 40 * i), duration: 250.ms).slideY(begin: 0.08, end: 0);
      },
    ),
    );
  }
}
