import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../data/shift_repository.dart';
import '../data/task_repository.dart';
import '../data/attendance_repository.dart';
import '../data/chat_remote.dart';
import '../data/ph_store.dart';

/// Konfirmasi lalu keluar: sesi dihapus dan semua cache data server
/// dikosongkan supaya akun berikutnya tidak melihat data akun sebelumnya.
Future<void> confirmSignOut(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log Out'),
      content: const Text('Keluar dari akun ini?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  await AuthRepository.instance.logout();
  clearAccountData();
  if (context.mounted) context.go('/welcome');
}

/// Mengosongkan semua cache data server milik akun yang baru keluar.
void clearAccountData() {
  PhStore.instance.clearRemote();
  ShiftRepository.instance.clear();
  TaskRepository.instance.replaceAll(const []);
  AttendanceRepository.instance.clear();
  ChatRepository.instance.clear();
}
