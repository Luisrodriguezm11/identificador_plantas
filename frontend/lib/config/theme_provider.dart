// frontend/lib/config/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// El ThemeProvider se encargará de notificar a la app cuando el tema cambie.
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Por defecto, iniciamos en modo oscuro.

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); // Cargamos la preferencia del usuario al iniciar.
  }

  // Carga la preferencia de tema guardada en el dispositivo.
  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Leemos el valor 'themeMode'. Si no existe, usamos 'dark' por defecto.
    String theme = prefs.getString('themeMode') ?? 'dark';
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners(); // Notificamos a los widgets que el tema ha sido cargado.
  }

  // Cambia el tema y guarda la nueva preferencia.
  void toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      prefs.setString('themeMode', 'dark');
    } else {
      _themeMode = ThemeMode.light;
      prefs.setString('themeMode', 'light');
    }
    notifyListeners(); // Notificamos a los widgets que deben redibujarse con el nuevo tema.
  }
}