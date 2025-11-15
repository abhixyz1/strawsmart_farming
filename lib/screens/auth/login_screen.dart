import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          _emailC.text.trim(),
          _passC.text,
        );
    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      data: (user) {
        if (user != null && mounted) context.go('/dashboard');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;
    final errMsg = authState.hasError ? '${authState.error}' : null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF0F2027), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -110,
              right: -70,
              child: _AccentCircle(
                size: 260,
                color: colorScheme.primary.withOpacity(0.18),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -30,
              child: _AccentCircle(
                size: 320,
                color: colorScheme.secondary.withOpacity(0.16),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _GlassPanel(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(36, 42, 36, 46),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AuthHeader(),
                            const SizedBox(height: 28),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: errMsg == null
                                  ? const SizedBox(height: 0)
                                  : _ErrorToast(message: errMsg),
                            ),
                            Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: InputDecorationTheme(
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: colorScheme.primary,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _emailC,
                                      decoration: const InputDecoration(
                                        labelText: 'Email Address',
                                        hintText: 'nama@email.com',
                                        prefixIcon: Icon(
                                          Icons.alternate_email_outlined,
                                        ),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Email wajib diisi.';
                                        }
                                        final ok = RegExp(
                                          r'^[^@]+@[^@]+\.[^@]+',
                                        ).hasMatch(v);
                                        if (!ok) {
                                          return 'Format email tidak valid.';
                                        }
                                        return null;
                                      },
                                      enabled: !loading,
                                    ),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                      controller: _passC,
                                      obscureText: _obscure,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscure
                                              ? 'Tampilkan kata sandi'
                                              : 'Sembunyikan kata sandi',
                                          onPressed: loading
                                              ? null
                                              : () => setState(
                                                    () =>
                                                        _obscure = !_obscure,
                                                  ),
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                        ),
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
                                      enabled: !loading,
                                    ),
                                    const SizedBox(height: 26),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: FilledButton.icon(
                                        onPressed: loading ? null : _submit,
                                        icon: loading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.login_rounded),
                                        label: Text(
                                          loading
                                              ? 'Memproses...'
                                              : 'Masuk ke Dashboard',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: loading
                                            ? null
                                            : () {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Fitur reset kata sandi akan ditambahkan.',
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: const Text('Lupa kata sandi?'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('atau'),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Belum punya akun? Hubungi admin StrawSmart untuk registrasi.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      children: [
        Transform.translate(
          offset: const Offset(0, 10),
          child: Hero(
            tag: 'logo',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/icon.png',
                width: 128,
                height: 128,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Welcome to StrawSmart!',
          style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Pantau dan kelola ekosistem StrawSmart dengan lebih cerdas.',
          style: theme.bodyMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AccentCircle extends StatelessWidget {
  const _AccentCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.02)],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 50,
                spreadRadius: -12,
                offset: Offset(0, 32),
                color: Color(0x33000000),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
