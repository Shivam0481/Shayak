import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shayak/l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'data/models/request_model.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';
import 'presentation/screens/auth_gate_screen.dart';
import 'presentation/providers/language_provider.dart';
import 'data/repositories/inventory_repository.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // For web script injection

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found. Ensure it exists before running.");
  }

  // For Web: Dynamically load Google Maps script
  if (kIsWeb) {
    final String mapsApiKey = dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');
    if (mapsApiKey.isNotEmpty) {
      final script = html.ScriptElement()
        ..src = 'https://maps.googleapis.com/maps/api/js?key=$mapsApiKey'
        ..id = 'google-maps-script';
      html.document.head?.append(script);
    }
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  // Hive (local offline DB)
  await Hive.initFlutter();
  Hive.registerAdapter(RequestModelAdapter());

  // FCM Notifications
  await NotificationService.init();

  // SharedPreferences for language
  final prefs = await SharedPreferences.getInstance();

  // Seed Inventory (only for development/demo)
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
  );
  await container.read(inventoryRepoProvider).seedInitialData();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const ShayakApp(),
    ),
  );
}

class ShayakApp extends ConsumerWidget {
  const ShayakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);

    return MaterialApp(
      title: 'Shayak – Disaster Response',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('hi', ''), // Hindi
      ],
      home: const AuthGateScreen(),
    );
  }
}
