// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:frontend/config/theme_provider.dart';
import 'package:provider/provider.dart';
import 'screens/auth_check_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Envolvemos la app con el ChangeNotifierProvider para que el tema esté disponible en todos los widgets.
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos un Consumer para que MaterialApp se redibuje cuando cambie el tema.
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Identificador de Plagas',
          debugShowCheckedModeBanner: false, // Opcional: para quitar la cinta de "Debug"
          
          // Aquí está la magia:
          theme: AppTheme.lightTheme,       // Asignamos el tema claro
          darkTheme: AppTheme.darkTheme,    // Asignamos el tema oscuro
          themeMode: themeProvider.themeMode, // El provider decide cuál mostrar

          home: const AuthCheckScreen(),
        );
      },
    );
  }
}