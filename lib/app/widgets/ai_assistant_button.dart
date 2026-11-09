import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _runa = 'assets/images/runa.png';
const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.heroStart, AppColors.primary700],
);

/// Tombol bulat Runa (AI Assistant) di pojok kanan bawah, seperti di web.
/// Untuk sekarang hanya tampilan: server belum punya endpoint chat AI
/// untuk aplikasi mobile, jadi jawaban berupa pesan "belum tersedia".
class AiAssistantButton extends StatelessWidget {
  const AiAssistantButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buka AI Assistant',
      child: GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AiAssistantSheet(),
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _gradient,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.primary700.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: ClipOval(child: Image.asset(_runa, fit: BoxFit.cover)),
        ),
      ),
    );
  }
}

class _Msg {
  final bool fromUser;
  final String text;
  const _Msg(this.fromUser, this.text);
}

class _AiAssistantSheet extends StatefulWidget {
  const _AiAssistantSheet();

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  // Disimpan statis supaya riwayat tidak hilang saat panel ditutup-buka.
  static final List<_Msg> _messages = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages
        ..add(_Msg(true, text))
        ..add(const _Msg(false, 'Runa belum tersedia di aplikasi mobile. Untuk sementara, gunakan AI Assistant di versi web.'));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: _gradient),
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: ClipOval(child: Image.asset(_runa, fit: BoxFit.cover)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Runa · AI Assistant', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Tanya soal proyek dan tugasmu', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _empty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Tulis pertanyaan…',
                          filled: true,
                          fillColor: AppColors.grey100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Kirim',
                      onPressed: _send,
                      style: IconButton.styleFrom(backgroundColor: AppColors.primary700, minimumSize: const Size(48, 48)),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(child: Image.asset(_runa, width: 72, height: 72, fit: BoxFit.cover)),
            const SizedBox(height: 12),
            const Text('Halo, aku Runa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            const SizedBox(height: 4),
            const Text(
              'Tanyakan apa saja tentang proyek, tugas, dan tenggatmu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grey700),
            ),
          ],
        ),
      );

  Widget _bubble(_Msg m) => Align(
        alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: m.fromUser ? AppColors.primary700 : AppColors.grey100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(m.text, style: TextStyle(fontSize: 14, color: m.fromUser ? Colors.white : AppColors.grey900)),
        ),
      );
}
