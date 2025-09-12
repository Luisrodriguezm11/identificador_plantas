// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'screens/auth_check_screen.dart';
import 'package:firebase_core/firebase_core.dart'; // <-- Importa Firebase Core
import 'firebase_options.dart'; // <-- Importa el archivo generado

void main() async { // <-- Convierte main en async
  WidgetsFlutterBinding.ensureInitialized();
  // 👇 Añade esta línea para inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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