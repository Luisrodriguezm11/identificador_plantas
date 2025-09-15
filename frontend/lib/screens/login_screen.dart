// frontend/lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'register_screen.dart'; // Importa la pantalla de registro
import '../services/auth_service.dart'; // Importa el servicio

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
              SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: Colors.red),
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
          // Fondo con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade200, Colors.green.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Contenido centrado
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Título
                          Text(
                            "Iniciar Sesión",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
                          // Campo de Correo
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: "Correo Electrónico",
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty || !value.contains('@')) {
                                return 'Por favor, ingresa un email válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Campo de Contraseña
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: "Contraseña",
                              prefixIcon: Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, ingresa tu contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Botón de Ingresar
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    onPressed: _login,
                                    child: const Text("Ingresar"),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          // Botón para Registrarse
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text("¿No tienes cuenta? Regístrate"),
                          ),
                        ],
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