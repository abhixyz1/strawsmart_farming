import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import '../../core/services/onboarding_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _heroImagePath = 'assets/images/onboarding_farmer.png';
  static const List<Map<String, String>> _featureSlides = [
    {
      'title': 'Growth Level',
      'description':
          'Pantau perkembangan tanaman stroberi harian dengan grafik pertumbuhan yang diperbarui otomatis.',
    },
    {
      'title': 'Crop Status',
      'description':
          'Lacak kesehatan tanaman dan terima peringatan dini sehingga tindakan dapat diambil sebelum masalah membesar.',
    },
    {
      'title': 'Smart Farming',
      'description':
          'Atur irigasi, nutrisi, dan iklim rumah kaca secara presisi langsung dari aplikasi.',
    },
    {
      'title': 'Nutrient Insights',
      'description':
          'Monitor EC, pH, dan konsumsi nutrisi untuk memastikan media tanam selalu berada pada rentang ideal.',
    },
    {
      'title': 'Harvest Forecast',
      'description':
          'Prediksi panen dan rencana batch otomatis membantu tim menentukan jadwal picking terbaik.',
    },
  ];

  late final PageController _pageController;
  int _currentSlide = 0;
  bool _needsOnboarding = true;
  bool _isCompletingOnboarding = false;
  bool _skipSplash = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initFlow();
  }

  Future<void> _initFlow() async {
    final onboarding = ref.read(onboardingServiceProvider);
    final hasCompleted = await onboarding.hasCompletedOnboarding();
    if (!mounted) return;

    if (hasCompleted) {
      setState(() {
        _skipSplash = true;
        _needsOnboarding = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_navigateBasedOnAuth());
      });
    } else {
      setState(() => _needsOnboarding = true);
    }
  }

  Future<void> _navigateBasedOnAuth() async {
    final authState = ref.read(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;
    if (!mounted) return;
    context.go(isLoggedIn ? '/dashboard' : '/login');
  }

  Future<void> _completeOnboarding() async {
    if (_isCompletingOnboarding) return;
    setState(() => _isCompletingOnboarding = true);
    await ref.read(onboardingServiceProvider).markCompleted();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    unawaited(_navigateBasedOnAuth());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skipSplash) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final mainSplash = KeyedSubtree(
      key: const ValueKey('splash-content'),
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: 0,
            right: 0,
            bottom: 150,
            child: Hero(
              tag: 'login-illustration',
              child: Image.asset(
                _heroImagePath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: true,
            bottom: false,
            left: false,
            right: false,
            child: Column(
              children: [
                _needsOnboarding
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/images/icon.png',
                                      width: 16,
                                      height: 16,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'StrawSmart',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _completeOnboarding,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Lewati'),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(height: 64),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.only(
                    left: _needsOnboarding ? 0 : 24,
                    right: _needsOnboarding ? 0 : 24,
                    bottom: bottomPadding == 0 ? 24 : bottomPadding,
                  ),
                  child: _needsOnboarding
                      ? _OnboardingPanel(
                          textTheme: textTheme,
                          slides: _featureSlides,
                          pageController: _pageController,
                          currentSlide: _currentSlide,
                          onPageChanged: (index) {
                            setState(() => _currentSlide = index);
                          },
                          onGetStarted: _completeOnboarding,
                          isCompleting: _isCompletingOnboarding,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(body: mainSplash);
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.textTheme,
    required this.slides,
    required this.pageController,
    required this.currentSlide,
    required this.onPageChanged,
    required this.onGetStarted,
    required this.isCompleting,
  });

  final TextTheme textTheme;
  final List<Map<String, String>> slides;
  final PageController pageController;
  final int currentSlide;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onGetStarted;
  final bool isCompleting;

  @override
  Widget build(BuildContext context) {
    final isLastSlide = currentSlide == slides.length - 1;
    final primaryLabel = isLastSlide ? 'Get Started' : 'Continue';

    if (isCompleting) {
      return Hero(
        tag: 'login-panel',
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF4EF), Color(0xFFFFFFFF)],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFBE3A34),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );
    }

    return Hero(
      tag: 'login-panel',
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFF4EF), Color(0xFFFFFFFF)],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome to StrawSmart!',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kelola rumah kaca Anda secara cerdas dan terukur.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: slides.length,
                  onPageChanged: onPageChanged,
                  physics: isCompleting
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return _FeatureCard(slide: slide);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: currentSlide == index ? 20 : 8,
                    decoration: BoxDecoration(
                      color: currentSlide == index
                          ? const Color(0xFFBE3A34)
                          : const Color(0xFFE7CFC8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBE3A34),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    if (isLastSlide) {
                      onGetStarted();
                    } else {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.slide});

  final Map<String, String> slide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE8DE), Color(0xFFFFF7F2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD6C8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slide['title'] ?? '',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5A1A2C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                slide['description'] ?? '',
                style: textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF7A3C4C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
