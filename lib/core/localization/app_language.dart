enum AppLanguage {
  english,
  hindi,
}

extension AppLanguageExtension on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.hindi:
        return 'hi';
    }
  }

  String get localeCode => code;

  String get name {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'हिन्दी';
    }
  }

  String get englishName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'Hindi';
    }
  }

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'hi':
        return AppLanguage.hindi;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}