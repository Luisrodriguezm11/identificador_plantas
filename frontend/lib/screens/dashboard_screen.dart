// frontend/lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'detection_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Función para manejar el cierre de sesión
  void _logout(BuildContext context) async {
    // Usamos el context para asegurar que es válido antes y después del async
    final navigator = Navigator.of(context);
    final authService = AuthService();

    await authService.deleteToken(); // Borra el token guardado

    // Navega a la pantalla de login y elimina todas las rutas anteriores del historial
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La AppBar es la barra superior de la aplicación
      appBar: AppBar(
        title: const Text("Plataforma de Detección"),
        backgroundColor: Colors.green[700], // Un color más oscuro para la barra
        actions: [
          // Este es el botón de cierre de sesión
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _logout(context), // Llama a la función de logout
          ),
        ],
      ),
      // El body es el contenido principal de la pantalla
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
            "¡Bienvenido!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Comienza un nuevo análisis para detectar plagas y enfermedades en tus cultivos de café.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("Analizar Nueva Hoja"),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DetectionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(fontSize: 18),
            ),
        ),
          ],
        ),
      ),
    );
  }
}