// frontend/lib/widgets/main_layout.dart

import 'package:flutter/material.dart';
import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:frontend/screens/auth_check_screen.dart'; // Asegúrate que la ruta sea correcta

class MainLayout extends StatelessWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos un Stack para poner el fondo detrás de todo
      body: Stack(
        children: [
          // 1. El fondo animado que SIEMPRE estará visible
          const AnimatedBubbleBackground(),

          // 2. Un Navigator que se encargará de mostrar las pantallas
          // encima del fondo.
          Navigator(
            // La pantalla inicial de tu app
            initialRoute: '/',
            // Esta función se encarga de construir las rutas (pantallas)
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(builder: (_) => const AuthCheckScreen());
                // Aquí podrías añadir más rutas si las necesitaras en este Navigator,
                // pero por ahora, el principal de MaterialApp las manejará.
                default:
                  return MaterialPageRoute(builder: (_) => const AuthCheckScreen()); // Una pantalla por defecto
              }
            },
          ),
        ],
      ),
    );
  }
}