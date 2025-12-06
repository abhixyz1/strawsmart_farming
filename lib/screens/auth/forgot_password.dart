import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'auth_repository.dart';
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
    const radius = 16.0;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.16)),
    );

    return InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: const Color(0xFFC1272D), width: 1.5),
      ),
      errorBorder:
          border.copyWith(borderSide: BorderSide(color: Colors.red.shade400)),
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIconColor: const Color(0xFFC1272D),
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
            'Link akan kadaluarsa dalam 1 jam. '
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
            backgroundColor: const Color(0xFFC1272D),
            body: Stack(
              children: [
                // Background Image
                Positioned(
                  top: -180,
                  left: 0,
                  right: 0,
                  bottom: 150,
                  child: Image.asset(
                    'assets/images/homestrawberry.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
                // Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => _navigateBackToLogin(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Lupa Kata Sandi',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Panel
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      MediaQuery.of(context).padding.bottom + 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF5F5), Color(0xFFFFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 40,
                          offset: Offset(0, -12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_reset,
                            size: 48,
                            color: Color(0xFFC1272D),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Reset Kata Sandi',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: const Color(0xFF111111),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Masukkan email yang terdaftar. Kami akan mengirim link resmi Firebase untuk mengganti kata sandi Anda.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF666666),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ErrorToast(
                                message: _error!,
                                onDismiss: () => setState(() => _error = null),
                              ),
                            ),
                          if (_successMessage != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
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
                                  hintText: 'nama@email.com',
                                  prefixIcon: Icon(Icons.alternate_email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Email wajib diisi.';
                                  }
                                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(v.trim());
                                  return ok ? null : 'Format email tidak valid.';
                                },
                                enabled: !_loading,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC1272D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Kirim Link Reset',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          if (_successMessage != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _navigateBackToLogin(context),
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label: const Text(
                                'Kembali ke Login',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC1272D),
                                side: const BorderSide(
                                  color: Color(0xFFC1272D),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ],
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
