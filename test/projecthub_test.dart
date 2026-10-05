import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:untitled/app/utils/ph_format.dart';
import 'package:untitled/app/data/ph_models.dart';
import 'package:untitled/app/data/ph_store.dart';
import 'package:untitled/app/screens/ph_screens.dart';
import 'package:untitled/router.dart';
import 'package:untitled/app/data/task_repository.dart';
import 'package:untitled/app/widgets/task_tile.dart';

/// Data server diganti fixture karena tes tidak login ke API.
void _loadFixtures(PhStore store) {
  store.users.addAll({'u7': const PhUser('u7', 'Andi Saputra'), 'c1': const PhUser('c1', 'PT Nusantara Retail', isClient: true)});
  store.projects.add(Project(
    id: 1, name: 'Mobile App Redesign', managerId: 'u1', clientId: 'c1', budget: 250000000, budgetThreshold: 80,
    milestones: [Milestone(id: 1, title: 'Desain UI final', status: 'in_progress')],
    members: [ProjectMember(id: 1, userId: 'u1', role: 'Lead Project')],
    budgetEntries: [
      BudgetEntry(id: 1, type: 'income', category: 'Termin 1', description: '', amount: 100000000, entryDate: '2026-03-10'),
      BudgetEntry(id: 2, type: 'expense', category: 'Lisensi', description: '', amount: 12500000, entryDate: '2026-03-15'),
      BudgetEntry(id: 3, type: 'expense', category: 'Gaji tim', description: '', amount: 165000000, entryDate: '2026-04-01'),
      BudgetEntry(id: 4, type: 'expense', category: 'Riset', description: '', amount: 28000000, entryDate: '2026-04-12'),
    ],
  ));
  store.tickets.addAll([
    Ticket(id: 1, projectName: 'Mobile App Redesign', title: 'Aplikasi crash di Android 13', description: 'Crash saat login.', priority: 'critical', status: 'in_progress', reporterId: 'c1', assigneeId: 'u2'),
    Ticket(id: 3, projectName: 'Mobile App Redesign', title: 'Token tidak dicabut', description: 'Token lama masih diterima.', priority: 'high', status: 'pending_review', reporterId: 'u4'),
  ]);
  store.approvals.add(Approval(
    id: 1, module: 'Tiket', action: 'Selesaikan', label: 'TK-3 Token tidak dicabut', requestedBy: 'u4', expiresAt: '2026-09-24 17:00',
    flowType: 'any_of', mine: true, ref: const ApprovalRef('ticket', 3, to: 'resolved'), steps: [ApprovalStep('u1', 'admin')],
  ));
  TaskRepository.instance.replaceAll([
    TaskEntry(id: 1, projectId: 1, title: 'Finalize wireframes', project: 'Mobile App Redesign', priority: TaskPriority.high, due: 'Today', status: 'in_progress'),
  ]);
}

