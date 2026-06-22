import 'package:flutter/material.dart';
import '../theme/app_themes.dart';
import '../services/app_storage.dart';

class ThemeProvider with ChangeNotifier {
  ThemeType _currentTheme = ThemeType.orangeRust;
  final AppStorage _storage = AppStorage();

  ThemeType get currentTheme => _currentTheme;
  ThemeData get currentThemeData => AppThemes.getTheme(_currentTheme);

  Future<void> loadTheme() async {
    final settings = await _storage.readSettings();
    final themeString = settings['appTheme'] as String?;
    if (themeString != null) {
      _currentTheme = ThemeType.values.firstWhere(
        (e) => e.name == themeString,
        orElse: () => ThemeType.orangeRust,
      );
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeType theme) async {
    _currentTheme = theme;
    final settings = await _storage.readSettings();
    settings['appTheme'] = theme.name;
    await _storage.writeSettings(settings);
    notifyListeners();
  }

  String getThemeName() {
    return _currentTheme.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ');
  }
}