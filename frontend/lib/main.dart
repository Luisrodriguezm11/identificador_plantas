// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'screens/auth_check_screen.dart';

void main() {
  // 👇 Añade esta línea
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
    // ... el resto de tu código no cambia
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identificador de Plagas',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthCheckScreen(),
    );
  }
}