// frontend/lib/config/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; 

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme(); 
  }


  _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String theme = prefs.getString('themeMode') ?? 'dark';
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners(); 
  }

  
  void toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      prefs.setString('themeMode', 'dark');
    } else {
      _themeMode = ThemeMode.light;
      prefs.setString('themeMode', 'light');
    }
    notifyListeners(); 
  }
}