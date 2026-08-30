import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'app_theme.dart';
import 'home_screen.dart';
import 'login_form_screen.dart';

/// Form register, gaya visual mengikuti LoginFormScreen (header lengkung +
/// ilustrasi, kartu putih dengan field pill) supaya alur auth terasa satu
/// kesatuan.
class RegisterFormScreen extends StatefulWidget {
  const RegisterFormScreen({super.key});

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _openLoginForm() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daftar',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.grey900),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      decoration: _inputDecoration(hint: 'Nama lengkap', icon: Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(hint: 'Email', icon: Icons.mail_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.grey400,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password wajib diisi';
                        if (v.length < 6) return 'Password minimal 6 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: _inputDecoration(
                        hint: 'Konfirmasi password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.grey400,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                        if (v != _passwordController.text) return 'Password tidak sama';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        ),
                        child: const Text('Daftar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sudah punya akun? ', style: TextStyle(color: AppColors.grey700, fontSize: 13)),
                        TextButton(
                          onPressed: _openLoginForm,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: const Text('Masuk',
                              style: TextStyle(color: AppColors.primary600, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(60),
        bottomRight: Radius.circular(60),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 44),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary900, AppColors.primary700, AppColors.primary600],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Halo!',
                            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Buat akun untuk mulai pakai Flovig',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _buildIllustration(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return SizedBox(
      width: 108,
      height: 108,
      child: Lottie.asset(
        'assets/lottie/login.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.grey400, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.grey100,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
    );
  }
}
