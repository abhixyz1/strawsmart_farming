import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/primary_button.dart';
import 'widgets/gradient_background.dart';
import 'widgets/error_toast.dart';

class ForgotPasswordEmailPage extends StatefulWidget {
  const ForgotPasswordEmailPage({super.key});

  @override
  State<ForgotPasswordEmailPage> createState() =>
      _ForgotPasswordEmailPageState();
}

class _ForgotPasswordEmailPageState extends State<ForgotPasswordEmailPage> {
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

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => loading = false);
      context.push('/forgot/otp');
    }
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
                          'Masukkan email untuk mengubah kata sandi',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),

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
                          label: 'Kirim OTP',
                          loadingLabel: 'Mengirim...',
                          loading: loading,
                          onPressed: loading ? null : _submit,
                        ),

                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Kembali ke Login'),
                        )
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


class ForgotPasswordOTPPage extends StatefulWidget {
  const ForgotPasswordOTPPage({super.key});

  @override
  State<ForgotPasswordOTPPage> createState() => _ForgotPasswordOTPPageState();
}

class _ForgotPasswordOTPPageState extends State<ForgotPasswordOTPPage> {
  final _otpC = TextEditingController();
  String? _error;
  bool loading = false;

  Future<void> _verify() async {
    if (_otpC.text.length != 4) {
      setState(() => _error = 'Kode harus 4 digit');
      return;
    }

    setState(() {
      loading = true;
      _error = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (_otpC.text == "1234") {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifikasi berhasil')),
        );
        context.push('/forgot/newpass');
      }
    } else {
      setState(() {
        loading = false;
        _error = 'Kode salah';
      });
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
                          'Ubah Kata Sandi',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masukkan 4 digit kode OTP',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),

                        if (_error != null)
                          ErrorToast(
                            message: _error!,
                            onDismiss: () => setState(() => _error = null),
                          ),

                        TextField(
                          controller: _otpC,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: cs.surface.withOpacity(0.96),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        PrimaryButton(
                          label: 'Verifikasi Kode',
                          loadingLabel: 'Memverifikasi...',
                          loading: loading,
                          onPressed: loading ? null : _verify,
                        ),

                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Kembali'),
                        )
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

class ForgotPasswordNewPassPage extends StatefulWidget {
  const ForgotPasswordNewPassPage({super.key});

  @override
  State<ForgotPasswordNewPassPage> createState() =>
      _ForgotPasswordNewPassPageState();
}

class _ForgotPasswordNewPassPageState
    extends State<ForgotPasswordNewPassPage> {
  final _formKey = GlobalKey<FormState>();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool loading = false;
  bool _obscure = true;
  bool _obscure2 = true;

  Future<void> _updatePass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diperbarui')),
      );
      context.go('/login');
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
                        const SizedBox(height: 24),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _passC,
                                obscureText: _obscure,
                                decoration: _dec(
                                  'Kata Sandi',
                                  _obscure,
                                  () => setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Kata sandi wajib diisi.';
                                  }
                                  if (v.length < 6) {
                                    return 'Minimal 6 karakter.';
                                  }
                                  return null;
                                },
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
                                  if (v != _passC.text) {
                                    return 'Kata sandi tidak sama.';
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

                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Kembali ke Login'),
                        )
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
