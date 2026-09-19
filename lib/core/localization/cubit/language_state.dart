import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';

class LanguageState extends Equatable {
  final AppLanguage language;

  const LanguageState(this.language);

  Locale get locale => language.locale;

  @override
  List<Object?> get props => [language];
}
