import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'widgets/project_card.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _projects = [
    {
      'title': 'Mobile App Redesign',
      'category': 'Design',
      'progress': 0.65,
      'totalTasks': 24,
      'doneTasks': 16,
      'memberColors': [AppColors.primary600, AppColors.accent400, AppColors.warning],
      'dueDate': 'May 20',
      'categoryColor': AppColors.info,
      'status': 'active',
    },
    {
      'title': 'Backend API v2',
      'category': 'Development',
      'progress': 0.40,
      'totalTasks': 18,
      'doneTasks': 7,
      'memberColors': [AppColors.success, AppColors.primary400],
      'dueDate': 'Jun 01',
      'categoryColor': AppColors.success,
      'status': 'active',
    },
    {
      'title': 'Marketing Campaign Q2',
      'category': 'Marketing',
      'progress': 0.80,
      'totalTasks': 10,
      'doneTasks': 8,
      'memberColors': [AppColors.warning, AppColors.error, AppColors.accent400],
      'dueDate': 'May 15',
      'categoryColor': AppColors.warning,
      'status': 'active',
    },
    {
      'title': 'Website Revamp',
      'category': 'Design',
      'progress': 1.0,
      'totalTasks': 30,
      'doneTasks': 30,
      'memberColors': [AppColors.primary600, AppColors.success],
      'dueDate': 'Apr 30',
      'categoryColor': AppColors.info,
      'status': 'completed',
    },
    {
      'title': 'CRM Integration',
      'category': 'Development',
      'progress': 1.0,
      'totalTasks': 15,
      'doneTasks': 15,
      'memberColors': [AppColors.accent400, AppColors.primary400],
      'dueDate': 'Apr 10',
      'categoryColor': AppColors.success,
      'status': 'completed',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(String status) {
    return _projects.where((p) {
      final matchStatus = status == 'all' || p['status'] == status;
      final matchSearch = p['title']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        backgroundColor: AppColors.primary700,
        title: const Text('Projects'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent400,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectList(_filtered('all')),
                _buildProjectList(_filtered('active')),
                _buildProjectList(_filtered('completed')),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Project',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search projects...',
          hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
          filled: true,
          fillColor: AppColors.grey100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 56, color: AppColors.grey400),
            SizedBox(height: AppSpacing.sm),
            Text('No projects found',
                style: TextStyle(color: AppColors.grey700, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final p = list[i];
        return ProjectCard(
          title: p['title'],
          category: p['category'],
          progress: p['progress'],
          totalTasks: p['totalTasks'],
          doneTasks: p['doneTasks'],
          memberColors: p['memberColors'],
          dueDate: p['dueDate'],
          categoryColor: p['categoryColor'],
        );
      },
    );
  }
}
