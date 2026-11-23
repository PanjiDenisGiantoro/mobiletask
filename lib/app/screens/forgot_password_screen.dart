import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../widgets/ph_widgets.dart';

/// Halaman Lupa Password: kirim tautan/token reset ke email & opsi reset dengan token.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _tokenCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _sending = false;
  bool _resetting = false;
  bool _emailSent = false;
  bool _showTokenForm = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _statusMsg;

  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendResetEmail() async {
    if (_sending) return;
    if (!_emailSent && _emailFormKey.currentState?.validate() != true) return;
    setState(() => _sending = true);
    try {
      final (msg, resendAfter) = await AuthRepository.instance.forgotPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _showTokenForm = true;
        _statusMsg = msg;
      });
      _startCooldown(resendAfter);
    } on AuthException catch (e) {
      if (mounted) phToast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (_resetting || _resetFormKey.currentState?.validate() != true) return;
    setState(() => _resetting = true);
    try {
      final msg = await AuthRepository.instance.resetPassword(
        email: _emailCtrl.text.trim(),
        token: _tokenCtrl.text.trim(),
        password: _pwdCtrl.text,
        confirmPassword: _confirmPwdCtrl.text,
      );
      if (!mounted) return;
      phToast(context, msg);
      context.pop();
    } on AuthException catch (e) {
      if (mounted) phToast(context, e.message);
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 10,
              16,
              28,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.heroStart, AppColors.heroMid, AppColors.heroEnd],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.tr('Lupa Password', 'Forgot Password'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            S.tr(
                              'Masukkan email akun Anda untuk menerima tautan reset password.',
                              'Enter your account email to receive a password reset link.',
                            ),
                            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PhCard(
                    child: _emailSent ? _buildSentCard(context) : _buildEmailForm(context),
                  ),
                  if (_showTokenForm) ...[
                    const SizedBox(height: 14),
                    PhCard(child: _buildTokenResetForm(context)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(BuildContext context) {
    final c = context.colors;
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.tr('Email Terdaftar', 'Registered Email'),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: 14, color: c.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.bg,
              hintText: 'nama@perusahaan.com',
              prefixIcon: Icon(Icons.email_outlined, color: c.textMuted, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return S.tr('Email wajib diisi', 'Email is required');
              if (!s.contains('@') || !s.contains('.')) {
                return S.tr('Format email tidak valid', 'Invalid email format');
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _sending ? null : _sendResetEmail,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                S.tr('Kirim Tautan Reset', 'Send Reset Link'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _showTokenForm = !_showTokenForm),
            child: Text(
              _showTokenForm
                  ? S.tr('Sembunyikan form token', 'Hide token form')
                  : S.tr('Sudah punya kode/token reset?', 'Already have a reset token?'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentCard(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: c.successBg, shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          S.tr('Cek Email Anda', 'Check Your Email'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          _statusMsg ??
              S.tr(
                'Kami telah mengirim instruksi reset password ke ${_emailCtrl.text.trim()}.',
                'We sent password reset instructions to ${_emailCtrl.text.trim()}.',
              ),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cooldown > 0 || _sending ? null : _sendResetEmail,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _cooldown > 0
                      ? S.tr('Kirim ulang (${_cooldown}s)', 'Resend (${_cooldown}s)')
                      : S.tr('Kirim Ulang', 'Resend Email'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  S.tr('Kembali Login', 'Back to Login'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _showTokenForm = !_showTokenForm),
          child: Text(
            S.tr('Masukkan token reset secara manual', 'Enter reset token manually'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenResetForm(BuildContext context) {
    final c = context.colors;
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.tr('Reset Password dengan Token', 'Reset Password with Token'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tokenCtrl,
            style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.bg,
              labelText: S.tr('Kode / Token Reset', 'Reset Token'),
              prefixIcon: Icon(Icons.vpn_key_outlined, size: 19, color: c.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? S.tr('Token wajib diisi', 'Token is required')
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pwdCtrl,
            obscureText: _obscure1,
            style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.bg,
              labelText: S.tr('Password Baru', 'New Password'),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 19, color: c.textMuted),
              suffixIcon: IconButton(
                icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v ?? '').length < 8
                ? S.tr('Minimal 8 karakter', 'Minimum 8 characters')
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _confirmPwdCtrl,
            obscureText: _obscure2,
            style: TextStyle(fontSize: 13.5, color: c.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.bg,
              labelText: S.tr('Konfirmasi Password Baru', 'Confirm New Password'),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 19, color: c.textMuted),
              suffixIcon: IconButton(
                icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => v != _pwdCtrl.text
                ? S.tr('Konfirmasi password tidak cocok', 'Passwords do not match')
                : null,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _resetting ? null : _submitNewPassword,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _resetting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      S.tr('Simpan Password Baru', 'Save New Password'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
