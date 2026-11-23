import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/ph_widgets.dart';

class _FaqItem {
  final String categoryId;
  final String categoryEn;
  final String qId;
  final String qEn;
  final String aId;
  final String aEn;

  const _FaqItem({
    required this.categoryId,
    required this.categoryEn,
    required this.qId,
    required this.qEn,
    required this.aId,
    required this.aEn,
  });
}

const _faqs = <_FaqItem>[
  _FaqItem(
    categoryId: 'Akun',
    categoryEn: 'Account',
    qId: 'Bagaimana cara mengubah foto profil dan nama?',
    qEn: 'How do I update my profile photo and name?',
    aId:
        'Buka tab Profil lalu ketuk tombol Edit Profil. Anda dapat mengubah nama lengkap, zona waktu, serta mengunggah atau menghapus foto avatar.',
    aEn:
        'Open the Profile tab and tap Edit Profile. You can update your full name, timezone, and upload or remove your avatar photo.',
  ),
  _FaqItem(
    categoryId: 'Akun',
    categoryEn: 'Account',
    qId: 'Bagaimana cara mengaktifkan Mode Gelap atau mengganti bahasa?',
    qEn: 'How do I enable Dark Mode or switch language?',
    aId:
        'Masuk ke tab Profil pada bagian Preferensi. Gunakan switch Mode Gelap untuk mengubah tema, dan ketuk Bahasa untuk memilih Indonesia atau English.',
    aEn:
        'Go to the Profile tab under Preferences. Toggle the Dark Mode switch for theme, and tap Language to switch between Indonesian and English.',
  ),
  _FaqItem(
    categoryId: 'Akun',
    categoryEn: 'Account',
    qId: 'Bagaimana jika saya lupa atau ingin mengganti password?',
    qEn: 'How do I change my password?',
    aId:
        'Ketuk Ubah Password di tab Profil, masukkan password saat ini dan password baru minimal 8 karakter yang mengandung huruf besar, kecil, angka, dan simbol.',
    aEn:
        'Tap Change Password on the Profile tab, enter your current password and a new password (min 8 chars with upper/lowercase, number, and symbol).',
  ),
  _FaqItem(
    categoryId: 'Proyek & Tugas',
    categoryEn: 'Projects & Tasks',
    qId: 'Bagaimana cara membuat tugas atau aktivitas baru?',
    qEn: 'How do I create a new task or activity?',
    aId:
        'Ketuk tombol + berwarna biru di tengah navigasi bawah pada mode Task Management, lalu isi detail tugas, proyek, prioritas, dan tenggat waktu.',
    aEn:
        'Tap the blue + button in the center of the bottom bar in Task Management mode, then fill in the task title, project, priority, and due date.',
  ),
  _FaqItem(
    categoryId: 'Proyek & Tugas',
    categoryEn: 'Projects & Tasks',
    qId: 'Bagaimana cara menandai proyek favorit?',
    qEn: 'How do I mark a project as favorite?',
    aId:
        'Pada halaman Daftar Proyek, ketuk ikon bintang di pojok kanan atas kartu proyek agar proyek muncul di carousel Proyek Favorit pada Beranda.',
    aEn:
        'On the Projects list, tap the star icon on the top-right of a project card to pin it to the Favorite Projects carousel on Home.',
  ),
  _FaqItem(
    categoryId: 'HRIS & Absensi',
    categoryEn: 'HRIS & Attendance',
    qId: 'Bagaimana cara berpindah ke mode HRIS (Absensi & Cuti)?',
    qEn: 'How do I switch to HRIS mode (Attendance & Leave)?',
    aId:
        'Buka tab Profil, pada bagian Mode Aplikasi pilih HRIS. Navigasi bawah akan otomatis berubah ke menu Absensi, Cuti, dan Aksi Cepat HRIS.',
    aEn:
        'Open the Profile tab and select HRIS under App Mode. The bottom navigation bar will switch to Attendance, Leave, and HRIS Quick Actions.',
  ),
  _FaqItem(
    categoryId: 'Tagihan',
    categoryEn: 'Billing',
    qId: 'Di mana saya bisa melihat riwayat langganan dan invoice?',
    qEn: 'Where can I view subscription and invoice history?',
    aId:
        'Buka Menu Lainnya dari Beranda atau menu Admin & Pengaturan di Profil, lalu pilih Langganan & Tagihan atau Invoice.',
    aEn:
        'Open More Menu from Home or Admin & Settings in Profile, then select Subscription & Billing or Invoices.',
  ),
];

