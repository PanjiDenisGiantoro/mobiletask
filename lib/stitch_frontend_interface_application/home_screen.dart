import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'widgets/stat_card.dart';
import 'widgets/project_card.dart';
import 'widgets/task_tile.dart';
import 'projects_screen.dart';
import 'tasks_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNav = 0;

  final List<Widget> _screens = const [
    _DashboardBody(),
    ProjectsScreen(),
    TasksScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: IndexedStack(
        index: _selectedNav,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedNav == 0
          ? FloatingActionButton(
              heroTag: 'home_fab',
              onPressed: () {},
              backgroundColor: AppColors.primary600,
              child: const Icon(Icons.add, color: AppColors.white),
            )
          : null,
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), activeIcon: Icon(Icons.folder), label: 'Projects'),
      BottomNavigationBarItem(icon: Icon(Icons.task_outlined), activeIcon: Icon(Icons.task), label: 'Tasks'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Messages'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
    ];

    return BottomNavigationBar(
      currentIndex: _selectedNav,
      onTap: (i) => setState(() => _selectedNav = i),
      items: items,
    );
  }
}

// ── Dashboard body (tab index 0) ─────────────────────────────────────────────

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final List<bool> _taskDone = [false, true, false, false];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreeting(),
                const SizedBox(height: AppSpacing.lg),
                _buildStats(),
                const SizedBox(height: AppSpacing.lg),
                _buildSectionHeader('Active Projects'),
                const SizedBox(height: AppSpacing.sm),
                _buildProjectCards(),
                const SizedBox(height: AppSpacing.lg),
                _buildSectionHeader("Today's Tasks"),
                const SizedBox(height: AppSpacing.sm),
                _buildTaskList(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: AppColors.primary700,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Text(
            'ProjectHub',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent400,
            child: const Text(
              'P',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Good morning, Panji 👋',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.grey900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'You have 4 tasks to complete today',
          style: TextStyle(fontSize: 14, color: AppColors.grey700),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.4,
      children: const [
        StatCard(value: '12', label: 'Active Projects', icon: Icons.folder_outlined, color: AppColors.primary600),
        StatCard(value: '48', label: 'Total Tasks', icon: Icons.task_alt_outlined, color: AppColors.accent400),
        StatCard(value: '7', label: 'Completed', icon: Icons.check_circle_outline, color: AppColors.success),
        StatCard(value: '3', label: 'Overdue', icon: Icons.warning_amber_outlined, color: AppColors.error),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.grey900)),
        GestureDetector(
          onTap: () {},
          child: const Text('See all',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary600)),
        ),
      ],
    );
  }

  Widget _buildProjectCards() {
    final projects = [
      {'title': 'Mobile App Redesign', 'category': 'Design', 'progress': 0.65, 'totalTasks': 24, 'doneTasks': 16, 'memberColors': [AppColors.primary600, AppColors.accent400, AppColors.warning], 'dueDate': 'May 20', 'categoryColor': AppColors.info},
      {'title': 'Backend API v2', 'category': 'Development', 'progress': 0.40, 'totalTasks': 18, 'doneTasks': 7, 'memberColors': [AppColors.success, AppColors.primary400], 'dueDate': 'Jun 01', 'categoryColor': AppColors.success},
      {'title': 'Marketing Campaign', 'category': 'Marketing', 'progress': 0.80, 'totalTasks': 10, 'doneTasks': 8, 'memberColors': [AppColors.warning, AppColors.error, AppColors.accent400], 'dueDate': 'May 15', 'categoryColor': AppColors.warning},
    ];
    return Column(
      children: projects.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ProjectCard(
          title: p['title'] as String,
          category: p['category'] as String,
          progress: p['progress'] as double,
          totalTasks: p['totalTasks'] as int,
          doneTasks: p['doneTasks'] as int,
          memberColors: p['memberColors'] as List<Color>,
          dueDate: p['dueDate'] as String,
          categoryColor: p['categoryColor'] as Color,
        ),
      )).toList(),
    );
  }

  Widget _buildTaskList() {
    final tasks = [
      {'title': 'Finalize wireframes for onboarding', 'project': 'Mobile App Redesign', 'priority': TaskPriority.high, 'due': 'Today'},
      {'title': 'Review API documentation', 'project': 'Backend API v2', 'priority': TaskPriority.medium, 'due': 'Today'},
      {'title': 'Send weekly report to stakeholders', 'project': 'Marketing Campaign', 'priority': TaskPriority.low, 'due': 'Today'},
      {'title': 'Fix login screen crash on Android', 'project': 'Mobile App Redesign', 'priority': TaskPriority.high, 'due': 'Today'},
    ];
    return Column(
      children: List.generate(tasks.length, (i) {
        final task = tasks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TaskTile(
            title: task['title'] as String,
            project: task['project'] as String,
            priority: task['priority'] as TaskPriority,
            dueDate: task['due'] as String,
            isDone: _taskDone[i],
            onChanged: (val) => setState(() => _taskDone[i] = val ?? false),
          ),
        );
      }),
    );
  }
}
