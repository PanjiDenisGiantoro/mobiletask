import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

/// Halaman daftar Member & Client dengan pencarian dan filter (Semua / Member / Client).
class MembersClientsScreen extends StatefulWidget {
  final String initialFilter; // all | member | client
  const MembersClientsScreen({super.key, this.initialFilter = 'all'});

  @override
  State<MembersClientsScreen> createState() => _MembersClientsScreenState();
}

class _MembersClientsScreenState extends State<MembersClientsScreen> {
  final _searchCtrl = TextEditingController();
  late String _filter;

  PhStore get _store => PhStore.instance;

  @override
  void initState() {
    super.initState();
    _filter = (widget.initialFilter == 'member' || widget.initialFilter == 'client')
        ? widget.initialFilter
        : 'all';
    _store.addListener(_onStoreChanged);
    if (!_store.synced) _store.sync();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PhUser> get _allUsers {
    final list = _store.users.values.toList();
    list.sort((a, b) {
      if (a.isClient != b.isClient) return a.isClient ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  List<PhUser> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allUsers.where((u) {
      if (_filter == 'member' && u.isClient) return false;
      if (_filter == 'client' && !u.isClient) return false;
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = _allUsers;
    final memberCount = all.where((u) => !u.isClient).length;
    final clientCount = all.where((u) => u.isClient).length;
    final items = _filtered;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: phAppBar(S.tr('Member & Client', 'Members & Clients')),
      body: RefreshIndicator(
        onRefresh: _store.sync,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: c.bg,
                      hintText: S.tr(
                        'Cari nama, email, atau role...',
                        'Search name, email, or role...',
                      ),
                      hintStyle: TextStyle(fontSize: 13, color: c.textFaint),
                      prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded, color: c.textMuted),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _filterChip(
                        context: context,
                        key: 'all',
                        label: '${S.tr('Semua', 'All')} (${all.length})',
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        context: context,
                        key: 'member',
                        label: 'Member ($memberCount)',
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        context: context,
                        key: 'client',
                        label: 'Client ($clientCount)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Icon(Icons.groups_outlined, size: 48, color: c.textFaint),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            S.tr('Tidak ada data yang cocok', 'No matching people found'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _buildUserCard(context, items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String key,
    required String label,
  }) {
    final c = context.colors;
    final selected = _filter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary600 : c.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.primary600 : c.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, PhUser u) {
    final c = context.colors;
    final typeLabel = u.isClient
        ? 'Client'
        : (u.role.isNotEmpty
            ? '${u.role[0].toUpperCase()}${u.role.substring(1)}'
            : 'Member');
    final badgeFg = u.isClient ? const Color(0xFFD97706) : c.primary;
    final badgeBg = u.isClient ? c.warningBg : c.primarySoft;

    return PhCard(
      onTap: () => showMemberClientDetailSheet(context, u),
      child: Row(
        children: [
          PhAvatar(u.id, size: 46, imageUrl: u.photoUrl, images: u.images),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    PhPill(typeLabel, fg: badgeFg, bg: badgeBg),
                  ],
                ),
                if (u.email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: u.isActive ? AppColors.success : c.textFaint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      u.isActive ? S.tr('Aktif', 'Active') : S.tr('Nonaktif', 'Inactive'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: u.isActive ? AppColors.success : c.textMuted,
                      ),
                    ),
                    if (u.joinedAt.isNotEmpty) ...[
                      Text(' • ', style: TextStyle(color: c.textFaint)),
                      Flexible(
                        child: Text(
                          fmtDate(u.joinedAt),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _circleActionBtn(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            color: c.primary,
            bg: c.primarySoft,
            tooltip: S.tr('Kirim Pesan', 'Message'),
            onTap: () => openMemberMessage(context, u),
          ),
        ],
      ),
    );
  }

  Widget _circleActionBtn({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Color bg,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

/// Membuka chat langsung (DM) dengan [u].
void openMemberMessage(BuildContext context, PhUser u) {
  context.push('/thread/${Uri.encodeComponent('dm:${u.id}')}');
}

/// Bottom sheet detail Member/Client dengan tombol Kirim Pesan.
void showMemberClientDetailSheet(BuildContext context, PhUser u) {
  final c = context.colors;
  final typeLabel = u.isClient
      ? 'Client'
      : (u.role.isNotEmpty
          ? '${u.role[0].toUpperCase()}${u.role.substring(1)}'
          : 'Member');
  final badgeFg = u.isClient ? const Color(0xFFD97706) : c.primary;
  final badgeBg = u.isClient ? c.warningBg : c.primarySoft;
  final relatedProjects = PhStore.instance.projects
      .where((p) => p.clientId == u.id || p.members.any((m) => m.userId == u.id))
      .length;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            PhAvatar(u.id, size: 68, imageUrl: u.photoUrl, images: u.images),
            const SizedBox(height: 12),
            Text(
              u.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            PhPill(typeLabel, fg: badgeFg, bg: badgeBg),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  openMemberMessage(context, u);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: Text(S.tr('Kirim Pesan', 'Message'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),
            KvCard([
              ('Email', u.email),
              if (u.phone.isNotEmpty) (S.tr('Telepon', 'Phone'), u.phone),
              (S.tr('Kategori', 'Category'), u.isClient ? 'Client' : 'Member'),
              ('Status', u.isActive ? S.tr('Aktif', 'Active') : S.tr('Nonaktif', 'Inactive')),
              (S.tr('Proyek Terkait', 'Related Projects'), '$relatedProjects'),
              if (u.joinedAt.isNotEmpty) (S.tr('Bergabung', 'Joined'), fmtDate(u.joinedAt)),
            ]),
          ],
        ),
      ),
    ),
  );
}
