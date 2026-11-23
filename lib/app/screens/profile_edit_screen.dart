import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/auth_repository.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
import '../widgets/ph_widgets.dart';

/// Halaman "Pengaturan Akun & Profil" (Edit Profile, Upload Foto, Ubah Password, Preferensi).
class ProfileEditScreen extends StatefulWidget {
  final bool focusPassword;
  const ProfileEditScreen({super.key, this.focusPassword = false});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  final _passwordKey = GlobalKey();

  String _timezone = 'Asia/Jakarta';
  bool _pushNotif = true;
  bool _emailReminder = true;
  bool _googleConnected = true;

  Uint8List? _pickedPhotoBytes;
  bool _photoRemoved = false;

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureConf = true;

  @override
  void initState() {
    super.initState();
    _syncFromUser(AuthRepository.instance.currentUser);
    _loadProfile();

    if (widget.focusPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _passwordKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
      });
    }
  }

  void _syncFromUser(AuthUser? user) {
    if (user == null) return;
    _nameCtrl.text = user.name;
    final tz = '${user.raw['timezone'] ?? 'Asia/Jakarta'}';
    if (const ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura', 'UTC'].contains(tz)) {
      _timezone = tz;
    }
    if (user.raw.containsKey('email_notifications_enabled')) {
      _emailReminder = user.raw['email_notifications_enabled'] == true || user.raw['email_notifications_enabled'] == 1;
    }
    if (user.raw.containsKey('has_google')) {
      _googleConnected = user.raw['has_google'] == true || user.raw['has_google'] == 1;
    }
  }

  Future<void> _loadProfile() async {
    try {
      final fresh = await AuthRepository.instance.fetchProfile();
      if (!mounted) return;
      _syncToStore(fresh);
      setState(() => _syncFromUser(fresh));
    } catch (_) {
      // Gunakan data lokal tersimpan bila offline
    }
  }

  void _syncToStore(AuthUser u) {
    final id = '${u.id}';
    final avatarUrl = '${u.raw['avatar_url'] ?? ''}'.trim();
    final prev = PhStore.instance.users[id];
    PhStore.instance.users[id] = PhUser(
      id,
      u.name,
      isClient: u.roles.contains('client') || (prev?.isClient ?? false),
      isActive: prev?.isActive ?? true,
      email: u.email,
      photoUrl: avatarUrl,
      images: avatarUrl.isNotEmpty ? [avatarUrl] : const [],
      joinedAt: prev?.joinedAt ?? '${u.raw['created_at'] ?? ''}',
      role: u.roles.isNotEmpty ? u.roles.first : (prev?.role ?? ''),
    );
    PhStore.instance.changed();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedPhotoBytes = bytes;
        _photoRemoved = false;
      });
      final fresh = await AuthRepository.instance.uploadAvatar(bytes, x.name);
      _syncToStore(fresh);
      if (mounted) phToast(context, 'Foto profil berhasil diperbarui');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final fresh = await AuthRepository.instance.deleteAvatar();
      _syncToStore(fresh);
      if (!mounted) return;
      setState(() {
        _pickedPhotoBytes = null;
        _photoRemoved = true;
      });
      phToast(context, 'Foto profil berhasil dihapus');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      phToast(context, 'Nama lengkap wajib diisi');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final fresh = await AuthRepository.instance.updateProfile(
        name: name,
        timezone: _timezone,
        emailNotificationsEnabled: _emailReminder,
      );
      _syncToStore(fresh);
      if (mounted) phToast(context, 'Informasi profil berhasil diperbarui');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    final cur = _currentPwdCtrl.text;
    final nw = _newPwdCtrl.text;
    final conf = _confirmPwdCtrl.text;
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      phToast(context, 'Lengkapi semua kolom password');
      return;
    }
    if (nw.length < 8) {
      phToast(context, 'Password baru minimal 8 karakter');
      return;
    }
    if (nw != conf) {
      phToast(context, 'Konfirmasi password tidak cocok');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await AuthRepository.instance.changePassword(
        currentPassword: cur,
        newPassword: nw,
        confirmPassword: conf,
      );
      _currentPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();
      if (mounted) phToast(context, 'Password berhasil diperbarui');
    } catch (e) {
      if (mounted) phToast(context, '$e');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    final user = AuthRepository.instance.currentUser;
    final storeUser = PhStore.instance.users[PhStore.meId];
    final roleLabel = (user?.roles ?? const ['Member'])
        .map((r) => r.isEmpty ? 'Member' : '${r[0].toUpperCase()}${r.substring(1)}')
        .join(', ');
    final joinedStr = (storeUser?.joinedAt.isNotEmpty ?? false) ? fmtDate(storeUser!.joinedAt) : '-';

    final rawImgs = user?.raw != null ? extractUserImages(user!.raw) : const <String>[];
    final imgs = storeUser != null && storeUser.images.isNotEmpty ? storeUser.images : rawImgs;
    final avatarUrl = _photoRemoved
        ? ''
        : (storeUser != null && storeUser.photoUrl.isNotEmpty
            ? storeUser.photoUrl
            : (imgs.isNotEmpty ? imgs.first : ''));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: phAppBar(s.profileSettingsTitle),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 14, 16, isWide ? 24 : 14, 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Judul + Badge Akun Aktif & Role
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.profileSettingsTitle,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              S.tr('Kelola informasi pribadi, foto avatar, keamanan login, dan preferensi notifikasi Anda.',
                                   'Manage your personal info, avatar photo, login security, and notification preferences.'),
                              style: TextStyle(fontSize: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhPill(S.tr('• Akun Aktif', '• Active Account'), fg: AppColors.success, bg: c.successBg),
                            const SizedBox(width: 6),
                            PhPill(roleLabel, fg: c.primary, bg: c.primarySoft),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Banner Navy-Blue Profil
                    _buildDarkProfileBanner(
                      user: user,
                      roleLabel: roleLabel,
                      joinedStr: joinedStr,
                      avatarUrl: avatarUrl,
                      imgs: _photoRemoved ? const [] : imgs,
                      isWide: isWide,
                    ),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildBasicInfoCard(user, roleLabel),
                                const SizedBox(height: 14),
                                _buildAvatarCard(avatarUrl, _photoRemoved ? const [] : imgs),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              children: [
                                _buildPasswordCard(),
                                const SizedBox(height: 14),
                                _buildPreferencesCard(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildBasicInfoCard(user, roleLabel),
                      const SizedBox(height: 14),
                      _buildAvatarCard(avatarUrl, _photoRemoved ? const [] : imgs),
                      const SizedBox(height: 14),
                      _buildPasswordCard(),
                      const SizedBox(height: 14),
                      _buildPreferencesCard(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDarkProfileBanner({
    required AuthUser? user,
    required String roleLabel,
    required String joinedStr,
    required String avatarUrl,
    required List<String> imgs,
    required bool isWide,
  }) {
    final avatarWidget = _pickedPhotoBytes != null
        ? ClipOval(child: Image.memory(_pickedPhotoBytes!, width: 64, height: 64, fit: BoxFit.cover))
        : PhAvatar(PhStore.meId, size: 64, imageUrl: avatarUrl, images: imgs);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _pickAvatar,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.camera_alt_outlined, size: 16),
          label: const Text('Upload Foto Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        if (_googleConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF34D399)),
                SizedBox(width: 6),
                Text('Google Terhubung', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6EE7B7))),
              ],
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                ),
                child: avatarWidget,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (user?.name ?? '-'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                          child: Text(roleLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text('Bergabung: $joinedStr', style: const TextStyle(fontSize: 11.5, color: Colors.white60)),
                  ],
                ),
              ),
              if (isWide) actions,
            ],
          ),
          if (!isWide) ...[
            const SizedBox(height: 14),
            actions,
          ],
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(AuthUser? user, String roleLabel) {
    final c = context.colors;
    final s = S.of(context);
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.person_outline_rounded, AppColors.primary600, c.primarySoft, s.basicInfo, s.basicInfoDesc),
          const SizedBox(height: 14),
          Text(s.fullName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDeco(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(s.emailAddress, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.border)),
            child: Row(
              children: [
                Expanded(child: Text(user?.email ?? '-', style: TextStyle(fontSize: 13, color: c.textSecondary))),
                PhPill('✓ ${s.verified}', fg: AppColors.success, bg: c.successBg),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.timezone, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _timezone,
            isExpanded: true,
            decoration: _inputDeco(),
            items: const [
              DropdownMenuItem(value: 'Asia/Jakarta', child: Text('Asia/Jakarta (WIB, UTC+7)')),
              DropdownMenuItem(value: 'Asia/Makassar', child: Text('Asia/Makassar (WITA, UTC+8)')),
              DropdownMenuItem(value: 'Asia/Jayapura', child: Text('Asia/Jayapura (WIT, UTC+9)')),
              DropdownMenuItem(value: 'UTC', child: Text('UTC')),
            ],
            onChanged: (v) => setState(() => _timezone = v ?? 'Asia/Jakarta'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.border)),
            child: Row(
              children: [
                Expanded(child: _metaCol(S.tr('Role / Posisi', 'Role / Position'), roleLabel)),
                Expanded(child: _metaCol(S.tr('Unit Organisasi', 'Organization Unit'), S.tr('Kantor Pusat', 'Head Office'))),
                Expanded(child: _metaCol('Status', S.tr('Aktif', 'Active'))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _savingProfile ? null : _saveProfile,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary600, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _savingProfile ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline_rounded, size: 17),
              label: Text(s.saveInfo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(String avatarUrl, List<String> imgs) {
    final c = context.colors;
    final s = S.of(context);
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.image_outlined, const Color(0xFF7C3AED), c.isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF), s.avatarTitle, s.avatarDesc),
          const SizedBox(height: 14),
          Row(
            children: [
              _pickedPhotoBytes != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_pickedPhotoBytes!, width: 58, height: 58, fit: BoxFit.cover))
                  : PhAvatar(PhStore.meId, size: 58, imageUrl: avatarUrl, images: imgs),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: _pickAvatar,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(s.chooseNewPhoto, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ),
                    TextButton.icon(
                      onPressed: _removeAvatar,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      label: const Text('Hapus Foto Profil Saat Ini', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    final p = _newPwdCtrl.text;
    final hasLen = p.length >= 8;
    final hasCase = p.contains(RegExp(r'[A-Z]')) && p.contains(RegExp(r'[a-z]'));
    final hasDigit = p.contains(RegExp(r'[0-9]'));
    final hasSpec = p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    return PhCard(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.lock_outline_rounded, const Color(0xFFD97706), AppColors.warningBg, 'Ubah Password', 'Pastikan menggunakan kata sandi minimal 8 karakter yang aman.'),
          const SizedBox(height: 14),
          const Text('Password Saat Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey700)),
          const SizedBox(height: 6),
          TextField(
            controller: _currentPwdCtrl,
            obscureText: _obscureCur,
            decoration: _inputDeco(
              suffix: IconButton(
                icon: Icon(_obscureCur ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureCur = !_obscureCur),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Password Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey700)),
          const SizedBox(height: 6),
          TextField(
            controller: _newPwdCtrl,
            obscureText: _obscureNew,
            onChanged: (_) => setState(() {}),
            decoration: _inputDeco(
              hint: 'Minimal 8 karakter',
              suffix: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _pwdRule('Minimal 8 karakter', hasLen),
              _pwdRule('Huruf besar & kecil', hasCase),
              _pwdRule('Angka', hasDigit),
              _pwdRule('Simbol (!@#\$&*)', hasSpec),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Konfirmasi Password Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey700)),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPwdCtrl,
            obscureText: _obscureConf,
            decoration: _inputDeco(
              hint: 'Ulangi password baru',
              suffix: IconButton(
                icon: Icon(_obscureConf ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                onPressed: () => setState(() => _obscureConf = !_obscureConf),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _savingPassword ? null : _savePassword,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F172A), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: _savingPassword
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Perbarui Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final c = context.colors;
    final s = S.of(context);
    return PhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.tune_rounded, const Color(0xFF9333EA), c.isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF), s.preferencesIntegrations, S.tr('Pengaturan pengingat dan koneksi aplikasi pihak ketiga.', 'Reminder settings and third-party integrations.')),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: SwitchListTile(
              dense: true,
              activeThumbColor: AppColors.primary600,
              title: Text(S.tr('Push Notifikasi', 'Push Notifications'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              subtitle: Text(S.tr('Terima notifikasi instan untuk pesan, tiket, & deadline task.', 'Receive instant notifications for messages, tickets, & task deadlines.'), style: TextStyle(fontSize: 11, color: c.textMuted)),
              value: _pushNotif,
              onChanged: (v) => setState(() => _pushNotif = v),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: SwitchListTile(
              dense: true,
              activeThumbColor: AppColors.primary600,
              title: Text(s.emailReminders, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              subtitle: Text(s.emailRemindersDesc, style: TextStyle(fontSize: 11, color: c.textMuted)),
              value: _emailReminder,
              onChanged: (v) async {
                setState(() => _emailReminder = v);
                try {
                  final fresh = await AuthRepository.instance.updateProfile(emailNotificationsEnabled: v);
                  _syncToStore(fresh);
                } catch (e) {
                  if (mounted) phToast(context, '$e');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Google Calendar & Meet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(S.tr('Otomatis jadwalkan meeting Google Meet dari Sprint, Milestone, dan Task.', 'Automatically schedule Google Meet from Sprints, Milestones, and Tasks.'), style: TextStyle(fontSize: 11, color: c.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _googleConnected = !_googleConnected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _googleConnected ? AppColors.error : c.primary,
                    side: BorderSide(color: _googleConnected ? const Color(0xFFFECACA) : AppColors.primary200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  child: Text(_googleConnected ? 'Disconnect' : S.tr('Hubungkan', 'Connect'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, Color fg, Color bg, String title, String subtitle) {
    final c = context.colors;
    return Row(
      children: [
        Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: fg)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaCol(String k, String v) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
        const SizedBox(height: 2),
        Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary)),
      ],
    );
  }

  Widget _pwdRule(String label, bool ok) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 13, color: ok ? AppColors.success : c.textFaint),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: ok ? AppColors.success : c.textMuted)),
      ],
    );
  }

  InputDecoration _inputDeco({String? hint, Widget? suffix}) {
    final c = context.colors;
    return InputDecoration(
      filled: true,
      fillColor: c.bg,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5, color: c.textFaint),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: c.primary, width: 1.5)),
    );
  }
}
