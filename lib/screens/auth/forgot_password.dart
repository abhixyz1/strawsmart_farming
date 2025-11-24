import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_repository.dart'; // Import otpServiceProvider dari sini
import 'validators/password_validator.dart';
import 'widgets/glass_card.dart';
import 'widgets/primary_button.dart';
import 'widgets/gradient_background.dart';
import 'widgets/error_toast.dart';
import 'widgets/otp_input_field.dart';

void _navigateBackToLogin(BuildContext context) {
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
  Future.microtask(() => router.go('/login'));
}

class ForgotPasswordEmailPage extends ConsumerStatefulWidget {
  const ForgotPasswordEmailPage({super.key});

  @override
  ConsumerState<ForgotPasswordEmailPage> createState() =>
      _ForgotPasswordEmailPageState();
}

class _ForgotPasswordEmailPageState extends ConsumerState<ForgotPasswordEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailC = TextEditingController();
  String? _error;
  bool loading = false;

  // Perbaikan: Ganti LoginConstants.inputBorderRadius → 14.0
  InputDecorationTheme _fieldTheme(ColorScheme cs) {
    const radius = 14.0;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: cs.outline.withOpacity(0.16)),
    );

    return InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder:
          border.copyWith(borderSide: BorderSide(color: Colors.red.shade400)),
      filled: true,
      fillColor: cs.surface.withOpacity(0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final otpService = ref.read(otpServiceProvider);
      
      // Generate dan kirim OTP
      await otpService.generateAndSendOTP(_emailC.text.trim());

      if (mounted) {
        setState(() => loading = false);
        
        // Navigate ke halaman OTP dengan email sebagai argumen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ForgotPasswordOTPPage(email: _emailC.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _error = 'Gagal mengirim OTP. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Paksa gunakan tema terang untuk halaman forgot password
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final theme = Theme.of(context);

          return Scaffold(
            body: Stack(
              children: [
                const GradientBackground(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Lupa Kata Sandi',
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                        const SizedBox(height: 8),
                        Text(
                          'Masukkan email untuk menerima kode OTP',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_error != null)
                          ErrorToast(
                            message: _error!,
                            onDismiss: () => setState(() => _error = null),
                          ),

                        Theme(
                          data: theme.copyWith(
                            inputDecorationTheme: _fieldTheme(cs),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailC,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'alamat email',
                                    prefixIcon:
                                        Icon(Icons.alternate_email_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Email wajib diisi.';
                                    }
                                    final ok = RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(v.trim());
                                    return ok ? null : 'Format email tidak valid.';
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        PrimaryButton(
                          label: 'Kirim Kode OTP',
                          loadingLabel: 'Mengirim...',
                          loading: loading,
                          onPressed: loading ? null : _submit,
                        ),

                        const SizedBox(height: 16),
                        
                        OutlinedButton.icon(
                          onPressed: () {
                            debugPrint('🔙 [EMAIL PAGE] Button Kembali ke Login diklik!');
                            _navigateBackToLogin(context);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Kembali ke Login'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
        },
      ),
    );
  }
}


class ForgotPasswordOTPPage extends ConsumerStatefulWidget {
  const ForgotPasswordOTPPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ForgotPasswordOTPPage> createState() => _ForgotPasswordOTPPageState();
}

class _ForgotPasswordOTPPageState extends ConsumerState<ForgotPasswordOTPPage> {
  String _currentOTP = '';
  String? _error;
  bool loading = false;
  int _countdown = 60; // 60 seconds countdown untuk resend
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
      _canResend = false;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _canResend = true;
          }
        });
        return _countdown > 0;
      }
      return false;
    });
  }

  Future<void> _verify(String otp) async {
    if (otp.length != 6) {
      setState(() => _error = 'Kode OTP harus 6 digit');
      return;
    }

    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final otpService = ref.read(otpServiceProvider);
      final isValid = await otpService.verifyOTP(
        email: widget.email,
        otp: otp,
      );

      if (mounted) {
        if (isValid) {
          setState(() => loading = false);
          
          // Navigate ke halaman ganti password
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ForgotPasswordNewPassPage(email: widget.email),
            ),
          );
        } else {
          setState(() {
            loading = false;
            _error = 'Kode OTP salah atau sudah kadaluarsa. Silakan coba lagi.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _error = 'Terjadi kesalahan. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final otpService = ref.read(otpServiceProvider);
      await otpService.generateAndSendOTP(widget.email);

      if (mounted) {
        setState(() => loading = false);
        _startCountdown();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kode OTP baru telah dikirim ke ${widget.email}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _error = 'Gagal mengirim ulang OTP. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paksa gunakan tema terang untuk halaman OTP
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final theme = Theme.of(context);

          return Scaffold(
            body: Stack(
              children: [
                const GradientBackground(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                        Text(
                          'Verifikasi Kode OTP',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masukkan 6 digit kode OTP yang telah dikirim ke ${widget.email}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        if (_error != null)
                          ErrorToast(
                            message: _error!,
                            onDismiss: () => setState(() => _error = null),
                          ),

                        const SizedBox(height: 16),

                        // OTP Input Field (6 kotak)
                        OTPInputField(
                          onCompleted: (otp) {
                            setState(() => _currentOTP = otp);
                            if (!loading) {
                              _verify(otp);
                            }
                          },
                          onChanged: (otp) {
                            setState(() {
                              _currentOTP = otp;
                              _error = null; // Clear error saat user mulai ketik
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // Loading indicator atau verify button
                        if (loading)
                          const CircularProgressIndicator()
                        else if (_currentOTP.length == 6)
                          PrimaryButton(
                            label: 'Verifikasi Kode',
                            loadingLabel: 'Verifikasi...',
                            loading: false,
                            onPressed: () => _verify(_currentOTP),
                          ),

                        const SizedBox(height: 20),

                        // Resend OTP dengan countdown
                        if (_canResend)
                          TextButton(
                            onPressed: loading ? null : _resendOTP,
                            child: const Text('Kirim Ulang Kode OTP'),
                          )
                        else
                          Text(
                            'Kirim ulang dalam $_countdown detik',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: () {
                            debugPrint('🔙 [OTP PAGE] Button Kembali ke Login diklik!');
                            _navigateBackToLogin(context);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Kembali ke Login'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
        },
      ),
    );
  }
}

class ForgotPasswordNewPassPage extends ConsumerStatefulWidget {
  const ForgotPasswordNewPassPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ForgotPasswordNewPassPage> createState() =>
      _ForgotPasswordNewPassPageState();
}

class _ForgotPasswordNewPassPageState
    extends ConsumerState<ForgotPasswordNewPassPage> {
  final _formKey = GlobalKey<FormState>();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  String? _error;
  bool loading = false;
  bool _obscure = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _updatePass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      _error = null;
    });

    try {
      final otpService = ref.read(otpServiceProvider);
      
      // Simpan password sementara ke RTDB
      await otpService.saveNewPassword(
        email: widget.email,
        newPassword: _passC.text,
      );

      if (mounted) {
        setState(() => loading = false);
        
        // Cleanup OTP
        await otpService.deleteOTP(widget.email);
        
        // Show simple success dialog
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green.shade600,
              size: 64,
            ),
            title: const Text(
              'Password Berhasil Diganti',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Password Anda telah berhasil diperbarui.\n\n'
              'Silakan login dengan password baru Anda.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  _navigateBackToLogin(context);
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Ke Halaman Login'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _error = 'Gagal menyimpan password. Silakan coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Paksa gunakan tema terang untuk halaman new password
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final theme = Theme.of(context);

          InputDecoration _dec(String label, bool obs, VoidCallback toggle) {
            return InputDecoration(
              labelText: label,
              filled: true,
              fillColor: cs.surface.withOpacity(0.96),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obs ? Icons.visibility : Icons.visibility_off),
                onPressed: toggle,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            );
          }

          return Scaffold(
            body: Stack(
              children: [
                const GradientBackground(),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Buat Kata Sandi Baru',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masukkan kata sandi baru Anda',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Untuk akun: ${widget.email}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _passC,
                                obscureText: _obscure,
                                decoration: _dec(
                                  'Kata Sandi Baru',
                                  _obscure,
                                  () => setState(() => _obscure = !_obscure),
                                ).copyWith(
                                  helperText: PasswordValidator.helperText,
                                  helperMaxLines: 2,
                                ),
                                validator: PasswordValidator.validate,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _confirmC,
                                obscureText: _obscure2,
                                decoration: _dec(
                                  'Konfirmasi Kata Sandi',
                                  _obscure2,
                                  () => setState(() => _obscure2 = !_obscure2),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Konfirmasi kata sandi diperlukan';
                                  }
                                  if (v != _passC.text) {
                                    return 'Kata sandi tidak cocok';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        PrimaryButton(
                          label: 'Update Kata Sandi',
                          loadingLabel: 'Memperbarui...',
                          loading: loading,
                          onPressed: loading ? null : _updatePass,
                        ),

                        const SizedBox(height: 16),
                        
                        OutlinedButton.icon(
                          onPressed: () {
                            debugPrint('🔙 [NEW PASSWORD PAGE] Button Kembali ke Login diklik!');
                            _navigateBackToLogin(context);
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Kembali ke Login'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
        },
      ),
    );
  }
}
