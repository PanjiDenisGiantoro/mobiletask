import 'package:flutter/material.dart';
import '../data/task_repository.dart';
import '../widgets/task_tile.dart';
import '../data/ph_api.dart';
import '../utils/ph_format.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../widgets/ph_form.dart';
import '../widgets/ph_widgets.dart';

const _area = PhFieldType.multiline;
const _num = PhFieldType.number;
const _date = PhFieldType.date;
const _sel = PhFieldType.select;

final _store = PhStore.instance;

List<(String, String)> _staffOptions() => [for (final u in _store.staff) (u.id, u.name)];

/// Form proyek. Field mengikuti tabel `projects`.
void openProjectForm(BuildContext context, {Project? project}) {
  final p = project;
  openPhForm(
    context,
    PhFormConfig(
      title: p == null ? 'Proyek Baru' : 'Ubah Proyek',
      doneMessage: 'Proyek tersimpan',
      fields: [
        PhField('name', 'Nama proyek', required: true, initial: p?.name),
        PhField('description', 'Deskripsi', type: _area, initial: p?.description),
        PhField('clientId', 'Client', type: _sel, options: [('', 'Tanpa client (internal)'), for (final c in _store.clients) (c.id, c.name)], initial: p?.clientId ?? ''),
        PhField('managerId', 'Lead Project', type: _sel, options: _staffOptions(), initial: p?.managerId ?? PhStore.meId),
        PhField('status', 'Status', type: _sel, options: statusOptions('project'), initial: p?.status ?? 'draft'),
        PhField('startDate', 'Tanggal mulai', type: _date, initial: p?.startDate),
        PhField('endDate', 'Tanggal selesai', type: _date, initial: p?.endDate),
        PhField('budget', 'Budget (Rp)', type: _num, initial: p?.budget.round()),
        PhField('budgetThreshold', 'Ambang peringatan budget', type: _num, unit: '%', initial: p?.budgetThreshold ?? 80),
        PhField('githubUrl', 'URL repo GitHub', initial: p?.githubUrl),
      ],
      onSave: (v) async {
        final s = v['startDate'] as String, e = v['endDate'] as String;
        if (s.isNotEmpty && e.isNotEmpty && e.compareTo(s) < 0) return 'Tanggal selesai harus setelah tanggal mulai';
        await _store.saveProject(p, v);
        return null;
      },
    ),
  );
}

String priorityKey(TaskPriority p) => p.name;

/// Form task. Field mengikuti kolom yang diterima TaskController di API.
void openTaskForm(BuildContext context, {required Project project, TaskEntry? task}) {
  final t = task;
  openPhForm(
    context,
    PhFormConfig(
      title: t == null ? 'Task Baru' : 'Ubah Task',
      note: 'Proyek: ${project.name}',
      doneMessage: 'Task tersimpan',
      fields: [
        PhField('title', 'Judul', required: true, initial: t?.title),
        PhField('description', 'Deskripsi', type: _area, initial: t?.description),
        PhField('milestone', 'Milestone', type: _sel, options: [('', 'Tanpa milestone'), for (final m in project.milestones) (m.title, m.title)], initial: t?.milestone ?? ''),
        PhField('sprint', 'Sprint', type: _sel, options: [('', 'Tanpa sprint'), for (final s in project.sprints) (s.name, s.name)], initial: t?.sprint ?? ''),
        PhField('assignedTo', 'Ditugaskan ke', type: _sel, options: [('', 'Belum ditugaskan'), ..._staffOptions()], initial: t?.assignedTo ?? ''),
        PhField('priority', 'Prioritas', type: _sel, options: statusOptions('priority').where((e) => e.$1 != 'critical').toList(), initial: t == null ? 'medium' : priorityKey(t.priority)),
        PhField('status', 'Kolom / status', type: _sel, options: statusOptions('task'), initial: t?.status ?? 'todo'),
        PhField('startDate', 'Tanggal mulai', type: _date, initial: t?.startDate),
        PhField('dueDate', 'Tenggat', type: _date, initial: t?.dueDate),
        PhField('estimatedHours', 'Estimasi', type: _num, unit: 'jam', initial: t?.estimatedHours),
        PhField('storyPoints', 'Story points', type: _num, initial: t?.storyPoints),
      ],
      onSave: (v) async {
        final s = v['startDate'] as String, e = v['dueDate'] as String;
        if (s.isNotEmpty && e.isNotEmpty && e.compareTo(s) < 0) return 'Tenggat harus setelah tanggal mulai';
        if (t == null) {
          await _store.createTask(project, v);
        } else {
          await _store.updateTask(t, v);
        }
        return null;
      },
    ),
  );
}

