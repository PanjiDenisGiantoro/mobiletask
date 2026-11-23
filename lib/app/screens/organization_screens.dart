import 'package:flutter/material.dart';
import '../data/admin_api_repository.dart';
import '../data/ph_store.dart';
import '../theme/app_theme.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

/// Halaman "Perusahaan" — Admin & Pengaturan -> Organization & Access -> Perusahaan.
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  String _companyName = 'PT Cek';
  String _industry = 'Technology & Software Development';
  String _email = 'admin@flovig.com';
  String _phone = '+62 21 5550 1234';
  String _address = 'Jakarta Selatan, DKI Jakarta';
  String _website = 'https://flovig.com';

  PhStore get _store => PhStore.instance;

  Future<void> _editCompany() async {
    await openPhForm(
      context,
      PhFormConfig(
        title: 'Edit Profil Perusahaan',
        saveLabel: 'Simpan Perubahan',
        doneMessage: 'Profil perusahaan diperbarui',
        fields: [
          PhField('name', 'Nama Perusahaan', required: true, initial: _companyName),
          PhField('industry', 'Bidang Usaha', initial: _industry),
          PhField('email', 'Email Resmi', required: true, initial: _email),
          PhField('phone', 'Nomor Telepon', initial: _phone),
          PhField('address', 'Alamat', type: PhFieldType.multiline, initial: _address),
          PhField('website', 'Website', initial: _website),
        ],
        onSave: (v) {
          if (mounted) {
            setState(() {
              _companyName = '${v['name'] ?? _companyName}';
              _industry = '${v['industry'] ?? _industry}';
              _email = '${v['email'] ?? _email}';
              _phone = '${v['phone'] ?? _phone}';
              _address = '${v['address'] ?? _address}';
              _website = '${v['website'] ?? _website}';
            });
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffCount = _store.staff.length;
    final clientCount = _store.clients.length;
    final projectCount = _store.projects.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.heroStart,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.heroStart, AppColors.heroMid],
            ),
          ),
        ),
        title: const Text('Perusahaan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF0F7FF)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _companyName,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _industry,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _editCompany,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _miniStat('$staffCount', 'Anggota Tim', const Color(0xFF2563EB))),
                    const SizedBox(width: 10),
                    Expanded(child: _miniStat('$clientCount', 'Klien Aktif', const Color(0xFF16A34A))),
                    const SizedBox(width: 10),
                    Expanded(child: _miniStat('$projectCount', 'Total Proyek', const Color(0xFF7C3AED))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PhCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Organisasi',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                _infoRow(Icons.email_outlined, 'Email Resmi', _email),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _infoRow(Icons.phone_outlined, 'Nomor Telepon', _phone),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _infoRow(Icons.language_rounded, 'Website', _website),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _infoRow(Icons.location_on_outlined, 'Alamat', _address),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}

/// Halaman "Roles" — terhubung ke API `/roles`.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final _api = AdminApiRepository.instance;
  List<ApiRole> _roles = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchRoles(search: _search);
      if (mounted) setState(() => _roles = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRoleForm([ApiRole? existing]) async {
    await openPhForm(
      context,
      PhFormConfig(
        title: existing == null ? 'Tambah Role Baru' : 'Edit Role',
        note: 'Gunakan huruf kecil, angka, "-" atau "_". Role baru menyalin permission default dari role member.',
        saveLabel: existing == null ? 'Simpan Role' : 'Perbarui Role',
        doneMessage: existing == null ? 'Role berhasil dibuat' : 'Role diperbarui',
        fields: [
          PhField('name', 'Nama Role', required: true, hint: 'contoh: finance', initial: existing?.name ?? ''),
        ],
        onSave: (v) async {
          final name = '${v['name'] ?? ''}'.trim();
          if (existing == null) {
            await _api.createRole(name);
          } else {
            await _api.updateRole(existing.id, name);
          }
          await _load();
          return null;
        },
      ),
    );
  }

  Future<void> _deleteRole(ApiRole role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Role'),
        content: Text('Yakin ingin menghapus role "${role.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteRole(role.id);
      await _load();
      if (mounted) phToast(context, 'Role "${role.label}" dihapus');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Roles', actions: [
        IconButton(tooltip: 'Muat ulang', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.white, Color(0xFFF0F7FF)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Manajemen Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                        const SizedBox(height: 3),
                        Text('${_roles.length} role tersedia di perusahaan Anda.', style: const TextStyle(fontSize: 12.5, color: AppColors.grey500)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openRoleForm(),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary600, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Tambah Role', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) {
                _search = v;
                _load();
              },
              decoration: InputDecoration(
                hintText: 'Cari nama role...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.grey400),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              PhCard(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
            else if (_roles.isEmpty)
              const PhCard(child: Center(child: Text('Belum ada role.', style: TextStyle(color: AppColors.grey500))))
            else
              for (final role in _roles) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (role.isSystem ? AppColors.primary600 : const Color(0xFF7C3AED)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.admin_panel_settings_rounded, size: 20, color: role.isSystem ? AppColors.primary600 : const Color(0xFF7C3AED)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(role.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                                PhPill(
                                  role.isSystem ? 'System' : 'Custom',
                                  fg: role.isSystem ? AppColors.primary700 : const Color(0xFF7C3AED),
                                  bg: role.isSystem ? AppColors.primary50 : const Color(0xFFF3E8FF),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('${role.name} · ${role.usersCount} pengguna', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                          ],
                        ),
                      ),
                      if (role.canEdit)
                        IconButton(tooltip: 'Edit Role', onPressed: () => _openRoleForm(role), icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primary600)),
                      if (role.canDelete)
                        IconButton(tooltip: 'Hapus Role', onPressed: () => _deleteRole(role), icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.error)),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Halaman "Permissions" — terhubung ke API `/permissions`.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final _api = AdminApiRepository.instance;
  ApiPermissionsData? _data;
  String _selectedRoleName = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchPermissions();
      if (mounted) {
        setState(() {
          _data = res;
          if (_selectedRoleName.isEmpty && res.roles.isNotEmpty) {
            _selectedRoleName = res.roles.first.name;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ApiPermRole? get _currentRole =>
      _data?.roles.where((r) => r.name == _selectedRoleName).firstOrNull;

  Future<void> _save() async {
    final role = _currentRole;
    if (role == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _api.savePermissions(role.name, role.permissions.toList());
      if (mounted) {
        setState(() {
          role.isCustomized = true;
          role.permissions
            ..clear()
            ..addAll(saved);
        });
        phToast(context, 'Permission untuk role ${role.label} disimpan');
      }
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final role = _currentRole;
    if (role == null || _saving) return;
    setState(() => _saving = true);
    try {
      final resetList = await _api.resetPermissions(role.name);
      if (mounted) {
        setState(() {
          role.isCustomized = false;
          role.permissions
            ..clear()
            ..addAll(resetList);
        });
        phToast(context, 'Permission ${role.label} dikembalikan ke default');
      }
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final role = _currentRole;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar('Permissions', actions: [
        if (role != null) ...[
          TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text('Reset', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '...' : 'Simpan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (data != null && data.note.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDBEAFE))),
                          child: Text(data.note, style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (data != null)
                        PhCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Pilih Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                                  if (role != null && role.isCustomized)
                                    const PhPill('Customized', fg: Color(0xFF1D4ED8), bg: Color(0xFFDBEAFE)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final r in data.roles)
                                    ChoiceChip(
                                      label: Text(r.label),
                                      selected: _selectedRoleName == r.name,
                                      onSelected: (_) => setState(() => _selectedRoleName = r.name),
                                      selectedColor: AppColors.primary600,
                                      backgroundColor: AppColors.bg,
                                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _selectedRoleName == r.name ? Colors.white : AppColors.grey700),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (data != null && role != null)
                        for (final grp in data.groups) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                                  decoration: const BoxDecoration(
                                    color: AppColors.bg,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    border: Border(bottom: BorderSide(color: AppColors.border)),
                                  ),
                                  child: Text(grp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                                ),
                                for (var i = 0; i < grp.permissions.length; i++) ...[
                                  if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  SwitchListTile(
                                    dense: true,
                                    activeThumbColor: AppColors.primary600,
                                    title: Text(grp.permissions[i].label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                                    subtitle: Text(grp.permissions[i].name, style: const TextStyle(fontSize: 11, color: AppColors.grey400)),
                                    value: role.permissions.contains(grp.permissions[i].name),
                                    onChanged: (val) => setState(() {
                                      if (val) {
                                        role.permissions.add(grp.permissions[i].name);
                                      } else {
                                        role.permissions.remove(grp.permissions[i].name);
                                      }
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
    );
  }
}
