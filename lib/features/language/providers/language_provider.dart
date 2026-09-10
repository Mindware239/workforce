import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workforce/core/localization/app_language.dart';


final languageProvider =
    NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

class LanguageNotifier extends Notifier<AppLanguage> {
  static const String _languageKey = 'app_language';

  @override
  AppLanguage build() {
    _loadLanguage();
    return AppLanguage.english;
  }

  Future<void> _loadLanguage() async {
    final preferences = await SharedPreferences.getInstance();

    final savedLanguage = preferences.getString(_languageKey);

    if (savedLanguage == null || savedLanguage.isEmpty) {
      return;
    }

    final language = AppLanguageExtension.fromCode(savedLanguage);

    if (language != state) {
      state = language;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) {
      return;
    }

    state = language;

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _languageKey,
      language.code,
    );
  }

  Future<void> resetLanguage() async {
    state = AppLanguage.english;

    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_languageKey);
  }
}