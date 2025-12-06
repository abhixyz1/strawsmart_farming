import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_repository.dart';

// Provider untuk SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Indonesian locale for date formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize SharedPreferences for notification repository
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationRepositoryProvider.overrideWithValue(
          NotificationRepository(prefs),
        ),
      ],
      child: const AppRoot(),
    ),
  );
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'StrawSmart',
      // Localization delegates untuk DatePicker bahasa Indonesia
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('id', 'ID'), // Indonesian
        Locale('en', 'US'), // English (fallback)
      ],
      locale: Locale('id', 'ID'),
      // Light theme - original design
      theme: AppTheme.lightTheme,
      // Dark theme - new dark mode support
      darkTheme: AppTheme.darkTheme,
      // ThemeMode - controlled by provider (system/light/dark)
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
