import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_repository.dart';
import 'widgets/glass_card.dart';
import 'widgets/primary_button.dart';
import 'widgets/gradient_background.dart';
import 'widgets/error_toast.dart';

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

class _ForgotPasswordEmailPageState
    extends ConsumerState<ForgotPasswordEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailC = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _successMessage;

  InputDecorationTheme _fieldTheme(ColorScheme cs) {
    const radius = 14.0;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
  borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.16)),
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
  fillColor: cs.surface.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendPasswordResetEmail(_emailC.text.trim());

      if (!mounted) return;
      setState(() {
        _loading = false;
        _successMessage =
            'Link reset kata sandi sudah dikirim ke ${_emailC.text.trim()}. '
            'Silakan cek inbox atau folder spam, lalu ikuti tautannya untuk membuat kata sandi baru.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal mengirim link reset. Periksa koneksi atau coba lagi.';
      });
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                'Masukkan email yang terdaftar. Kami akan mengirim link resmi Firebase untuk mengganti kata sandi Anda.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (_error != null)
                                ErrorToast(
                                  message: _error!,
                                  onDismiss: () =>
                                      setState(() => _error = null),
                                ),
                              if (_successMessage != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _successMessage!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Theme(
                                data: theme.copyWith(
                                  inputDecorationTheme: _fieldTheme(cs),
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: TextFormField(
                                    controller: _emailC,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      hintText: 'contoh@email.com',
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
                                ),
                              ),
                              const SizedBox(height: 24),
                              PrimaryButton(
                                label: 'Kirim Link Reset',
                                loadingLabel: 'Mengirim...',
                                loading: _loading,
                                onPressed: _loading ? null : _submit,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  debugPrint(
                                      '🔙 [EMAIL PAGE] Button Kembali ke Login diklik!');
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
