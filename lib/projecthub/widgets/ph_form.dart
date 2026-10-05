import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../stitch_frontend_interface_application/app_theme.dart';
import '../ph_format.dart';
import 'ph_widgets.dart';

enum PhFieldType { text, multiline, number, date, time, dateTime, select, multi, toggle, file, info }

class PhField {
  final String key;
  final String label;
  final PhFieldType type;
  final bool required;
  final String hint;
  final String unit;
  final List<(String, String)> options;
  final Object? initial;
  final bool readOnly;
  const PhField(
    this.key,
    this.label, {
    this.type = PhFieldType.text,
    this.required = false,
    this.hint = '',
    this.unit = '',
    this.options = const [],
    this.initial,
    this.readOnly = false,
  });
}

/// File yang dipilih lewat field [PhFieldType.file].
class PhPickedFile {
  final String name;
  final List<int> bytes;
  const PhPickedFile(this.name, this.bytes);
}

class PhFormConfig {
  final String title;
  final String note;
  final List<PhField> fields;

  /// Mengembalikan pesan galat, atau null bila berhasil. Boleh async
  /// (mis. menyimpan ke API); tombol Simpan terkunci selama menunggu.
  final FutureOr<String?> Function(Map<String, Object?> values) onSave;
  final String doneMessage;
  final String saveLabel;

  /// Field turunan (mis. total hari dari tanggal). Mengembalikan nilai baru per kunci.
  final Map<String, Object?> Function(Map<String, Object?> values)? derive;

  /// Ringkasan hitung otomatis yang tampil di bawah field (mis. estimasi upah lembur).
  final Widget Function(Map<String, Object?> values)? preview;

  const PhFormConfig({
    required this.title,
    required this.fields,
    required this.onSave,
    this.note = '',
    this.doneMessage = 'Tersimpan',
    this.saveLabel = 'Simpan',
    this.derive,
    this.preview,
  });
}

Future<void> openPhForm(BuildContext context, PhFormConfig config) => context.push('/form', extra: config);

class PhFormScreen extends StatefulWidget {
  final PhFormConfig config;
  const PhFormScreen({super.key, required this.config});

  @override
  State<PhFormScreen> createState() => _PhFormScreenState();
}

class _PhFormScreenState extends State<PhFormScreen> {
  final _values = <String, Object?>{};
  final _controllers = <String, TextEditingController>{};
  final _errors = <String, String?>{};
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    for (final f in widget.config.fields) {
      switch (f.type) {
        case PhFieldType.text:
        case PhFieldType.multiline:
        case PhFieldType.number:
        case PhFieldType.date:
        case PhFieldType.time:
        case PhFieldType.dateTime:
        case PhFieldType.file:
          final v = f.initial == null ? '' : '${f.initial}';
          _controllers[f.key] = TextEditingController(text: v);
          _values[f.key] = v;
        case PhFieldType.select:
          _values[f.key] = f.initial?.toString() ?? (f.options.isEmpty ? '' : f.options.first.$1);
        case PhFieldType.multi:
          _values[f.key] = <String>[...((f.initial as List<String>?) ?? const [])];
        case PhFieldType.toggle:
          _values[f.key] = f.initial == true;
        case PhFieldType.info:
          _values[f.key] = '';
      }
    }
    _recompute();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recompute() {
    final d = widget.config.derive?.call(_values);
    if (d == null) return;
    d.forEach((k, v) {
      _values[k] = v;
      final c = _controllers[k];
      if (c != null && c.text != '$v') c.text = '$v';
    });
  }

