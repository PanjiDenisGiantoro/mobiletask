import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/ai_assistant_repository.dart';
import '../data/ph_remote.dart';
import '../data/ph_store.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/ph_widgets.dart';

/// Membuka modal chat AI Assistant (Runa).
Future<void> showAiAssistantSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AiAssistantSheet(),
  );
}

class _AiAssistantSheet extends StatefulWidget {
  const _AiAssistantSheet();

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  AiAssistantRepository get _repo => AiAssistantRepository.instance;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (preset == null) _inputCtrl.clear();

    final userMsg = AiChatMessage(role: 'user', content: text);
    final botMsg = AiChatMessage(role: 'assistant', isStreaming: true);

    setState(() {
      _sending = true;
      _repo.messages.add(userMsg);
      _repo.messages.add(botMsg);
    });
    _scrollToBottom();

    try {
      final history = _repo.buildHistoryPayload();
      await for (final event in _repo.sendChat(history)) {
        if (!mounted) return;
        setState(() {
          if (event is AiTextChunkEvent) {
            botMsg.content += event.chunk;
          } else if (event is AiActionProposalEvent) {
            if (event.reply.isNotEmpty) botMsg.content = event.reply;
            botMsg.action = event.action;
          }
        });
        _scrollToBottom();
      }
      if (mounted) {
        setState(() {
          botMsg.isStreaming = false;
          if (botMsg.content.isEmpty && botMsg.action == null) {
            botMsg.content = S.tr('Tidak ada balasan dari Runa.', 'No response from Runa.');
          }
        });
      }
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          botMsg.isStreaming = false;
          botMsg.isError = true;
          botMsg.content = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _executeAction(AiChatMessage msg) async {
    final action = msg.action;
    if (action == null || msg.actionExecuting || msg.actionExecuted) return;
    setState(() => msg.actionExecuting = true);
    try {
      final result = await _repo.executeAction(action);
      unawaited(PhStore.instance.sync());
      if (!mounted) return;
      setState(() {
        msg.actionExecuting = false;
        msg.actionExecuted = true;
        msg.actionResultMessage = result.message;
        msg.actionRoute = result.nativeRoute;
      });
      phToast(context, result.message);
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => msg.actionExecuting = false);
      phToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    final sheetHeight = mq.size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header Runa
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.heroStart, AppColors.heroMid, AppColors.accent400],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/runa_ai_avatar.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Runa AI Assistant',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              S.tr(
                                'Tanya panduan, buat proyek, atau tambah tugas',
                                'Ask guides, create projects, or add tasks',
                              ),
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      if (_repo.messages.isNotEmpty)
                        IconButton(
                          tooltip: S.tr('Bersihkan chat', 'Clear chat'),
                          onPressed: _sending
                              ? null
                              : () => setState(() => _repo.clear()),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                        ),
                      IconButton(
                        tooltip: S.tr('Tutup', 'Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Daftar pesan atau empty state dengan prompt cepat
            Expanded(
              child: _repo.messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      itemCount: _repo.messages.length,
                      itemBuilder: (context, i) => _buildBubble(context, _repo.messages[i]),
                    ),
            ),

            // Input bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(fontSize: 13.5, color: c.textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: c.bg,
                          hintText: S.tr('Tanya Runa sesuatu...', 'Ask Runa anything...'),
                          hintStyle: TextStyle(fontSize: 13, color: c.textFaint),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: c.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: FilledButton(
                        onPressed: _sending ? null : () => _send(),
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: AppColors.primary600,
                          shape: const CircleBorder(),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 19, color: Colors.white),
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final c = context.colors;
    final prompts = [
      S.tr('Buat proyek baru bernama Website Company Profile', 'Create a new project named Company Website'),
      S.tr('Buatkan task desain halaman login', 'Create a task to design login page'),
      S.tr('Bagaimana cara mengelola tiket & SLA?', 'How do I manage tickets & SLA?'),
      S.tr('Tips membagi sprint proyek agar rapi', 'Tips to organize project sprints'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 20),
      children: [
        Center(
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7C3AED), AppColors.primary600, AppColors.accent400],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary600.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0F172A),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/runa_ai_avatar.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          S.tr('Halo! Saya Runa 👋', 'Hi! I am Runa 👋'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          S.tr(
            'Asisten AI Flovig yang siap menjawab pertanyaan maupun membantu membuat proyek & tugas.',
            'Your Flovig AI assistant ready to answer questions and help create projects & tasks.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textMuted),
        ),
        const SizedBox(height: 20),
        Text(
          S.tr('Coba tanyakan:', 'Try asking:'),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary),
        ),
        const SizedBox(height: 8),
        ...prompts.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _send(p),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 17, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13, color: c.textFaint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(BuildContext context, AiChatMessage msg) {
    final c = context.colors;
    final isUser = msg.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary600
              : (msg.isError ? c.errorBg : c.surface),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: msg.isError ? AppColors.error.withValues(alpha: 0.4) : c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg.content.isNotEmpty)
              SelectableText(
                msg.content,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.48,
                  color: isUser
                      ? Colors.white
                      : (msg.isError ? AppColors.error : c.textPrimary),
                ),
              ),
            if (msg.isStreaming && msg.content.isEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.tr('Runa sedang mengetik...', 'Runa is typing...'),
                    style: TextStyle(fontSize: 12, color: c.textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            if (msg.action != null) ...[
              if (msg.content.isNotEmpty) const SizedBox(height: 10),
              _buildActionConfirmCard(context, msg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionConfirmCard(BuildContext context, AiChatMessage msg) {
    final c = context.colors;
    final action = msg.action!;

    if (msg.actionExecuted) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.successBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    msg.actionResultMessage ?? S.tr('Berhasil dijalankan', 'Action completed'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            if (msg.actionRoute != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final route = msg.actionRoute!;
                    Navigator.pop(context);
                    context.push(route);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    action.tool == 'create_task'
                        ? S.tr('Buka Tugas', 'Open Task')
                        : S.tr('Buka Proyek', 'Open Project'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (msg.actionDismissed) {
      return Text(
        S.tr('Aksi dibatalkan.', 'Action cancelled.'),
        style: TextStyle(fontSize: 12, color: c.textMuted, fontStyle: FontStyle.italic),
      );
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                action.tool == 'create_task'
                    ? Icons.task_alt_rounded
                    : Icons.create_new_folder_outlined,
                color: c.primary,
                size: 17,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  S.tr('Konfirmasi Aksi', 'Confirm Action'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.label.isNotEmpty ? action.label : action.tool,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: msg.actionExecuting
                      ? null
                      : () => setState(() => msg.actionDismissed = true),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(S.of(context).cancel, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: msg.actionExecuting ? null : () => _executeAction(msg),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: msg.actionExecuting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 17),
                  label: Text(
                    S.tr('Jalankan', 'Execute'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
