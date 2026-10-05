import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/ph_models.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_type.dart';

/// Bottom sheet "Tugas Baru" yang dibuka langsung dari tombol + di tengah
/// bottom nav (mode Task Management). Berisi judul tugas, lampiran foto
/// (kamera atau galeri), dan tipe aktivitas.
Future<void> showAddTaskFormSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const AddTaskFormSheet(),
  );
}

class AddTaskFormSheet extends StatefulWidget {
  const AddTaskFormSheet({super.key});

  @override
  State<AddTaskFormSheet> createState() => _AddTaskFormSheetState();
}

class _AddTaskFormSheetState extends State<AddTaskFormSheet> {
  final _titleController = TextEditingController();
  ActivityType _type = ActivityType.task;
  Uint8List? _photo;
  bool _saving = false;
  Project? _project = PhStore.instance.projects.where((p) => p.status == 'active').firstOrNull ??
      PhStore.instance.projects.firstOrNull;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa mengakses kamera/galeri di perangkat ini')),
      );
    }
  }

  void _openPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.heroStart),
                title: const Text('Ambil Foto'),
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.heroStart),
                title: const Text('Pilih dari Galeri'),
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Isi dulu tugas yang ingin dikerjakan')));
      return;
    }
    final project = _project;
    if (project == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pilih proyek untuk tugas ini')));
      return;
    }
    setState(() => _saving = true);
    try {
      await PhStore.instance.createTask(project, {
        'title': title,
        'description': 'Tipe aktivitas: ${_type.label}',
        'priority': 'medium',
        'status': 'todo',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text('Tugas "$title" berhasil ditambahkan')));
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tugas Baru',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Apa yang ingin dikerjakan?',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _titleController,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Perbaiki bug login di Android',
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
                        'Proyek',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<Project>(
                        initialValue: _project,
                        isExpanded: true,
                        hint: const Text('Belum ada proyek'),
                        items: [
                          for (final p in PhStore.instance.projects)
                            DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (p) => setState(() => _project = p),
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
                        'Lampiran Foto',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      GestureDetector(
                        onTap: _openPhotoSourceSheet,
                        child: _photo == null
                            ? Container(
                                width: double.infinity,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: AppColors.grey100,
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                  border: Border.all(color: AppColors.grey100, width: 1),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, color: AppColors.grey400, size: 22),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ambil foto atau upload dari galeri',
                                      style: TextStyle(fontSize: 12, color: AppColors.grey400),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                    child: Image.memory(
                                      _photo!,
                                      width: double.infinity,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _photo = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Tipe Aktivitas',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.grey700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: ActivityType.values.map((t) {
                          final selected = _type == t;
                          return GestureDetector(
                            onTap: () => setState(() => _type = t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs + 2),
                              decoration: BoxDecoration(
                                color: selected ? t.color.withValues(alpha: 0.12) : AppColors.grey100,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(color: selected ? t.color : Colors.transparent, width: 1.3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.icon, size: 14, color: selected ? t.color : AppColors.grey400),
                                  const SizedBox(width: 5),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? t.color : AppColors.grey700,
                                    ),
                                  ),
                                ],
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Menyimpan...' : 'Simpan Tugas',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
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
