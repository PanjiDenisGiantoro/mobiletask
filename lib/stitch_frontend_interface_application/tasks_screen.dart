import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'widgets/task_tile.dart';

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

  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Finalize wireframes for onboarding', 'project': 'Mobile App Redesign', 'priority': TaskPriority.high, 'due': 'Today', 'done': false},
    {'title': 'Fix login screen crash on Android', 'project': 'Mobile App Redesign', 'priority': TaskPriority.high, 'due': 'Today', 'done': false},
    {'title': 'Review API documentation', 'project': 'Backend API v2', 'priority': TaskPriority.medium, 'due': 'Today', 'done': true},
    {'title': 'Setup CI/CD pipeline', 'project': 'Backend API v2', 'priority': TaskPriority.medium, 'due': 'May 14', 'done': false},
    {'title': 'Send weekly report to stakeholders', 'project': 'Marketing Campaign Q2', 'priority': TaskPriority.low, 'due': 'Today', 'done': false},
    {'title': 'Design token documentation', 'project': 'Mobile App Redesign', 'priority': TaskPriority.low, 'due': 'May 15', 'done': false},
    {'title': 'Database schema migration', 'project': 'Backend API v2', 'priority': TaskPriority.high, 'due': 'May 14', 'done': false},
    {'title': 'Write unit tests for auth module', 'project': 'Backend API v2', 'priority': TaskPriority.medium, 'due': 'May 16', 'done': true},
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 'All') return _tasks;
    final map = {'High': TaskPriority.high, 'Medium': TaskPriority.medium, 'Low': TaskPriority.low};
    return _tasks.where((t) => t['priority'] == map[_selectedFilter]).toList();
  }

  int get _doneCount => _tasks.where((t) => t['done'] == true).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        backgroundColor: AppColors.primary700,
        title: const Text('Tasks'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent400,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(false),
                _buildTaskList(true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks_fab',
        onPressed: () {},
        backgroundColor: AppColors.primary600,
        child: const Icon(Icons.add, color: Colors.white),
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
                            color: AppColors.primary600)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.primary50,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary600),
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
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
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
                color: selected ? AppColors.primary600 : AppColors.grey100,
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
    final list = _filtered.where((t) => t['done'] == showDone).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showDone ? Icons.check_circle_outline : Icons.task_outlined,
              size: 56,
              color: AppColors.grey400,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              showDone ? 'No completed tasks yet' : 'All tasks done!',
              style: const TextStyle(color: AppColors.grey700, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final task = list[i];
        final globalIndex = _tasks.indexOf(task);
        return TaskTile(
          title: task['title'],
          project: task['project'],
          priority: task['priority'],
          dueDate: task['due'],
          isDone: task['done'],
          onChanged: (val) =>
              setState(() => _tasks[globalIndex]['done'] = val ?? false),
        );
      },
    );
  }
}
