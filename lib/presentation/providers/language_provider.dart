import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Initialized in main.dart
});

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return LanguageNotifier(prefs);
});

class LanguageNotifier extends StateNotifier<Locale> {
  final SharedPreferences _prefs;
  static const _langKey = 'selected_language';

  LanguageNotifier(this._prefs) : super(const Locale('en')) {
    _loadLanguage();
  }

  void _loadLanguage() {
    final code = _prefs.getString(_langKey);
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(_langKey, languageCode);
    state = Locale(languageCode);
  }

  Future<void> toggleLanguage() async {
    final newCode = state.languageCode == 'en' ? 'hi' : 'en';
    await setLanguage(newCode);
  }
}
