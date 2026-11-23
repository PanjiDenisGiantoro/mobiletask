import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../utils/ph_format.dart';
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

/// File yang dipilih lewat field [PhFieldType.file] atau pemilih lampiran.
class PhPickedFile {
  final String name;
  final List<int> bytes;
  const PhPickedFile(this.name, this.bytes);
}

/// Buka pemilih berkas/gambar dan kembalikan [PhPickedFile] bila dipilih.
Future<PhPickedFile?> pickPhFile([BuildContext? context]) async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return PhPickedFile(x.name, bytes);
  } catch (_) {
    if (context != null && context.mounted) {
      phToast(context, 'Galeri tidak dapat dibuka di perangkat ini');
    }
    return null;
  }
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
        fillColor: f.readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
        hintText: f.hint.isEmpty ? null : f.hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        errorText: _errors[f.key],
        errorStyle: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
        suffixIcon: suffix,
        suffixText: f.unit.isEmpty ? null : f.unit,
        suffixStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      );

  Widget _label(PhField f) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: RichText(
          text: TextSpan(
            text: f.label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
            children: [
              if (f.required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
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
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
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
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            onTap: () => _pickDate(f),
            decoration: _decoration(
              f,
              suffix: const Icon(Icons.calendar_today_outlined, size: 17, color: Color(0xFF2563EB)),
            ),
          ),
        ]);
      case PhFieldType.time:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          TextField(
            controller: _controllers[f.key],
            readOnly: true,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            onTap: () => _pickTime(f),
            decoration: _decoration(
              f,
              suffix: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
            ),
          ),
        ]);
      case PhFieldType.file:
        final fileName = '${_values[f.key] ?? ''}'.trim();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickFile(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errors[f.key] != null ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Choose File',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName.isEmpty ? (f.hint.isEmpty ? 'Belum ada berkas dipilih' : f.hint) : fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: fileName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        fontWeight: fileName.isEmpty ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.attach_file_rounded, size: 17, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          if (_errors[f.key] != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 12),
              child: Text(_errors[f.key]!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5)),
            ),
        ]);
      case PhFieldType.select:
        final valid = f.options.any((o) => o.$1 == _values[f.key]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(f),
          DropdownButtonFormField<String>(
            initialValue: valid ? _values[f.key] as String : null,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
            decoration: _decoration(f),
            items: [
              for (final o in f.options)
                DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
            ],
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
                  label: Text(o.$2, style: const TextStyle(fontSize: 12)),
                  selected: selected.contains(o.$1),
                  selectedColor: const Color(0xFFEFF6FF),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selected.contains(o.$1) ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                  checkmarkColor: const Color(0xFF2563EB),
                  onSelected: (on) {
                    final next = [...selected];
                    on ? next.add(o.$1) : next.remove(o.$1);
                    _set(f.key, next);
                  },
                ),
            ],
          ),
          if (_errors[f.key] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_errors[f.key]!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5)),
            ),
        ]);
      case PhFieldType.toggle:
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                activeThumbColor: const Color(0xFF2563EB),
                value: _values[f.key] == true,
                onChanged: (v) => _set(f.key, v),
                title: Text(f.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                subtitle: f.hint.isEmpty ? null : Text(f.hint, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ),
            ),
          ),
        );
      case PhFieldType.info:
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: widget.config.preview?.call(_values) ?? const SizedBox.shrink(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: phAppBar(c.title),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (c.note.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    c.note,
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final f in c.fields) _field(f),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  c.saveLabel,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
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
    );
  }
}
