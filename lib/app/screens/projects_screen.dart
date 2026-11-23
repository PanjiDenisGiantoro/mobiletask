import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../l10n/app_strings.dart';
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
  bool _gridView = true;

  /// Label & warna urgensi tenggat: Terlambat / Hari ini / Minggu ini /
  /// Bulan ini / tanggal langsung kalau masih jauh.
  (String, Color) _deadlineInfo(String isoEndDate) {
    final due = DateTime.tryParse(isoEndDate);
    if (due == null) return ('Tanpa tenggat', AppColors.grey500);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(due.year, due.month, due.day);
    final days = dueOnly.difference(todayOnly).inDays;
    if (days < 0) return ('Terlambat', AppColors.error);
    if (days == 0) return ('Hari ini', AppColors.error);
    if (days <= 7) return ('Minggu ini', AppColors.warning);
    if (dueOnly.year == todayOnly.year && dueOnly.month == todayOnly.month) return ('Bulan ini', AppColors.info);
    return (fmtDate(isoEndDate), AppColors.grey700);
  }

  /// Daftar proyek dibaca dari [PhStore] (tabel projects) supaya proyek baru
  /// dan hasil ubah dari Detail Proyek langsung tampil di sini.
  List<Map<String, dynamic>> get _projects => PhStore.instance.projects.map((p) {
        final (deadlineLabel, deadlineColor) = _deadlineInfo(p.endDate);
        return <String, dynamic>{
          'id': p.id,
          'title': p.name,
          'category': p.category,
          'logoUrl': p.logoUrl,
          'progress': p.totalTasks > 0 ? p.doneTasks / p.totalTasks : p.progress / 100,
          'totalTasks': p.totalTasks,
          'doneTasks': p.doneTasks,
          'memberColors': p.memberColors.map(Color.new).toList(),
          'teamCount': p.members.length,
          'dueDate': fmtDate(p.endDate),
          'deadlineLabel': deadlineLabel,
          'deadlineColor': deadlineColor,
          'status': p.status,
        };
      }).toList();

  bool get _loading => PhStore.instance.syncing && PhStore.instance.projects.isEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    PhStore.instance.addListener(_onStoreChanged);
    PhStore.instance.loadFavoriteProjects();
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

  List<String> get _categories => _projects
      .map((p) => (p['category'] as String).trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

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
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
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
        title: Text(S.of(context).navProjects),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Draft'),
            Tab(text: 'Active'),
            Tab(text: 'On Hold'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _gridView ? S.tr('Tampilan list', 'List view') : S.tr('Tampilan grid', 'Grid view'),
            icon: Icon(_gridView ? Icons.view_list_rounded : Icons.grid_view_rounded, color: Colors.white),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: S.tr('Filter kategori', 'Filter category'),
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  onPressed: () => _showCategoryFilterSheet(context),
                ),
                if (_categoryFilter != null)
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.heroMid, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndCategoryBar(),
          Expanded(
            child: _loading
                ? const SkeletonList(itemHeight: 96)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProjectList(_filtered('all')),
                      _buildProjectList(_filtered('draft')),
                      _buildProjectList(_filtered('active')),
                      _buildProjectList(_filtered('on_hold')),
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
          label: Text(
            S.tr('Proyek Baru', 'New Project'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndCategoryBar() {
    final c = context.colors;
    final cats = _categories;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypeAheadField<String>(
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
              child: Text(suggestion, style: TextStyle(fontSize: 13.5, color: c.textPrimary)),
            ),
            emptyBuilder: (context) => const SizedBox.shrink(),
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: S.tr('Cari proyek...', 'Search projects...'),
                  hintStyle: TextStyle(color: c.textFaint, fontSize: 13.5),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded, color: c.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              );
            },
          ),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(
                    context: context,
                    label: S.tr('Semua', 'All'),
                    count: _projects.length,
                    selected: _categoryFilter == null,
                    onTap: () => setState(() => _categoryFilter = null),
                  ),
                  for (final cat in cats)
                    _categoryChip(
                      context: context,
                      label: cat,
                      count: _projects.where((p) => (p['category'] as String).trim() == cat).length,
                      selected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter = _categoryFilter == cat ? null : cat),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryChip({
    required BuildContext context,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary600 : c.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary600 : c.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : c.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : c.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : c.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryFilterSheet(BuildContext context) {
    final c = context.colors;
    final cats = _categories;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.category_outlined, color: c.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.tr('Filter Kategori Proyek', 'Filter Project Category'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                  ),
                  if (_categoryFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _categoryFilter = null);
                        Navigator.pop(sheetCtx);
                      },
                      child: Text(S.tr('Reset', 'Reset')),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _categoryChip(
                    context: sheetCtx,
                    label: S.tr('Semua Kategori', 'All Categories'),
                    count: _projects.length,
                    selected: _categoryFilter == null,
                    onTap: () {
                      setState(() => _categoryFilter = null);
                      Navigator.pop(sheetCtx);
                    },
                  ),
                  for (final cat in cats)
                    _categoryChip(
                      context: sheetCtx,
                      label: cat,
                      count: _projects.where((p) => (p['category'] as String).trim() == cat).length,
                      selected: _categoryFilter == cat,
                      onTap: () {
                        setState(() => _categoryFilter = cat);
                        Navigator.pop(sheetCtx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
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
      child: _gridView ? _buildProjectGrid(list) : _buildProjectListView(list),
    );
  }

  Widget _buildProjectListView(List<Map<String, dynamic>> list) {
    return ListView.separated(
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
        final pid = p['id'] as int;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/project/$pid'),
          child: ProjectCard(
            title: p['title'],
            logoUrl: p['logoUrl'],
            deadlineLabel: p['deadlineLabel'],
            deadlineColor: p['deadlineColor'],
            progress: p['progress'],
            totalTasks: p['totalTasks'],
            doneTasks: p['doneTasks'],
            memberColors: p['memberColors'],
            teamCount: p['teamCount'],
            dueDate: p['dueDate'],
            isFavorite: PhStore.instance.isFavoriteProject(pid),
            onToggleFavorite: () => PhStore.instance.toggleFavoriteProject(pid),
          ),
        );
      },
    );
  }

  /// Grid responsif: jumlah kolom menyesuaikan lebar layar (HP ~2 kolom,
  /// tablet/layar lebar otomatis lebih banyak kolom).
  Widget _buildProjectGrid(List<Map<String, dynamic>> list) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        final pid = p['id'] as int;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/project/$pid'),
          child: ProjectGridCard(
            title: p['title'],
            logoUrl: p['logoUrl'],
            deadlineLabel: p['deadlineLabel'],
            deadlineColor: p['deadlineColor'],
            progress: p['progress'],
            totalTasks: p['totalTasks'],
            doneTasks: p['doneTasks'],
            teamCount: p['teamCount'],
            dueDate: p['dueDate'],
            isFavorite: PhStore.instance.isFavoriteProject(pid),
            onToggleFavorite: () => PhStore.instance.toggleFavoriteProject(pid),
          ),
        );
      },
    );
  }
}