void openMilestoneForm(BuildContext context, Project project, {Milestone? milestone}) {
  final m = milestone;
  openPhForm(
    context,
    PhFormConfig(
      title: m == null ? 'Milestone Baru' : 'Ubah Milestone',
      fields: [
        PhField('title', 'Judul', required: true, initial: m?.title),
        PhField('description', 'Deskripsi', type: _area, initial: m?.description),
        PhField('status', 'Status', type: _sel, options: statusOptions('milestone'), initial: m?.status ?? 'pending'),
        PhField('startDate', 'Mulai', type: _date, initial: m?.startDate),
        PhField('dueDate', 'Jatuh tempo', type: _date, initial: m?.dueDate),
        PhField('assignedTo', 'Penanggung jawab', type: _sel, options: [('', 'Belum ditentukan'), ..._staffOptions()], initial: m?.assignedTo ?? ''),
      ],
      onSave: (v) async {
        await _store.saveMilestone(project, m, v);
        return null;
      },
    ),
  );
}

void openSprintForm(BuildContext context, Project project, {Sprint? sprint}) {
  final s = sprint;
  openPhForm(
    context,
    PhFormConfig(
      title: s == null ? 'Sprint Baru' : 'Ubah Sprint',
      note: 'Hanya satu sprint aktif per proyek; mengaktifkan sprint ini menutup sprint aktif lain.',
      doneMessage: 'Sprint tersimpan',
      fields: [
        PhField('name', 'Nama sprint', required: true, initial: s?.name),
        PhField('goal', 'Goal', type: _area, initial: s?.goal),
        PhField('status', 'Status', type: _sel, options: statusOptions('sprint'), initial: s?.status ?? 'planned'),
        PhField('startDate', 'Mulai', type: _date, initial: s?.startDate),
        PhField('endDate', 'Selesai', type: _date, initial: s?.endDate),
        PhField('milestone', 'Milestone', type: _sel, options: [('', 'Tanpa milestone'), for (final m in project.milestones) (m.title, m.title)], initial: s?.milestone ?? ''),
      ],
      onSave: (v) async {
        final a = v['startDate'] as String, b = v['endDate'] as String;
        if (a.isNotEmpty && b.isNotEmpty && b.compareTo(a) < 0) return 'Tanggal selesai harus setelah tanggal mulai';
        await _store.saveSprint(project, s, v);
        return null;
      },
    ),
  );
}

void openMemberForm(BuildContext context, Project project) {
  final existing = {for (final m in project.members) m.userId};
  final candidates = [for (final u in _store.staff.where((u) => !existing.contains(u.id))) (u.id, u.name)];
  if (candidates.isEmpty) {
    phToast(context, 'Semua pengguna sudah menjadi anggota proyek ini');
    return;
  }
  openPhForm(
    context,
    PhFormConfig(
      title: 'Tambah Anggota',
      doneMessage: 'Anggota ditambahkan',
      fields: [
        PhField('userIds', 'Pengguna', type: PhFieldType.multi, options: candidates),
        const PhField('role', 'Peran di proyek', hint: 'Contoh: Frontend Developer'),
        const PhField('maxHoursPerDay', 'Maks jam per hari', type: _num, unit: 'jam', initial: 8),
      ],
      onSave: (v) async {
        final ids = [...(v['userIds'] as List<String>)];
        if (ids.isEmpty) return 'Pilih minimal satu pengguna';
        final hours = int.tryParse('${v['maxHoursPerDay']}') ?? 8;
        if (hours < 1 || hours > 24) return 'Jam per hari harus 1 sampai 24';
        await _store.addMembers(project, ids, '${v['role'] ?? ''}', hours);
        return null;
      },
    ),
  );
}

void openBudgetForm(BuildContext context, Project project) {
  openPhForm(
    context,
    PhFormConfig(
      title: 'Entri Budget',
      doneMessage: 'Entri budget ditambahkan',
      fields: [
        const PhField('type', 'Jenis', type: _sel, options: [('income', 'Pemasukan'), ('expense', 'Pengeluaran')], initial: 'expense'),
        const PhField('category', 'Kategori', required: true, hint: 'Contoh: Infrastruktur'),
        const PhField('description', 'Deskripsi', required: true),
        const PhField('amount', 'Jumlah (Rp)', type: _num, required: true),
        PhField('entryDate', 'Tanggal', type: _date, required: true, initial: isoDate(DateTime.now())),
        const PhField('reference', 'Referensi', hint: 'No. invoice atau bukti'),
      ],
      onSave: (v) async {
        if ((double.tryParse('${v['amount']}') ?? -1) < 0) return 'Jumlah tidak valid';
        await _store.addBudgetEntry(project, v);
        return null;
      },
    ),
  );
}

