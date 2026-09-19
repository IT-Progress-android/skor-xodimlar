import 'package:flutter/material.dart';

enum AppLanguage {
  uzbek('uz', 'O\'zbekcha', 'O‘zbek tili', '🇺🇿'),
  russian('ru', 'Русский', 'Русский язык', '🇷🇺'),
  english('en', 'English', 'English', '🇬🇧'),
  kyrgyz('ky', 'Кыргызча', 'Кыргыз тили', '🇰🇬');

  final String code;
  final String title;
  final String nativeTitle;
  final String flag;

  const AppLanguage(this.code, this.title, this.nativeTitle, this.flag);

  Locale get locale => Locale(code);

  static List<Locale> get supportedLocales =>
      AppLanguage.values.map((lang) => lang.locale).toList();

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.uzbek;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code.toLowerCase().trim(),
      orElse: () => AppLanguage.uzbek,
    );
  }

  static AppLanguage fromLocale(Locale locale) {
    return fromCode(locale.languageCode);
  }
}
