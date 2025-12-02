import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key for storing onboarding completion status.
const _kOnboardingKey = 'strawsmart_has_seen_onboarding';

/// Simple persistence service to track whether the user has completed
/// the first-run onboarding experience.
class OnboardingService {
  const OnboardingService();

  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kOnboardingKey) ?? false;
    } catch (e) {
      debugPrint('[OnboardingService] hasCompletedOnboarding error: $e');
      return false;
    }
  }

  Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingKey, true);
    } catch (e) {
      debugPrint('[OnboardingService] markCompleted error: $e');
    }
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return const OnboardingService();
});
