// frontend/lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'register_screen.dart'; // Importa la pantalla de registro
import '../services/auth_service.dart'; // Importa el servicio
import 'dart:ui'; // Necesario para el BackdropFilter

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService(); // Instancia del servicio

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${result['error']}'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Imagen de fondo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    "assets/background.jpg"), // Asegúrate de tener esta imagen
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Contenido centrado
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: 700),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // --- COLUMNA IZQUIERDA: FORMULARIO (Más ancha) ---
                            Expanded(
                              flex: 3, // <-- AQUÍ ESTÁ EL CAMBIO
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "INICIAR SESIÓN",
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 32),
                                      TextFormField(
                                        controller: _emailController,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: "CORREO ELECTRÓNICO",
                                          labelStyle: TextStyle(
                                              color: Colors.white70),
                                          enabledBorder:
                                              UnderlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white54),
                                          ),
                                          focusedBorder:
                                              UnderlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white),
                                          ),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null ||
                                              value.isEmpty ||
                                              !value.contains('@')) {
                                            return 'Por favor, ingresa un email válido';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: const InputDecoration(
                                          labelText: "CONTRASEÑA",
                                          labelStyle: TextStyle(
                                              color: Colors.white70),
                                          enabledBorder:
                                              UnderlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white54),
                                          ),
                                          focusedBorder:
                                              UnderlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.white),
                                          ),
                                        ),
                                        obscureText: true,
                                        validator: (value) {
                                          if (value == null ||
                                              value.isEmpty) {
                                            return 'Por favor, ingresa tu contraseña';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 32),
                                      _isLoading
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.white,
                                                  foregroundColor: Colors
                                                      .blue.shade700,
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      vertical: 16.0),
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30.0),
                                                  ),
                                                ),
                                                onPressed: _login,
                                                child: const Text(
                                                  "INGRESAR",
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                      const SizedBox(height: 24),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const RegisterScreen()),
                                          );
                                        },
                                        child: const Text(
                                          "¿No tienes una cuenta? Regístrate",
                                          style: TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // --- COLUMNA DERECHA: IMAGEN (Más estrecha) ---
                            Expanded(
                              flex: 2, // <-- AQUÍ ESTÁ EL CAMBIO
                              child: Container(
                                padding: const EdgeInsets.all(0.0),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(16.0),
                                    bottomRight: Radius.circular(16.0),
                                  ),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/login_image.jpg',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}