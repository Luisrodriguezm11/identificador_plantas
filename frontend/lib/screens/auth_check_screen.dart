// frontend/lib/screens/auth_check_screen.dart

import 'package:flutter/material.dart';
//import 'package:frontend/config/app_theme.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:lottie/lottie.dart'; // 
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
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
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
                Lottie.asset(
                  'assets/animations/focus_animation.json', //animacion de carga de pagina
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