void openBudgetThresholdForm(BuildContext context, Project project) {
  openPhForm(
    context,
    PhFormConfig(
      title: 'Ambang Peringatan Budget',
      doneMessage: 'Ambang diperbarui',
      fields: [PhField('threshold', 'Ambang', type: _num, unit: '%', required: true, initial: project.budgetThreshold)],
      onSave: (v) async {
        final t = int.tryParse('${v['threshold']}') ?? -1;
        if (t < 0 || t > 100) return 'Ambang harus 0 sampai 100';
        await _store.setBudgetThreshold(project, t);
        return null;
      },
    ),
  );
}

const riskCategories = {
  'technical': 'Teknis', 'schedule': 'Jadwal', 'resource': 'Sumber daya', 'budget': 'Budget', 'external': 'Eksternal', 'other': 'Lainnya',
};

void openRiskForm(BuildContext context, Project project, {Risk? risk}) {
  final r = risk;
  openPhForm(
    context,
    PhFormConfig(
      title: r == null ? 'Risiko Baru' : 'Ubah Risiko',
      note: 'Skor = probabilitas × dampak.',
      doneMessage: 'Risiko tersimpan',
      fields: [
        PhField('title', 'Judul', required: true, initial: r?.title),
        PhField('description', 'Deskripsi', type: _area, initial: r?.description),
        PhField('category', 'Kategori', type: _sel, options: [for (final e in riskCategories.entries) (e.key, e.value)], initial: r?.category ?? 'technical'),
        PhField('probability', 'Probabilitas (1-5)', type: _num, required: true, initial: r?.probability ?? 3),
        PhField('impact', 'Dampak (1-5)', type: _num, required: true, initial: r?.impact ?? 3),
        PhField('status', 'Status', type: _sel, options: statusOptions('risk'), initial: r?.status ?? 'open'),
        PhField('mitigationPlan', 'Rencana mitigasi', type: _area, initial: r?.mitigationPlan),
        PhField('owner', 'Pemilik risiko', initial: r?.owner),
      ],
      onSave: (v) async {
        final pr = int.tryParse('${v['probability']}') ?? 0, im = int.tryParse('${v['impact']}') ?? 0;
        if (pr < 1 || pr > 5 || im < 1 || im > 5) return 'Probabilitas dan dampak harus 1 sampai 5';
        await _store.saveRisk(project, r, v);
        return null;
      },
    ),
  );
}

void openFileForm(BuildContext context, Project project) {
  openPhForm(
    context,
    PhFormConfig(
      title: 'Unggah File',
      note: 'Pilih gambar/foto dokumen dari galeri (maks 50 MB). Gunakan "/" untuk subfolder, mis. Desain/v2.',
      doneMessage: 'File diunggah',
      fields: const [
        PhField('folder', 'Folder', required: true, hint: 'Contoh: Desain', initial: 'General'),
        PhField('file', 'File', type: PhFieldType.file, required: true),
        PhField('description', 'Deskripsi', type: _area),
      ],
      onSave: (v) async {
        final f = v['fileFile'] as PhPickedFile?;
        if (f == null) return 'Pilih file terlebih dahulu';
        await _store.uploadFile(project, '${v['folder']}', '${v['description'] ?? ''}', ApiFile('files[]', f.name, f.bytes));
        return null;
      },
    ),
  );
}

/// Catat waktu manual (TimeLogController action=manual): durasi + catatan.
void openTimeLogForm(BuildContext context, Project project) {
  final tasks = TaskRepository.instance.tasks.where((t) => t.projectId == project.id).toList();
  if (tasks.isEmpty) {
    phToast(context, 'Belum ada task di proyek ini');
    return;
  }
  openPhForm(
    context,
    PhFormConfig(
      title: 'Catat Waktu',
      doneMessage: 'Waktu tercatat',
      fields: [
        PhField('taskId', 'Task', type: _sel, options: [for (final t in tasks) ('${t.id}', t.title)]),
        const PhField('hours', 'Jam', type: _num, initial: 1),
        const PhField('minutes', 'Menit', type: _num, initial: 0),
        const PhField('notes', 'Catatan', type: _area),
      ],
      onSave: (v) async {
        final total = (int.tryParse('${v['hours']}') ?? 0) * 60 + (int.tryParse('${v['minutes']}') ?? 0);
        if (total < 1) return 'Durasi minimal 1 menit';
        await _store.logTime(project, int.parse('${v['taskId']}'), 'manual', minutes: total, notes: '${v['notes'] ?? ''}');
        return null;
      },
    ),
  );
}
