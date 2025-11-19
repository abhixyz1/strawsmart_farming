import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key for storing theme mode preference in SharedPreferences
const String _themeModeKey = 'theme_mode';

/// Provider untuk ThemeMode preference
/// 
/// Menyimpan pilihan user (light/dark/system) dan persist ke local storage.
/// Default: ThemeMode.system (mengikuti system theme)
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Notifier untuk mengelola ThemeMode state dengan persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  /// Load saved theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      
      if (savedMode != null) {
        state = ThemeMode.values.firstWhere(
          (mode) => mode.name == savedMode,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      print('[ThemeModeNotifier] Error loading theme mode: $e');
      // Fallback to system theme if error
      state = ThemeMode.system;
    }
  }

  /// Save theme mode to SharedPreferences
  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      print('[ThemeModeNotifier] Error saving theme mode: $e');
    }
  }

  /// Set theme mode and save to local storage
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _saveThemeMode(mode);
  }

  /// Toggle between light and dark mode (ignoring system)
  /// Useful for simple dark mode toggle switch
  Future<void> toggleDarkMode() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Check if current mode is dark (either explicitly or via system)
  bool isDarkMode(BuildContext context) {
    if (state == ThemeMode.dark) return true;
    if (state == ThemeMode.light) return false;
    // ThemeMode.system - check platform brightness
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }
}
