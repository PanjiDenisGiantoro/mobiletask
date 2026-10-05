import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'shift_repository.dart';

/// Pengaturan shift absensi (Admin & Pengaturan → Shift Kerja): kelola
/// daftar shift (jam masuk/pulang) dan atur shift masing-masing karyawan
/// supaya tampil di halaman Absensi.
class ShiftSettingsScreen extends StatefulWidget {
  const ShiftSettingsScreen({super.key});

  @override
  State<ShiftSettingsScreen> createState() => _ShiftSettingsScreenState();
}

class _ShiftSettingsScreenState extends State<ShiftSettingsScreen> {
  @override
  void initState() {
    super.initState();
    ShiftRepository.instance.addListener(_onChanged);
    ShiftRepository.instance.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    ShiftRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _openShiftForm({WorkShift? shift}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShiftFormSheet(shift: shift),
    );
  }

  void _confirmDelete(WorkShift shift) {
    final repo = ShiftRepository.instance;
    if (repo.shifts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada satu shift')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Shift'),
        content: Text('Hapus "${shift.name}"? Karyawan yang memakai shift ini menjadi tanpa shift sampai diatur ulang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _run(() => repo.deleteShift(shift), 'Shift dihapus');
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ShiftRepository.instance;
    return Scaffold(
      backgroundColor: AppColors.bg,
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
        title: const Text('Shift Kerja'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.heroStart,
        onPressed: () => _openShiftForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          const Text(
            'Atur jam kerja tiap shift, lalu tetapkan shift masing-masing karyawan agar tampil di Absensi.',
            style: TextStyle(fontSize: 12.5, color: AppColors.grey500),
          ),
          if (repo.loading && repo.shifts.isEmpty)
            const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator())),
          if (repo.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(repo.error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
            ),
          const SizedBox(height: AppSpacing.lg),
          _sectionTitle('Daftar Shift'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: List.generate(repo.shifts.length, (i) {
                final shift = repo.shifts[i];
                final isLast = i == repo.shifts.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: shift.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shift.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${shift.range} · istirahat ${shift.breakRange} · toleransi ${shift.toleranceMinutes} mnt',
                                  style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.grey500),
                            onPressed: () => _openShiftForm(shift: shift),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                            onPressed: () => _confirmDelete(shift),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 36, color: AppColors.grey100),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _sectionTitle('Shift Karyawan'),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: List.generate(repo.employees.length, (i) {
                final name = repo.employees[i];
                final isLast = i == repo.employees.length - 1;
                final current = repo.shiftFor(name);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.heroStart.withValues(alpha: 0.12),
                            child: Text(
                              name.substring(0, 1),
                              style: const TextStyle(color: AppColors.heroStart, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.grey900),
                            ),
                          ),
                          DropdownButton<String>(
                            value: current?.id,
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(fontSize: 12.5, color: AppColors.grey900, fontWeight: FontWeight.w600),
                            items: repo.shifts
                                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                .toList(),
                            onChanged: (id) {
                              if (id != null) _run(() => repo.assignShift(name, id), 'Shift $name diperbarui');
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 60, color: AppColors.grey100),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey500, letterSpacing: 0.8),
        ),
      );
}

class _ShiftFormSheet extends StatefulWidget {
  final WorkShift? shift;
  const _ShiftFormSheet({this.shift});

  @override
  State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  late final TextEditingController _nameController;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late TimeOfDay _breakStart;
  late TimeOfDay _breakEnd;
  late final TextEditingController _toleranceController;
  late Color _color;

  static const _palette = [
    AppColors.info,
    AppColors.warning,
    AppColors.primary700,
    AppColors.success,
    AppColors.error,
    AppColors.accent400,
  ];

  @override
  void initState() {
    super.initState();
    final shift = widget.shift;
    _nameController = TextEditingController(text: shift?.name ?? '');
    _start = shift == null ? const TimeOfDay(hour: 8, minute: 0) : _parseTime(shift.startTime);
    _end = shift == null ? const TimeOfDay(hour: 17, minute: 0) : _parseTime(shift.endTime);
    _breakStart = (shift == null || shift.breakStart.isEmpty) ? const TimeOfDay(hour: 12, minute: 0) : _parseTime(shift.breakStart);
    _breakEnd = (shift == null || shift.breakEnd.isEmpty) ? const TimeOfDay(hour: 13, minute: 0) : _parseTime(shift.breakEnd);
    _toleranceController = TextEditingController(text: '${shift?.toleranceMinutes ?? 15}');
    _color = shift?.color ?? _palette.first;
    _workingDays = {...(shift == null || shift.workingDays.isEmpty) ? const [1, 2, 3, 4, 5] : shift.workingDays};
  }

  late Set<int> _workingDays;
  static const _dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _format(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _nameController.dispose();
    _toleranceController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickBreak({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _breakStart : _breakEnd);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _breakStart = picked;
      } else {
        _breakEnd = picked;
      }
    });
  }

  bool _saving = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi dulu nama shift')),
      );
      return;
    }
    final repo = ShiftRepository.instance;
    final messenger = ScaffoldMessenger.of(context);
    final tolerance = int.tryParse(_toleranceController.text.trim()) ?? 0;
    final startTime = _format(_start);
    final endTime = _format(_end);
    if (_workingDays.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Pilih minimal satu hari kerja')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.shift == null) {
        await repo.addShift(
          name: name, startTime: startTime, endTime: endTime, color: _color,
          breakStart: _format(_breakStart), breakEnd: _format(_breakEnd), toleranceMinutes: tolerance,
          workingDays: _workingDays.toList()..sort(),
        );
      } else {
        await repo.updateShift(
          widget.shift!, name: name, startTime: startTime, endTime: endTime, color: _color,
          breakStart: _format(_breakStart), breakEnd: _format(_breakEnd), toleranceMinutes: tolerance,
          workingDays: _workingDays.toList()..sort(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Shift "$name" berhasil disimpan')));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.shift != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.full)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEdit ? 'Ubah Shift' : 'Shift Baru',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Shift',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Shift Pagi',
                        filled: true,
                        fillColor: AppColors.grey100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(label: 'Jam Masuk', value: _format(_start), onTap: () => _pickTime(isStart: true)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TimeField(label: 'Jam Pulang', value: _format(_end), onTap: () => _pickTime(isStart: false)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(label: 'Mulai Istirahat', value: _format(_breakStart), onTap: () => _pickBreak(isStart: true)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TimeField(label: 'Selesai Istirahat', value: _format(_breakEnd), onTap: () => _pickBreak(isStart: false)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Toleransi Terlambat (menit)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: _toleranceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.grey100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Hari Kerja',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final d in const [1, 2, 3, 4, 5, 6, 0])
                          FilterChip(
                            label: Text(_dayNames[d]),
                            selected: _workingDays.contains(d),
                            onSelected: (v) => setState(() => v ? _workingDays.add(d) : _workingDays.remove(d)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Warna (tampilan di aplikasi)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: _palette.map((c) {
                        final selected = c.toARGB32() == _color.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: AppColors.grey900, width: 2) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.heroStart,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                        ),
                        child: Text(
                          _saving ? 'Menyimpan...' : 'Simpan Shift',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700)),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.sm + 6),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                const Icon(Icons.access_time_rounded, size: 17, color: AppColors.grey400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