void main() {
  final store = PhStore.instance;
  _loadFixtures(store);

  group('layar modul lewat router', () {
    Future<void> open(WidgetTester tester, String path) async {
      // Font uji (Ahem) jauh lebih lebar dari Roboto, jadi layar uji dibuat lebar
      // supaya tes memeriksa isi, bukan lebar glyph.
      tester.view.physicalSize = const Size(1400, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Pindah route sebelum widget dibangun supaya SplashScreen (dengan timer)
      // tidak pernah ikut terpasang.
      appRouter.go(path);
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    testWidgets('detail proyek menampilkan semua tab dan ringkasan budget', (tester) async {
      await open(tester, '/project/1');
      expect(find.text('Mobile App Redesign'), findsWidgets);
      for (final tab in ['Ringkasan', 'Task', 'Milestone', 'Sprint', 'Tim', 'Budget', 'Risiko', 'File', 'Timesheet', 'Tiket', 'Chat']) {
        expect(find.descendant(of: find.byType(TabBar), matching: find.text(tab)), findsOneWidget, reason: 'tab $tab');
      }
      expect(find.textContaining('melewati ambang peringatan 80%'), findsOneWidget);
    });

    testWidgets('bug tickets menampilkan daftar dan SLA di detail', (tester) async {
      await open(tester, '/tickets');
      expect(find.textContaining('TK-1'), findsOneWidget);
      appRouter.go('/ticket/1');
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('SLA'), findsOneWidget);
      expect(find.textContaining('respons 1 jam'), findsOneWidget);
    });

    testWidgets('approvals: tab untuk saya berisi pengajuan', (tester) async {
      await open(tester, '/approvals');
      expect(find.textContaining('Untuk saya'), findsOneWidget);
      expect(find.textContaining('Tiket · Selesaikan'), findsOneWidget);
    });

    testWidgets('chat punya tiga tab', (tester) async {
      await open(tester, '/chat');
      for (final t in ['Proyek', 'Pesan', 'Forum']) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('form task menolak judul kosong', (tester) async {
      await open(tester, '/project/1');
      await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Task')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task baru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Judul wajib diisi'), findsOneWidget);
    });

    testWidgets('absensi meminta login bila belum ada sesi', (tester) async {
      await open(tester, '/attendance');
      expect(find.text('Silakan login untuk memakai absensi'), findsOneWidget);
      for (final tab in ['Hari Ini', 'Rekap', 'Tim']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('slip gaji menampilkan seluruh komponen', (tester) async {
      store.payrolls.add(const Payroll(
        id: 1, userId: 'u1', year: 2026, month: 9, status: 'draft', gajiPokok: 12000000, tunjanganTransport: 500000, tunjanganMakan: 660000,
        tunjanganJabatan: 1000000, hariKerja: 22, hariHadir: 20, hariCuti: 1, hariAlpha: 1, potonganAlpha: 545455, potonganBpjsKes: 120000,
        potonganBpjsTk: 360000, potonganPph21: 300000, tanggunganBpjsKes: 480000, tanggunganBpjsTk: 748800, serverGajiBersih: 12834545,
      ));
      await open(tester, '/payroll/1');
      expect(find.text('Rp 12.834.545'), findsOneWidget, reason: 'gaji bersih dari server dipakai apa adanya');
      expect(find.text('PENDAPATAN'), findsOneWidget);
      expect(find.text('POTONGAN'), findsOneWidget);
      expect(find.text('TANGGUNGAN PERUSAHAAN'), findsOneWidget);
    });

    testWidgets('modul HRIS punya semua layar dan meminta login tanpa sesi', (tester) async {
      for (final path in ['/leave', '/overtime', '/reimburse', '/kasbon', '/employees', '/holidays', '/faces', '/shift-schedule']) {
        await open(tester, path);
        expect(tester.takeException(), isNull, reason: path);
        expect(find.text('Silakan login untuk memakai HRIS'), findsWidgets, reason: path);
      }
      expect(AttendanceScreen, isNotNull);
    });
  });

  group('logika data projecthub_pro', () {
    test('rp memformat rupiah dengan pemisah ribuan titik', () {
      expect(rp(12500000), 'Rp 12.500.000');
      expect(rp(0), 'Rp 0');
    });

    test('lembur akhir pekan 10 jam: 8 jam x2, 1 jam x3, 1 jam x4', () {
      final lines = store.overtimeBreakdown('weekend', 10);
      expect(lines.map((l) => (l.hours, l.multiplier)), [(8.0, 2.0), (1.0, 3.0), (1.0, 4.0)]);
      final wage = store.hourlyWage;
      expect(lines.fold<int>(0, (s, l) => s + l.amount), (8 * 2 * wage) + (3 * wage) + (4 * wage));
    });

    test('lembur hari kerja 2 jam: jam pertama x1,5 dan jam berikutnya x2', () {
      final lines = store.overtimeBreakdown('weekday', 2);
      expect(lines.map((l) => l.multiplier), [1.5, 2.0]);
    });

    test('menyetujui approval tiket mengubah status tiket dan mencatat riwayat', () {
      final ticket = store.ticketById(3)!;
      expect(ticket.status, 'pending_review');
      final approval = store.approvalById(1)!;
      store.applyApproval(approval, 'approved', 'Cocok');
      expect(approval.status, 'approved');
      expect(ticket.status, 'resolved');
      expect(ticket.history.first.newValue, 'Resolved');
      expect(store.pendingForMe, lessThan(3));
    });

    test('menolak approval cuti mengisi alasan penolakan pada pengajuan', () {
      store.leaveRequests.add(LeaveRequest(id: 1, userId: 'u2', leaveTypeId: 1, startDate: '2026-07-10', endDate: '2026-07-12', totalDays: 3, reason: 'Acara keluarga'));
      final approval = Approval(id: 99, module: 'Cuti', action: 'Setujui cuti', label: 'x', requestedBy: 'u2', expiresAt: '', flowType: 'single', ref: const ApprovalRef('leave', 1), steps: [ApprovalStep('u1', 'admin')]);
      store.applyApproval(approval, 'rejected', 'Bentrok jadwal');
      final leave = store.leaveRequests.firstWhere((l) => l.id == 1);
      expect(leave.status, 'rejected');
      expect(leave.rejectionReason, 'Bentrok jadwal');
    });

    test('status task tersinkron dengan flag done', () {
      final t = TaskRepository.instance.byId(1)!;
      expect(t.done, isFalse);
      t.status = 'done';
      expect(t.done, isTrue);
      t.done = false;
      expect(t.status, 'todo');
    });

    test('progres budget: pengeluaran melewati ambang peringatan', () {
      final p = store.projectById(1)!;
      expect(p.expense, 205500000);
      expect(p.budgetUsedPercent, 82);
      expect(p.budgetUsedPercent >= p.budgetThreshold, isTrue);
    });

    test('skor risiko = probabilitas x dampak', () {
      expect(Risk(id: 99, title: 'x', probability: 4, impact: 5).score, 20);
    });
  });

}
