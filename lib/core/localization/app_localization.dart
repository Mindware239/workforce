import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:workforce/core/localization/app_language.dart';
import 'package:workforce/features/language/providers/language_provider.dart';

final appLocalizationProvider = Provider<AppLocalization>((ref) {
  final language = ref.watch(languageProvider);

  return AppLocalization(language);
});

class AppLocalization {
  final AppLanguage language;

  const AppLocalization(this.language);

  static const String _assetPath =
      'assets/localization/localization.json';

  static Map<String, dynamic> _translations = {};

  static bool _isLoaded = false;

  static Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    final jsonString = await rootBundle.loadString(_assetPath);

    final decoded = jsonDecode(jsonString);

    if (decoded is Map) {
      _translations = Map<String, dynamic>.from(decoded);
    }

    _isLoaded = true;
  }

  String translate(String key) {
    final languageData = _translations[language.code];

    if (languageData is Map) {
      final value = languageData[key];

      if (value != null) {
        return value.toString();
      }
    }

    // Fallback to English
    final englishData = _translations['en'];

    if (englishData is Map) {
      final fallback = englishData[key];

      if (fallback != null) {
        return fallback.toString();
      }
    }

    // If key doesn't exist, return key itself.
    return key;
  }

  String tr(String key) {
    return translate(key);
  }

  String get languageCode {
    return language.code;
  }

  String get languageName {
    return language.name;
  }
}

extension LocalizationRefExtension on WidgetRef {
  String tr(String key) {
    return watch(appLocalizationProvider).tr(key);
  }
}

extension LocalizationRefExtensionOnRef on Ref {
  String tr(String key) {
    return watch(appLocalizationProvider).tr(key);
  }
}