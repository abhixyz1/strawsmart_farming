import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/login_constants.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'validators/password_validator.dart';
import 'widgets/error_toast.dart';
import 'widgets/glass_card.dart';
import 'widgets/gradient_background.dart';
import 'widgets/login_header.dart';
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
      precacheImage(
        const AssetImage('assets/images/homestrawberry.jpg'),
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
    
    await ref.read(authControllerProvider.notifier).signIn(
          _emailC.text.trim(),
          _passC.text,
        );
    
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
            borderRadius: BorderRadius.circular(LoginConstants.buttonBorderRadius),
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
                  : [const Color(0xFFB31217), const Color(0xFFED213A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(LoginConstants.buttonBorderRadius),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        const Icon(Icons.login_rounded, color: Colors.white, size: 20),
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
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
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
  borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.16)),
    );

    return InputDecorationTheme(
  filled: true,
  fillColor: colorScheme.surface.withValues(alpha: 0.96),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(
  color: colorScheme.onSurface.withValues(alpha: 0.75),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
  color: colorScheme.onSurface.withValues(alpha: 0.5),
      ),
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
    final size = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isLandscape = LoginConstants.isLandscape(context);
    final screenHeight = size.height;
    
    final verticalPadding = LoginConstants.getVerticalPadding(screenHeight);
    final horizontalPadding = LoginConstants.getHorizontalPadding(size.width);
    final cardPadding = LoginConstants.getCardPadding(screenHeight);
    final spacing = LoginConstants.getSpacing(screenHeight);

    // Paksa gunakan tema terang untuk halaman login
    return Theme(
      data: AppTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          
          return Scaffold(
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                const GradientBackground(),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Untuk landscape atau tablet, gunakan layout horizontal
                      if (isLandscape && constraints.maxWidth > 700) {
                        return _buildLandscapeLayout(
                          loading: loading,
                          errMsg: errMsg,
                          theme: theme,
                          colorScheme: colorScheme,
                          cardPadding: cardPadding,
                          spacing: spacing,
                        );
                      }
                      
                      // Default portrait layout
                      return _buildPortraitLayout(
                        loading: loading,
                        errMsg: errMsg,
                        theme: theme,
                        colorScheme: colorScheme,
                        verticalPadding: verticalPadding,
                        horizontalPadding: horizontalPadding,
                        cardPadding: cardPadding,
                        spacing: spacing,
                        viewInsets: viewInsets,
                        screenHeight: screenHeight,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Portrait layout untuk mobile
  Widget _buildPortraitLayout({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double verticalPadding,
    required double horizontalPadding,
    required double cardPadding,
    required double spacing,
    required EdgeInsets viewInsets,
    required double screenHeight,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: verticalPadding,
          bottom: viewInsets.bottom + verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: LoginConstants.maxCardWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoginHeader(),
              SizedBox(height: spacing),
              GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Landscape layout untuk tablet/desktop
  Widget _buildLandscapeLayout({
    required bool loading,
    required String? errMsg,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double cardPadding,
    required double spacing,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LoginConstants.maxLayoutWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Left side - Header
              Expanded(
                child: Center(
                  child: const LoginHeader(),
                ),
              ),
              const SizedBox(width: 32),
              // Right side - Form
              Expanded(
                child: GlassCard(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(cardPadding),
                    child: _buildFormContent(
                      loading: loading,
                      errMsg: errMsg,
                      theme: theme,
                      colorScheme: colorScheme,
                      spacing: spacing,
                      screenHeight: 900, // Medium size for landscape
                    ),
                  ),
                ),
              ),
            ],
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
          'Masuk ke StrawSmart',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: spacing * 0.5),
        Text(
          'Kelola rumah kaca stroberi Anda dengan insight nutrisi, suhu, dan panen yang terpusat.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: spacing),
        // Error toast
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
                        final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(v.trim());
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
                        helperText: PasswordValidator.helperText,
                        helperMaxLines: 2,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: loading
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
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
                  SizedBox(height: spacing),
                  // Login button dengan morph animation
                  _buildLoginButton(loading: loading),
                  // Forgot password - hanya tampil di layar medium/large
                  if (screenHeight >= LoginConstants.smallScreenHeight) ...[
                    SizedBox(height: spacing * 0.75),
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
                  ],
                ],
              ),
            ),
          ),
        ),
        // Footer text - hanya tampil di layar medium/large
        if (screenHeight >= LoginConstants.smallScreenHeight) ...[
          SizedBox(height: spacing),
          Divider(color: colorScheme.outline.withValues(alpha: 0.26)),
          SizedBox(height: spacing * 0.75),
          Text(
            'Belum punya akun? Hubungi admin StrawSmart untuk registrasi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
