import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../utils/ph_format.dart';
import 'ph_forms_project.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/project_card.dart';
import '../widgets/skeleton_list.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _categoryFilter;

  /// Daftar proyek dibaca dari [PhStore] (tabel projects) supaya proyek baru
  /// dan hasil ubah dari Detail Proyek langsung tampil di sini.
  List<Map<String, dynamic>> get _projects => PhStore.instance.projects.map((p) {
        final color = switch (p.category) {
          'Development' || 'Internal' => AppColors.success,
          'Marketing' => AppColors.warning,
          _ => AppColors.info,
        };
        return <String, dynamic>{
          'id': p.id,
          'title': p.name,
          'category': p.category,
          'progress': p.totalTasks > 0 ? p.doneTasks / p.totalTasks : p.progress / 100,
          'totalTasks': p.totalTasks,
          'doneTasks': p.doneTasks,
          'memberColors': p.memberColors.map(Color.new).toList(),
          'dueDate': fmtDate(p.endDate),
          'categoryColor': color,
          'status': p.completed ? 'completed' : 'active',
        };
      }).toList();

  bool get _loading => PhStore.instance.syncing && PhStore.instance.projects.isEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PhStore.instance.addListener(_onStoreChanged);
    if (!PhStore.instance.synced) PhStore.instance.sync();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PhStore.instance.removeListener(_onStoreChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _projects.map((p) => p['category'] as String).toSet().toList()..sort();

  List<Map<String, dynamic>> _filtered(String status) {
    return _projects.where((p) {
      final matchStatus = status == 'all' || p['status'] == status;
      final matchSearch = p['title']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final matchCategory = _categoryFilter == null || p['category'] == _categoryFilter;
      return matchStatus && matchSearch && matchCategory;
    }).toList();
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
        title: const Text('Projects'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: DropdownButton2<String>(
              value: _categoryFilter,
              hint: const Text('Semua', style: TextStyle(color: Colors.white, fontSize: 13)),
              underline: const SizedBox.shrink(),
              iconStyleData: const IconStyleData(icon: Icon(Icons.filter_list, color: Colors.white)),
              buttonStyleData: const ButtonStyleData(padding: EdgeInsets.symmetric(horizontal: 4)),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _categoryFilter = v),
              selectedItemBuilder: (context) => [
                const Text('Semua', style: TextStyle(color: Colors.white, fontSize: 13)),
                ..._categories.map((c) => Text(c, style: const TextStyle(color: Colors.white, fontSize: 13))),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const SkeletonList(itemHeight: 96)
                : TabBarView(
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          heroTag: 'projects_fab',
          onPressed: () => openProjectForm(context),
          backgroundColor: AppColors.heroStart,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Project',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TypeAheadField<String>(
        controller: _searchController,
        suggestionsCallback: (pattern) {
          if (pattern.isEmpty) return const [];
          return _projects
              .map((p) => p['title'] as String)
              .where((title) => title.toLowerCase().contains(pattern.toLowerCase()))
              .toList();
        },
        onSelected: (suggestion) {
          _searchController.text = suggestion;
          setState(() => _searchQuery = suggestion);
        },
        itemBuilder: (context, suggestion) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(suggestion, style: const TextStyle(fontSize: 13.5, color: AppColors.grey900)),
        ),
        emptyBuilder: (context) => const SizedBox.shrink(),
        builder: (context, controller, focusNode) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
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
          );
        },
      ),
    );
  }

  Widget _buildProjectList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: PhStore.instance.sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 120),
          children: [
            const Icon(Icons.folder_off_outlined, size: 56, color: AppColors.grey400),
            const SizedBox(height: AppSpacing.sm),
            Text(PhStore.instance.syncError ?? 'No projects found',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey700, fontSize: 14)),
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
        final p = list[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/project/${p['id']}'),
          child: ProjectCard(
            title: p['title'],
            category: p['category'],
            progress: p['progress'],
            totalTasks: p['totalTasks'],
            doneTasks: p['doneTasks'],
            memberColors: p['memberColors'],
            dueDate: p['dueDate'],
            categoryColor: p['categoryColor'],
          ),
        );
      },
    ),
    );
  }
}
