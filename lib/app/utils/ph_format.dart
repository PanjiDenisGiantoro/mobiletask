import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const monthsLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const weekdaysLong = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

/// "Rp 12.500.000" dengan pemisah ribuan titik, sesuai kolom decimal(15,2).
String rp(num value) {
  final v = value.round();
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $buf';
}

/// "2026-05-20" -> "20 Mei 2026". Kosong -> "-".
String fmtDate(String? iso) {
  if (iso == null || iso.length < 10) return '-';
  final p = iso.substring(0, 10).split('-');
  final m = int.tryParse(p[1]) ?? 1;
  return '${int.parse(p[2])} ${monthsShort[m - 1]} ${p[0]}';
}

/// "2026-05-20 10:30" -> "20 Mei 2026, 10:30".
String fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  if (iso.length <= 10) return fmtDate(iso);
  return '${fmtDate(iso)}, ${iso.substring(11, 16)}';
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "2026-11-10 10:30" -> "5 menit lalu" / "2 jam lalu" / "3 hari lalu".
/// Lebih dari 30 hari jatuh balik ke [fmtDate].
String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return '-';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 0) return fmtDate(iso);
  if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 30) return '${diff.inDays} hari lalu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan lalu';
  return fmtDate(iso);
}

/// Rentang tanggal untuk filter "Bulan ini" (1 s.d. akhir bulan berjalan).
DateTimeRange currentMonthRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTimeRange(start: DateTime(n.year, n.month, 1), end: DateTime(n.year, n.month + 1, 0));
}

/// "1 – 30 Nov 2026" atau "28 Nov – 5 Des 2026" kalau beda bulan.
String fmtDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.day} – ${end.day} ${monthsShort[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${monthsShort[start.month - 1]} – ${end.day} ${monthsShort[end.month - 1]} ${start.year}';
  }
  return '${start.day} ${monthsShort[start.month - 1]} ${start.year} – ${end.day} ${monthsShort[end.month - 1]} ${end.year}';
}

/// Cek tanggal ISO ("yyyy-MM-dd...") jatuh di dalam [range] (inklusif, berbasis hari).
bool inDateRange(String isoDateStr, DateTimeRange range) {
  final d = DateTime.tryParse(isoDateStr);
  if (d == null) return false;
  final day = DateTime(d.year, d.month, d.day);
  return !day.isBefore(range.start) && !day.isAfter(range.end);
}

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String longDay(DateTime d) =>
    '${weekdaysLong[d.weekday - 1]}, ${d.day} ${monthsLong[d.month - 1]} ${d.year}';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((e) => e[0].toUpperCase()).join();
}

String fileSize(int bytes) => bytes >= 1048576
    ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).round()} KB';

/// Warna dan label status. Kunci mengikuti nilai enum di database projecthub_pro.
class StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const StatusStyle(this.label, this.fg, this.bg);
}

const _grey = StatusStyle('', AppColors.grey700, AppColors.grey100);
const _info = StatusStyle('', Color(0xFF1565C0), AppColors.primary50);
const _warn = StatusStyle('', Color(0xFFB15600), AppColors.warningBg);
const _ok = StatusStyle('', Color(0xFF2E7D32), AppColors.successBg);
const _bad = StatusStyle('', Color(0xFFC62828), AppColors.errorBg);

StatusStyle _s(String label, StatusStyle base) => StatusStyle(label, base.fg, base.bg);

final Map<String, Map<String, StatusStyle>> _statusTable = {
  'project': {
    'draft': _s('Draft', _grey),
    'active': _s('Aktif', _info),
    'on_hold': _s('Ditunda', _warn),
    'completed': _s('Selesai', _ok),
    'cancelled': _s('Dibatalkan', _bad),
  },
  'priority': {
    'low': _s('Low', _grey),
    'medium': _s('Medium', _info),
    'high': _s('High', _warn),
    'urgent': _s('Urgent', _bad),
    'critical': _s('Critical', _bad),
  },
  'task': {
    'todo': _s('To Do', _grey),
    'in_progress': _s('In Progress', _info),
    'review': _s('Review', _warn),
    'done': _s('Done', _ok),
  },
  'milestone': {
    'pending': _s('Pending', _grey),
    'in_progress': _s('In Progress', _info),
    'completed': _s('Completed', _ok),
  },
  'sprint': {
    'planned': _s('Planned', _grey),
    'active': _s('Active', _info),
    'completed': _s('Completed', _ok),
  },
  'risk': {
    'open': _s('Open', _bad),
    'mitigated': _s('Mitigated', _ok),
    'accepted': _s('Accepted', _warn),
    'closed': _s('Closed', _grey),
  },
  'ticket': {
    'open': _s('Open', _info),
    'assigned': _s('Assigned', _info),
    'in_progress': _s('In Progress', _warn),
    'pending_review': _s('Pending Review', _warn),
    'resolved': _s('Resolved', _ok),
    'closed': _s('Closed', _grey),
    'reopened': _s('Reopened', _bad),
  },
  'request': {
    'waiting_approval': _s('Menunggu approval', _warn),
    'approved': _s('Disetujui', _ok),
    'rejected': _s('Ditolak', _bad),
    'done': _s('Selesai', _ok),
  },
  'approval': {
    'pending': _s('Menunggu', _warn),
    'approved': _s('Disetujui', _ok),
    'rejected': _s('Ditolak', _bad),
    'expired': _s('Kedaluwarsa', _grey),
    'cancelled': _s('Dibatalkan', _grey),
    'skipped': _s('Dilewati', _grey),
  },
  'submission': {
    'pending': _s('Menunggu', _warn),
    'approved': _s('Disetujui', _ok),
    'rejected': _s('Ditolak', _bad),
    'cancelled': _s('Dibatalkan', _grey),
  },
  'payroll': {
    'draft': _s('Draft', _grey),
    'finalized': _s('Final', _info),
    'paid': _s('Dibayar', _ok),
  },
  'kasbon': {
    'berjalan': _s('Berjalan', _warn),
    'lunas': _s('Lunas', _ok),
  },
  'attendance': {
    'hadir': _s('Hadir', _ok),
    'alpha': _s('Alpha', _bad),
    'izin': _s('Izin', _info),
    'sakit': _s('Sakit', _warn),
    'cuti': _s('Cuti', _info),
    'libur': _s('Libur', _grey),
  },
  'kb_category': {
    'brd': const StatusStyle('BRD', Color(0xFF8E24AA), Color(0xFFF3E5F5)),
    'prd': const StatusStyle('PRD', Color(0xFF3949AB), Color(0xFFE8EAF6)),
    'fsd': const StatusStyle('FSD', Color(0xFF5E35B1), Color(0xFFEDE7F6)),
    'mom': const StatusStyle('MOM', Color(0xFF00897B), Color(0xFFE0F2F1)),
    'tech_spec': const StatusStyle('Tech Spec', Color(0xFFFB8C00), AppColors.warningBg),
    'onboarding': const StatusStyle('Onboarding', Color(0xFF00ACC1), Color(0xFFE0F7FA)),
  },
};

StatusStyle statusStyle(String group, String key) =>
    _statusTable[group]?[key] ?? StatusStyle(key, AppColors.grey700, AppColors.grey100);

String statusLabel(String group, String key) => statusStyle(group, key).label;

/// Daftar (kunci, label) satu grup status, untuk dropdown dan filter.
List<(String, String)> statusOptions(String group) =>
    (_statusTable[group] ?? {}).entries.map((e) => (e.key, e.value.label)).toList();