  void _set(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _errors[key] = null;
      _recompute();
    });
  }

  Future<void> _pickDate(PhField f) async {
    final current = DateTime.tryParse('${_values[f.key]}'.split(' ').first) ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2035));
    if (d == null) return;
    if (f.type == PhFieldType.dateTime) {
      if (!mounted) return;
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t == null) return;
      final text = '${isoDate(d)} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      _controllers[f.key]!.text = text;
      _set(f.key, text);
    } else {
      final text = isoDate(d);
      _controllers[f.key]!.text = text;
      _set(f.key, text);
    }
  }

  Future<void> _pickTime(PhField f) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    final text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    _controllers[f.key]!.text = text;
    _set(f.key, text);
  }

  /// Nama file disimpan di `values[key]`, isinya (byte) di `values['${'$'}{key}File']`
  /// sebagai [PhPickedFile] supaya onSave bisa mengunggahnya ke server.
  Future<void> _pickFile(PhField f) async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      _controllers[f.key]!.text = x.name;
      _values['${f.key}File'] = PhPickedFile(x.name, bytes);
      _set(f.key, x.name);
    } catch (_) {
      if (mounted) phToast(context, 'Galeri tidak dapat dibuka di perangkat ini');
    }
  }

  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    var ok = true;
    setState(() {
      for (final f in widget.config.fields) {
        _errors[f.key] = null;
        if (!f.required) continue;
        final v = _values[f.key];
        final empty = v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);
        if (empty) {
          _errors[f.key] = '${f.label} wajib diisi';
          ok = false;
        }
      }
    });
    if (!ok) return;
    setState(() => _saving = true);
    String? error;
    try {
      error = await widget.config.onSave(_values);
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      phToast(context, error);
      return;
    }
    context.pop();
    phToast(context, widget.config.doneMessage);
  }

  InputDecoration _decoration(PhField f, {Widget? suffix}) => InputDecoration(
        filled: true,
        fillColor: AppColors.grey100,
        hintText: f.hint.isEmpty ? null : f.hint,
        errorText: _errors[f.key],
        suffixIcon: suffix,
        suffixText: f.unit.isEmpty ? null : f.unit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: BorderSide.none),
      );

  Widget _label(PhField f) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: AppSpacing.md),
        child: Text('${f.label}${f.required ? ' *' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey700)),
      );

  Widget _field(PhField f) {
    switch (f.type) {
      case PhFieldType.text:
      case PhFieldType.multiline:
      case PhFieldType.number:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          TextField(
            controller: _controllers[f.key],
            readOnly: f.readOnly,
            minLines: f.type == PhFieldType.multiline ? 3 : 1,
            maxLines: f.type == PhFieldType.multiline ? 6 : 1,
            keyboardType: f.type == PhFieldType.number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: _decoration(f),
            onChanged: (v) => _set(f.key, v),
          ),
        ]);
      case PhFieldType.date:
      case PhFieldType.dateTime:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          TextField(
            controller: _controllers[f.key],
            readOnly: true,
            onTap: () => _pickDate(f),
            decoration: _decoration(f, suffix: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.grey500)),
          ),
        ]);
      case PhFieldType.time:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          TextField(
            controller: _controllers[f.key],
            readOnly: true,
            onTap: () => _pickTime(f),
            decoration: _decoration(f, suffix: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.grey500)),
          ),
        ]);
      case PhFieldType.file:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          TextField(
            controller: _controllers[f.key],
            readOnly: true,
            onTap: () => _pickFile(f),
            decoration: _decoration(f, suffix: const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.grey500)).copyWith(hintText: f.hint.isEmpty ? 'Pilih berkas' : f.hint),
          ),
        ]);
      case PhFieldType.select:
        final valid = f.options.any((o) => o.$1 == _values[f.key]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          DropdownButtonFormField<String>(
            initialValue: valid ? _values[f.key] as String : null,
            isExpanded: true,
            decoration: _decoration(f),
            items: [for (final o in f.options) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
            onChanged: f.readOnly ? null : (v) => _set(f.key, v ?? ''),
          ),
        ]);
      case PhFieldType.multi:
        final selected = _values[f.key] as List<String>;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in f.options)
                FilterChip(
                  label: Text(o.$2),
                  selected: selected.contains(o.$1),
                  selectedColor: AppColors.primary50,
                  checkmarkColor: AppColors.primary700,
                  onSelected: (on) {
                    final next = [...selected];
                    on ? next.add(o.$1) : next.remove(o.$1);
                    _set(f.key, next);
                  },
                ),
            ],
          ),
          if (_errors[f.key] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errors[f.key]!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
        ]);
      case PhFieldType.toggle:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(AppRadius.medium)),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                value: _values[f.key] == true,
                onChanged: (v) => _set(f.key, v),
                title: Text(f.label, style: const TextStyle(fontSize: 14)),
                subtitle: f.hint.isEmpty ? null : Text(f.hint, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        );
      case PhFieldType.info:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: widget.config.preview?.call(_values) ?? const SizedBox.shrink(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: phAppBar(c.title),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                children: [
                  if (c.note.isNotEmpty) Text(c.note, style: const TextStyle(fontSize: 12.5, color: AppColors.grey700, height: 1.4)),
                  for (final f in c.fields) _field(f),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PhButton(_saving ? 'Menyimpan...' : c.saveLabel, onPressed: _saving ? null : _submit, color: AppColors.primary700),
            ),
          ],
        ),
      ),
    );
  }
}
