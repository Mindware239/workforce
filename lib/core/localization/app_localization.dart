import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/localization/app_language.dart';
import 'package:workforce/core/localization/app_translations.dart';
import 'package:workforce/features/language/providers/language_provider.dart';

final appLocalizationProvider = Provider<AppLocalization>((ref) {
  final language = ref.watch(languageProvider);

  return AppLocalization(language);
});

class AppLocalization {
  final AppLanguage language;

  const AppLocalization(this.language);

  String translate(String key) {
    return AppTranslations.translate(
      key,
      language: language,
    );
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