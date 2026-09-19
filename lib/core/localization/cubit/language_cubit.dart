import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skore_hodimlar/core/localization/app_language.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/localization/cubit/language_state.dart';

class LanguageCubit extends Cubit<LanguageState> {
  final SharedPreferences _prefs;
  static const String prefKey = 'selected_app_language';

  LanguageCubit(this._prefs) : super(_loadInitialState(_prefs)) {
    AppLocalizations.setCurrentLanguage(state.language);
  }

  static LanguageState _loadInitialState(SharedPreferences prefs) {
    final savedCode = prefs.getString(prefKey);
    final language = AppLanguage.fromCode(savedCode);
    return LanguageState(language);
  }

  Future<void> changeLanguage(AppLanguage language) async {
    if (state.language == language) return;
    emit(LanguageState(language));
    AppLocalizations.setCurrentLanguage(language);
    await _prefs.setString(prefKey, language.code);
  }
}
