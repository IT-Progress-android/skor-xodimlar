import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's appearance choice (system / light / dark) and persists it.
class ThemeCubit extends Cubit<ThemeMode> {
  final SharedPreferences _prefs;
  static const String prefKey = 'selected_theme_mode';

  ThemeCubit(this._prefs) : super(_load(_prefs));

  static ThemeMode _load(SharedPreferences prefs) {
    final saved = prefs.getString(prefKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> changeTheme(ThemeMode mode) async {
    if (state == mode) return;
    emit(mode);
    await _prefs.setString(prefKey, mode.name);
  }
}
