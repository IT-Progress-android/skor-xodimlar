import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_translations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// Non-widget layers (blocs, repositories, data sources, pure-Dart error
  /// formatters) have no BuildContext, so they can't call `context.tr()`.
  /// This static mirror is kept in sync by [LanguageCubit] on every language
  /// change (and on startup) so those layers can still translate via
  /// [AppLocalizations.trStatic].
  static AppLanguage _currentLanguage = AppLanguage.uzbek;

  static void setCurrentLanguage(AppLanguage language) {
    _currentLanguage = language;
  }

  static String trStatic(String key, [Map<String, String>? params]) {
    return AppLocalizations(_currentLanguage.locale).translate(key, params);
  }

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String translate(String key, [Map<String, String>? params]) {
    final langCode = locale.languageCode;
    final dict =
        AppTranslations.translations[langCode] ??
        AppTranslations.translations['uz'] ??
        {};

    String value = dict[key] ?? AppTranslations.translations['uz']?[key] ?? key;

    if (params != null && params.isNotEmpty) {
      params.forEach((paramKey, paramValue) {
        value = value.replaceAll('{$paramKey}', paramValue);
      });
    }

    return value;
  }

  AppLanguage get currentLanguage => AppLanguage.fromLocale(locale);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLanguage.values.any((lang) => lang.code == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizations(const Locale('uz'));

  String tr(String key, [Map<String, String>? params]) {
    return l10n.translate(key, params);
  }

  AppLanguage get currentAppLanguage => l10n.currentLanguage;
}