/// Halaman Pusat Bantuan & FAQ Flovig.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCat = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);
    final query = _searchCtrl.text.trim().toLowerCase();

    final categories = <String, String>{
      'all': S.tr('Semua', 'All'),
      'Akun': S.tr('Akun', 'Account'),
      'Proyek & Tugas': S.tr('Proyek & Tugas', 'Projects & Tasks'),
      'HRIS & Absensi': S.tr('HRIS & Absensi', 'HRIS & Attendance'),
      'Tagihan': S.tr('Tagihan', 'Billing'),
    };

    final filtered = _faqs.where((f) {
      if (_selectedCat != 'all' && f.categoryId != _selectedCat) return false;
      if (query.isEmpty) return true;
      final q = (s.isId ? f.qId : f.qEn).toLowerCase();
      final a = (s.isId ? f.aId : f.aEn).toLowerCase();
      return q.contains(query) || a.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: phAppBar(s.helpCenter),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.heroStart, AppColors.heroMid],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.tr('Ada yang bisa kami bantu?', 'How can we help you?'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            S.tr(
                              'Temukan panduan cepat penggunaan Flovig.',
                              'Find quick guides for using Flovig.',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: c.surface,
                    hintText: S.tr('Cari pertanyaan...', 'Search questions...'),
                    hintStyle: TextStyle(color: c.textFaint, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
                    suffixIcon: query.isEmpty
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
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.entries.map((e) {
                final selected = _selectedCat == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCat = e.key),
                    selectedColor: AppColors.primary600,
                    backgroundColor: c.surface,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : c.textSecondary,
                    ),
                    side: BorderSide(color: selected ? AppColors.primary600 : c.border),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            PhCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 36, color: c.textFaint),
                    const SizedBox(height: 8),
                    Text(
                      S.tr('Pertanyaan tidak ditemukan', 'No matching questions found'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    border: Border.all(color: c.border),
                    boxShadow: c.cardShadow,
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      iconColor: c.primary,
                      collapsedIconColor: c.textMuted,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.isId ? f.categoryId : f.categoryEn,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: c.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.isId ? f.qId : f.qEn,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            s.isId ? f.aId : f.aEn,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          PhCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.tr('Masih butuh bantuan?', 'Still need help?'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.tr(
                    'Tim dukungan PT Arunika Solusi Inovasi siap membantu Senin–Jumat, 08:00–17:00 WIB.',
                    'PT Arunika Solusi Inovasi support team is available Monday–Friday, 08:00–17:00 WIB.',
                  ),
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launch('mailto:support@flovig.com'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.primary,
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.email_outlined, size: 17),
                        label: const Text('Email Support', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _launch('https://flovig.com'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.public_rounded, size: 17),
                        label: const Text('flovig.com', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
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

/// Halaman Kebijakan Privasi Flovig.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = S.of(context);

    final sections = [
      (
        Icons.folder_shared_outlined,
        S.tr('1. Informasi yang Kami Kumpulkan', '1. Information We Collect'),
        S.tr(
          'Flovig mengumpulkan informasi akun yang Anda berikan saat mendaftar atau menggunakan layanan, seperti nama lengkap, alamat email perusahaan, foto profil, data proyek, tugas, serta log aktivitas kerja sesuai izin perusahaan Anda.',
          'Flovig collects account information you provide when registering or using the service, such as full name, company email address, profile photo, project and task data, and work activity logs authorized by your company.',
        ),
      ),
      (
        Icons.location_on_outlined,
        S.tr('2. Lokasi & Kamera (Fitur Absensi)', '2. Location & Camera (Attendance)'),
        S.tr(
          'Akses lokasi (GPS) dan kamera hanya digunakan secara eksplisit saat Anda melakukan absensi kehadiran atau mengunggah foto profil/lampiran tugas. Kami tidak melacak lokasi di luar aktivitas tersebut.',
          'Location (GPS) and camera access are only used explicitly when you clock in/out for attendance or upload profile/task attachments. We do not track location outside those actions.',
        ),
      ),
      (
        Icons.verified_user_outlined,
        S.tr('3. Penggunaan & Pembagian Data', '3. How We Use & Share Data'),
        S.tr(
          'Data Anda digunakan semata-mata untuk operasional workspace perusahaan Anda (manajemen proyek, kolaborasi tim, absensi, dan penagihan). Kami tidak pernah menjual data pribadi Anda kepada pihak ketiga.',
          'Your data is used solely to operate your company workspace (project management, team collaboration, attendance, and billing). We never sell your personal data to third parties.',
        ),
      ),
      (
        Icons.lock_outline_rounded,
        S.tr('4. Keamanan & Penyimpanan', '4. Security & Storage'),
        S.tr(
          'Seluruh komunikasi antara aplikasi mobile dan server Flovig dilindungi enkripsi HTTPS/TLS. Token autentikasi serta preferensi lokal disimpan menggunakan secure storage pada perangkat Anda.',
          'All communication between the mobile app and Flovig servers is protected with HTTPS/TLS encryption. Authentication tokens and local preferences are stored in your device secure storage.',
        ),
      ),
      (
        Icons.manage_accounts_outlined,
        S.tr('5. Hak Anda & Kontak', '5. Your Rights & Contact'),
        S.tr(
          'Anda berhak memperbarui data profil kapan saja melalui menu Edit Profil, atau mengajukan penghapusan/ekspor data melalui administrator perusahaan Anda maupun email ke support@flovig.com (PT Arunika Solusi Inovasi).',
          'You may update your profile details anytime via Edit Profile, or request data export/deletion through your company administrator or by emailing support@flovig.com (PT Arunika Solusi Inovasi).',
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: phAppBar(s.privacyPolicy),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.tr('Kebijakan Privasi Flovig', 'Flovig Privacy Policy'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.tr(
                          'PT Arunika Solusi Inovasi • Diperbarui Nov 2026',
                          'PT Arunika Solusi Inovasi • Updated Nov 2026',
                        ),
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...sections.map(
            (sec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PhCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(sec.$1, size: 18, color: c.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sec.$2,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sec.$3,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
