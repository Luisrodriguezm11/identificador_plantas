// frontend/lib/screens/auth_check_screen.dart

import 'package:flutter/material.dart';
//import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS EL TEMA
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:lottie/lottie.dart'; // <-- 2. IMPORTAMOS LOTTIE PARA ANIMACIONES
import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

void _checkLoginStatus() async {
  await Future.delayed(const Duration(seconds: 2));

  final token = await _authService.readToken();
  if (mounted) {
    if (token != null) {
      // Navega a la ruta '/dashboard' DENTRO del navegador de MainLayout
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      // Navega a la pantalla de Login (esta reemplaza toda la app, lo cual es correcto aquí)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          
          //Container(
            //decoration: AppTheme.backgroundDecoration,
          //),
          //const AnimatedBubbleBackground(),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 4. USAMOS UNA ANIMACIÓN DE LOTTIE
                Lottie.asset(
                  'assets/animations/focus_animation.json', // Puedes cambiar esta por otra animación si quieres
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cargando tu espacio de trabajo...',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}