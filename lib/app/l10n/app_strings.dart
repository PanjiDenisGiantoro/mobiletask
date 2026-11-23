import 'package:flutter/widgets.dart';
import '../theme/app_settings.dart';

/// Kamus lokalisasi aplikasi Flovig (Indonesia & English).
class S {
  final bool isId;
  const S._(this.isId);

  static S of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    return S._(scope?.isIndonesian ?? AppSettings.instance.isIndonesian);
  }

  static S get current => S._(AppSettings.instance.isIndonesian);

  /// Helper ringkas untuk teks bilingual.
  static String tr(String idText, String enText) =>
      AppSettings.instance.isIndonesian ? idText : enText;

  // Bahasa & Tema
  String get language => isId ? 'Bahasa' : 'Language';
  String get indonesian => 'Bahasa Indonesia';
  String get english => 'English';
  String get languageName => isId ? 'Indonesia' : 'English';
  String get chooseLanguage => isId ? 'Pilih Bahasa' : 'Choose Language';
  String get darkMode => isId ? 'Mode Gelap' : 'Dark Mode';

  // Bottom Navigation
  String get navHome => isId ? 'Beranda' : 'Home';
  String get navProjects => isId ? 'Proyek' : 'Projects';
  String get navActivities => isId ? 'Aktivitas' : 'Activities';
  String get navProfile => isId ? 'Profil' : 'Profile';
  String get navAttendance => isId ? 'Absensi' : 'Attendance';
  String get navLeave => isId ? 'Cuti' : 'Leave';

  // Profile Screen
  String get editProfile => isId ? 'Edit Profil' : 'Edit Profile';
  String get changePassword => isId ? 'Ubah Password' : 'Change Password';
  String get notifications => isId ? 'Notifikasi' : 'Notifications';
  String get appMode => isId ? 'MODE APLIKASI' : 'APP MODE';
  String get sectionAccount => isId ? 'Akun' : 'Account';
  String get sectionAdmin => isId ? 'Administrasi' : 'Administration';
  String get adminAndSettings =>
      isId ? 'Admin & Pengaturan' : 'Admin & Settings';
  String get sectionPreferences => isId ? 'Preferensi' : 'Preferences';
  String get sectionSupport => isId ? 'Bantuan' : 'Support';
  String get helpCenter => isId ? 'Pusat Bantuan' : 'Help Center';
  String get privacyPolicy => isId ? 'Kebijakan Privasi' : 'Privacy Policy';
  String get aboutFlovig => isId ? 'Tentang Flovig' : 'About Flovig';
  String get logOut => isId ? 'Keluar' : 'Log Out';
  String get projects => isId ? 'Proyek' : 'Projects';
  String get tasks => isId ? 'Tugas' : 'Tasks';
  String get teams => isId ? 'Tim' : 'Teams';
  String get roleAdmin => 'Admin';
  String get roleMember => 'Member';

  // Profile Edit Screen
  String get profileSettingsTitle =>
      isId ? 'Pengaturan Akun & Profil' : 'Account & Profile Settings';
  String get basicInfo =>
      isId ? 'Informasi Dasar Akun' : 'Basic Account Information';
  String get basicInfoDesc => isId
      ? 'Informasi identitas akun yang ditampilkan ke seluruh rekan kerja.'
      : 'Your account identity shown across your workspace.';
  String get fullName => isId ? 'Nama Lengkap' : 'Full Name';
  String get emailAddress => isId ? 'Alamat Email' : 'Email Address';
  String get verified => isId ? 'Terverifikasi' : 'Verified';
  String get timezone => isId ? 'Zona Waktu' : 'Timezone';
  String get saveInfo => isId ? 'Simpan Informasi' : 'Save Information';
  String get avatarTitle =>
      isId ? 'Foto Profil (Avatar)' : 'Profile Photo (Avatar)';
  String get avatarDesc => isId
      ? 'Upload foto berformat JPG, PNG, atau WEBP dengan ukuran maks. 2MB.'
      : 'Upload a JPG, PNG, or WEBP photo (max 2MB).';
  String get chooseNewPhoto => isId ? 'Pilih Foto Baru' : 'Choose New Photo';
  String get removeCurrentPhoto =>
      isId ? 'Hapus Foto Profil Saat Ini' : 'Remove Current Photo';
  String get currentPassword =>
      isId ? 'Password Saat Ini' : 'Current Password';
  String get newPassword => isId ? 'Password Baru' : 'New Password';
  String get confirmNewPassword =>
      isId ? 'Konfirmasi Password Baru' : 'Confirm New Password';
  String get updatePassword => isId ? 'Perbarui Password' : 'Update Password';
  String get preferencesIntegrations =>
      isId ? 'Preferensi & Integrasi' : 'Preferences & Integrations';
  String get emailReminders => isId ? 'Pengingat Email' : 'Email Reminders';
  String get emailRemindersDesc => isId
      ? 'Terima email rangkuman otomatis saat ada tiket baru atau status penting.'
      : 'Receive automatic summary emails for new tickets or important updates.';
  String get cancel => isId ? 'Batal' : 'Cancel';
  String get save => isId ? 'Simpan' : 'Save';

  // Dashboard & Menu Lainnya
  String get quickAccess => isId ? 'Akses Cepat' : 'Quick Access';
  String get moreMenu => isId ? 'Menu Lainnya' : 'More Menu';
  String get subscriptionBilling =>
      isId ? 'Langganan & Tagihan' : 'Subscription & Billing';
  String get activityLog => isId ? 'Log Aktivitas' : 'Activity Log';
  String get invoices => isId ? 'Invoice' : 'Invoices';
  String get role => 'Role';
  String get permission => 'Permission';
  String get taskDistribution =>
      isId ? 'Distribusi Tugas' : 'Task Distribution';
  String get activeSprints => isId ? 'Sprint Aktif' : 'Active Sprints';
  String get projectProgress => isId ? 'Progres Proyek' : 'Project Progress';
  String get teamActivity => isId ? 'Aktivitas Tim' : 'Team Activity';
  String get recentTickets => isId ? 'Tiket Terbaru' : 'Recent Tickets';
  String get upcomingDeadlines =>
      isId ? 'Tenggat Mendatang' : 'Upcoming Deadlines';
  String get subscriptionStatus =>
      isId ? 'Status Langganan' : 'Subscription Status';
  String get viewAll => isId ? 'Lihat Semua' : 'View All';
  String get search => isId ? 'Cari' : 'Search';
  String get calendar => isId ? 'Kalender' : 'Calendar';
  String get chat => isId ? 'Obrolan' : 'Chat';
  String get tickets => isId ? 'Tiket' : 'Tickets';
  String get files => isId ? 'Berkas' : 'Files';
  String get reports => isId ? 'Laporan' : 'Reports';
}

/// InheritedWidget agar setiap pemanggil `S.of(context)` langsung rebuild
/// saat bahasa diubah, tanpa mengganggu state navigasi.
class AppStringsScope extends InheritedWidget {
  final bool isIndonesian;

  const AppStringsScope({
    super.key,
    required this.isIndonesian,
    required super.child,
  });

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      isIndonesian != oldWidget.isIndonesian;
}
