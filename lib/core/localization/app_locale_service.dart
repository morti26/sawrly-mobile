import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The two languages supported by the application.
enum AppLanguage { arabic, english }

/// Stores the selected language and notifies the app when it changes.
class AppLocaleService extends ChangeNotifier {
  static const _storageKey = 'app_language';
  static const _storage = FlutterSecureStorage();
  static AppLocaleService? _shared;

  Locale _locale = const Locale('ar');

  AppLocaleService() {
    _shared = this;
  }

  static AppLocaleService get instance => _shared ??= AppLocaleService();

  Locale get locale => _locale;
  AppLanguage get language => _locale.languageCode == 'en'
      ? AppLanguage.english
      : AppLanguage.arabic;
  bool get isEnglish => language == AppLanguage.english;
  TextDirection get textDirection => isEnglish
      ? TextDirection.ltr
      : TextDirection.rtl;

  Future<void> init() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'en') {
        _locale = const Locale('en');
      }
    } catch (_) {
      // Storage is best-effort (for example on an embedded web preview).
    }
  }

  Future<void> setLanguage(AppLanguage value) async {
    final next = value == AppLanguage.english
        ? const Locale('en')
        : const Locale('ar');
    if (_locale == next) return;
    _locale = next;
    try {
      await _storage.write(key: _storageKey, value: next.languageCode);
    } catch (_) {
      // The current process still switches language when persistent storage
      // is unavailable.
    }
    notifyListeners();
  }

  String translate(String arabic, String english) =>
      isEnglish ? english : arabic;
}

/// Small, context-free helper for places such as services and callbacks.
String tr(String arabic, String english) =>
    AppLocaleService.instance.translate(arabic, english);
