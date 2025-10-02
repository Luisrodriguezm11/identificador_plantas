// frontend/lib/config/app_theme.dart

import 'package:flutter/material.dart';

// --- PALETA DE COLORES PARA TEMA OSCURO ---
class AppColorsDark {
  static const Color primary = Color(0xFF5E35B1); // Un morado elegante
  static const Color accent = Color(0xFF00E676); // Verde brillante para acentos
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color danger = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  static const Color success = Color(0xFF66BB6A);
}

// --- PALETA DE COLORES PARA TEMA CLARO ---
class AppColorsLight {
  static const Color primary = Color(0xFF673AB7); // Mantenemos el morado
  static const Color accent = Color(0xFF00C853); // Un verde un poco más oscuro
  static const Color background = Color(0xFFF5F5F5); // Un gris muy claro
  static const Color surface = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);
  static const Color success = Color(0xFF388E3C);
}

class AppTheme {

  // --- IMAGEN DE FONDO (COMÚN PARA AMBOS TEMAS) ---
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/background3.jpg"),
          fit: BoxFit.cover,
        ),
      );

  // --- TEMA CLARO ---
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColorsLight.primary,
      scaffoldBackgroundColor: AppColorsLight.background,
      colorScheme: const ColorScheme.light(
        primary: AppColorsLight.primary,
        secondary: AppColorsLight.accent,
        error: AppColorsLight.danger,
        surface: AppColorsLight.surface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColorsLight.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: AppColorsLight.textPrimary, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: AppColorsLight.textSecondary),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(AppColorsLight.primary),
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
    );
  }

  // --- TEMA OSCURO ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColorsDark.primary,
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        secondary: AppColorsDark.accent,
        error: AppColorsDark.danger,
        surface: AppColorsDark.surface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColorsDark.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: AppColorsDark.textPrimary, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: AppColorsDark.textSecondary),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(AppColorsDark.primary),
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
    );
  }
  
  // --- MÉTODOS REUTILIZABLES PARA ESTILOS ---
  
  static ElevatedButtonThemeData _elevatedButtonTheme(Color backgroundColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
  
  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      labelStyle: TextStyle(color: isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: isDark ? Colors.white54 : Colors.black54),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
      ),
      errorStyle: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger),
    );
  }

  // Estilos específicos que puedes seguir usando
  static ButtonStyle accentButtonStyle(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton.styleFrom(
      backgroundColor: isDark ? AppColorsDark.accent : AppColorsLight.accent,
    );
  }

  static ButtonStyle dangerButtonStyle(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton.styleFrom(
      backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
    );
  }
}