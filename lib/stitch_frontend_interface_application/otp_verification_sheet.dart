import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'app_theme.dart';

/// Bottom sheet verifikasi OTP untuk alur "Lupa Password?" di halaman
/// login. Kode demo yang valid: 123456 (belum tersambung ke backend/SMS).
Future<void> showOtpVerificationSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _OtpVerificationSheet(),
  );
}

class _OtpVerificationSheet extends StatefulWidget {
  const _OtpVerificationSheet();

  @override
  State<_OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<_OtpVerificationSheet> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verify(String code) {
    if (code == '123456') {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verifikasi berhasil, silakan buat password baru')),
      );
    } else {
      setState(() => _error = 'Kode salah, coba lagi (demo: 123456)');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.grey900),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
    );
    final focusedTheme = defaultTheme.copyDecorationWith(
      border: Border.all(color: AppColors.heroStart, width: 1.6),
    );
    final errorTheme = defaultTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 1.6),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const Text(
                'Verifikasi OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Masukkan 6 digit kode yang dikirim ke email kamu',
                style: TextStyle(fontSize: 12.5, color: AppColors.grey700),
              ),
              const SizedBox(height: AppSpacing.lg),
              Pinput(
                length: 6,
                controller: _pinController,
                defaultPinTheme: defaultTheme,
                focusedPinTheme: focusedTheme,
                errorPinTheme: errorTheme,
                forceErrorState: _error != null,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onCompleted: _verify,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
