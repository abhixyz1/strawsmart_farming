import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/login_constants.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'validators/password_validator.dart';
import 'widgets/error_toast.dart';
import 'forgot_password.dart';

/// Login screen dengan responsive layout, keyboard handling, dan accessibility
/// Optimized untuk fit dalam 1 viewport tanpa scroll di mobile (>=667px height)
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
  String? _currentError;
  bool _loginSuccess = false;

  @override
  void initState() {
    super.initState();
    // Preload background image untuk performa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        const AssetImage('assets/images/onboarding_farmer.png'),
        context,
      );
    });
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard to ensure smooth transition
    FocusScope.of(context).unfocus();

    setState(() {
      _currentError = null;
      _loginSuccess = false;
    });

    await ref
        .read(authControllerProvider.notifier)
        .signIn(_emailC.text.trim(), _passC.text);

    final state = ref.read(authControllerProvider);

    if (state.hasValue && state.value != null) {
      if (mounted) {
        setState(() => _loginSuccess = true);

        // Delay navigation to show success animation
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          context.go('/dashboard');
        }
      }
    } else if (state.hasError) {
      if (mounted) {
        setState(() {
          _currentError = state.error.toString();
          _loginSuccess = false;
        });
      }
    }
  }

  void _showContactAdminInfo() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Hubungi admin StrawSmart untuk membuat akun baru.'),
          duration: Duration(seconds: 3),
        ),
      );
  }

  /// Login button dengan efek morph animation (Fade + Scale)
  Widget _buildLoginButton({required bool loading}) {
    const duration = Duration(milliseconds: 400);

    // Determine current state
    final isSuccess = _loginSuccess;
    final isLoading = loading && !isSuccess;

    return SizedBox(
      height: LoginConstants.buttonHeight,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        child: isSuccess
            ? _buildSuccessButton(key: const ValueKey('success'))
            : _buildNormalButton(
                key: const ValueKey('normal'),
                loading: isLoading,
              ),
      ),
    );
  }

  /// Tombol normal (idle/loading state)
  Widget _buildNormalButton({required Key key, required bool loading}) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: Colors.white,
    );

    return Semantics(
      key: key,
      button: true,
      enabled: !loading,
      label: loading ? 'Memproses...' : 'Login',
      child: ElevatedButton(
        onPressed: loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              LoginConstants.buttonBorderRadius,
            ),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: loading
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : [const Color(0xFFC64B40), const Color(0xFFE87058)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(
              LoginConstants.buttonBorderRadius,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: LoginConstants.shortDuration,
              child: loading
                  ? Row(
                      key: const ValueKey('loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Memproses...', style: textStyle),
                      ],
                    )
                  : Row(
                      key: const ValueKey('idle'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text('Login', style: textStyle),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol sukses dengan icon check hijau
  Widget _buildSuccessButton({required Key key}) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      color: Colors.white,
    );

    return Container(
      key: key,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(LoginConstants.buttonBorderRadius),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text('Berhasil!', style: textStyle),
          ],
        ),
      ),
    );
  }

  InputDecorationTheme _buildFieldTheme(ColorScheme colorScheme) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LoginConstants.inputBorderRadius),
      borderSide: BorderSide(
        color: colorScheme.outline.withValues(alpha: 0.16),
      ),
    );

    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
      prefixIconColor: colorScheme.primary,
      suffixIconColor: colorScheme.primary,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;
    final errMsg = authState.hasError ? '${authState.error}' : _currentError;

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final viewInsets = mediaQuery.viewInsets;
    final safePadding = mediaQuery.padding;
    final isLandscape = LoginConstants.isLandscape(context);
    final screenHeight = size.height;

    final horizontalPadding = LoginConstants.getHorizontalPadding(size.width);
    final cardPadding = LoginConstants.getCardPadding(screenHeight);
    final spacing = LoginConstants.getSpacing(screenHeight);

    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Scaffold(
            backgroundColor: const Color(0xFFC1272D),
            resizeToAvoidBottomInset: false,
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
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/icon.png',
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'StrawSmart',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart Greenhouse Management',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (isLandscape && constraints.maxWidth > 900) {
                      return _buildLandscapeLayout(
                        loading: loading,
                        errMsg: errMsg,
                        theme: theme,
                        colorScheme: colorScheme,
                        horizontalPadding: horizontalPadding,
                        cardPadding: cardPadding,
                        spacing: spacing,
                        screenHeight: constraints.maxHeight,
                        viewInsets: viewInsets,
                        bottomSafeArea: safePadding.bottom,
                      );
                    }

                    return _buildPortraitLayout(
                      loading: loading,
                      errMsg: errMsg,
                      theme: theme,
                      colorScheme: colorScheme,
                      horizontalPadding: horizontalPadding,
                      cardPadding: cardPadding,
                      spacing: spacing,
                      viewInsets: viewInsets,
                      screenHeight: screenHeight,
                      bottomSafeArea: safePadding.bottom,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Portrait layout untuk mobile dengan panel bawah seperti splash
  Widget _buildPortraitLayout({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double horizontalPadding,
    required double cardPadding,
    required double spacing,
    required EdgeInsets viewInsets,
    required double screenHeight,
    required double bottomSafeArea,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: LoginConstants.longDuration,
        curve: Curves.easeOutCubic,
        child: _buildLoginPanel(
          loading: loading,
          errMsg: errMsg,
          theme: theme,
          colorScheme: colorScheme,
          cardPadding: cardPadding,
          spacing: spacing,
          screenHeight: screenHeight,
          isLandscape: false,
          viewInsetsBottom: viewInsets.bottom,
        ),
      ),
    );
  }

  /// Landscape layout untuk tablet/desktop dengan panel terpusat
  Widget _buildLandscapeLayout({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double horizontalPadding,
    required double cardPadding,
    required double spacing,
    required double screenHeight,
    required EdgeInsets viewInsets,
    required double bottomSafeArea,
  }) {
    final bottomPadding = viewInsets.bottom > 0
        ? viewInsets.bottom + 24
        : bottomSafeArea + 32;

    return Align(
      alignment: Alignment.center,
      child: AnimatedPadding(
        duration: LoginConstants.mediumDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding + 24,
          48,
          horizontalPadding + 24,
          bottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _buildLoginPanel(
            loading: loading,
            errMsg: errMsg,
            theme: theme,
            colorScheme: colorScheme,
            cardPadding: cardPadding,
            spacing: spacing,
            screenHeight: screenHeight,
            isLandscape: true,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double cardPadding,
    required double spacing,
    required double screenHeight,
    required bool isLandscape,
    double viewInsetsBottom = 0,
  }) {
    final borderRadius = isLandscape
        ? BorderRadius.circular(32)
        : const BorderRadius.vertical(top: Radius.circular(40));

    final panelPadding = EdgeInsets.fromLTRB(
      cardPadding + (isLandscape ? 20 : 24),
      cardPadding + (isLandscape ? 24 : 32),
      cardPadding + (isLandscape ? 20 : 24),
      viewInsetsBottom > 0
          ? viewInsetsBottom + cardPadding
          : cardPadding + (isLandscape ? 24 : 28),
    );

    return Hero(
      tag: 'login-panel',
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: LoginConstants.longDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF5F5), Color(0xFFFFFFFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC1272D).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
              const BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: panelPadding,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _buildFormContent(
                loading: loading,
                errMsg: errMsg,
                theme: theme,
                colorScheme: colorScheme,
                spacing: spacing,
                screenHeight: screenHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Form content yang digunakan di kedua layout
  Widget _buildFormContent({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double spacing,
    required double screenHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Login',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFC1272D),
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
        ),
        SizedBox(height: spacing * 0.9),
        AnimatedSwitcher(
          duration: LoginConstants.mediumDuration,
          child: errMsg == null
              ? const SizedBox.shrink()
              : ErrorToast(
                  key: ValueKey(errMsg),
                  message: errMsg,
                  onDismiss: () {
                    if (mounted) {
                      setState(() => _currentError = null);
                    }
                  },
                ),
        ),
        // Form fields
        Theme(
          data: theme.copyWith(
            inputDecorationTheme: _buildFieldTheme(colorScheme),
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email field
                  Semantics(
                    label: 'Alamat email',
                    textField: true,
                    child: TextFormField(
                      controller: _emailC,
                      decoration: const InputDecoration(
                        labelText: 'Alamat email',
                        hintText: 'nama@email.com',
                        prefixIcon: Icon(Icons.alternate_email_outlined),
                      ),
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email wajib diisi.';
                        }
                        final ok = RegExp(
                          r'^[^@]+@[^@]+\.[^@]+',
                        ).hasMatch(v.trim());
                        if (!ok) {
                          return 'Format email tidak valid.';
                        }
                        return null;
                      },
                      enabled: !loading,
                    ),
                  ),
                  SizedBox(height: spacing),
                  // Password field
                  Semantics(
                    label: 'Kata sandi',
                    textField: true,
                    obscured: _obscure,
                    child: TextFormField(
                      controller: _passC,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: loading
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!loading) _submit();
                      },
                      validator: PasswordValidator.validate,
                      enabled: !loading,
                    ),
                  ),
                  SizedBox(height: spacing * 0.5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordEmailPage(),
                                ),
                              );
                            },
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  SizedBox(height: spacing * 0.5),
                  _buildLoginButton(loading: loading),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: spacing * 0.5),
        Center(
          child: TextButton(
            onPressed: loading ? null : _openWhatsAppAdmin,
            child: const Text('Belum punya akun? Hubungi admin'),
          ),
        ),
      ],
    );
  }

  /// Open email client to contact admin
  void _openWhatsAppAdmin() async {
    const adminEmail = 'erfinbrian@gmail.com';
    const subject = 'Pendaftaran Akun StrawSmart';
    const body = 'Halo admin, saya ingin mendaftar akun StrawSmart.';
    final url = Uri.parse(
      'mailto:$adminEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka email client. Pastikan ada aplikasi email terinstall.'),
          ),
        );
      }
    }
  }
}

class _StrawberryPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Draw decorative circles pattern
    for (var i = 0; i < 15; i++) {
      final x = (i * size.width / 6) % size.width;
      final y = (i * size.height / 8) % size.height;
      canvas.drawCircle(Offset(x, y), 30, paint);
    }

    // Draw strawberry dots pattern
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 40; i++) {
      final x = (i * 73 + 20) % size.width;
      final y = (i * 97 + 40) % size.height;
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
