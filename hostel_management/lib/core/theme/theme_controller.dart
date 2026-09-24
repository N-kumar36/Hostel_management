import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _themeKey = 'hostel_mess_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;

      case AppThemeMode.dark:
        return ThemeMode.dark;

      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get modeName {
    switch (_mode) {
      case AppThemeMode.light:
        return 'Light';

      case AppThemeMode.dark:
        return 'Dark';

      case AppThemeMode.system:
        return 'System Default';
    }
  }

  IconData get modeIcon {
    switch (_mode) {
      case AppThemeMode.light:
        return Icons.light_mode_rounded;

      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;

      case AppThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMode = prefs.getString(_themeKey);

    switch (savedMode) {
      case 'light':
        _mode = AppThemeMode.light;
        break;

      case 'dark':
        _mode = AppThemeMode.dark;
        break;

      case 'system':
      default:
        _mode = AppThemeMode.system;
        break;
    }

    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _mode = mode;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> toggleDarkMode(bool enabled) async {
    await setTheme(enabled ? AppThemeMode.dark : AppThemeMode.light);
  }
}
