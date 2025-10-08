import 'package:flutter/material.dart';

/// Service locator simple para acceder a las funciones de cambio de tema e idioma
class AppService {
  static late void Function(ThemeMode) changeTheme;
  static late void Function(Locale) changeLocale;
  
  /// Inicializa las referencias a las funciones de cambio
  static void initialize({
    required void Function(ThemeMode) onChangeTheme,
    required void Function(Locale) onChangeLocale,
  }) {
    changeTheme = onChangeTheme;
    changeLocale = onChangeLocale;
  }
}