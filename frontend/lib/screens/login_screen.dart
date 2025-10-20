// frontend/lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'register_screen.dart';
import '../services/auth_service.dart';
import 'dart:ui';
import '../config/app_theme.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await _authService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success']) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        // Usamos los colores del tema para el SnackBar
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
          ),
        );
      }
    }
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    
    // <-- 1. Obtenemos el ancho de la pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    // <-- 2. Definimos un punto de quiebre (breakpoint) para cambiar el diseño
    final bool isWideScreen = screenWidth > 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                      ),
                      child: IntrinsicHeight(
                        // <-- 3. Usamos un operador ternario para elegir el layout
                        child: isWideScreen
                            ? Row(
                                children: [
                                  Expanded(flex: 3, child: _buildLoginForm(context)),
                                  Expanded(flex: 2, child: _buildImageSide(context)),
                                ],
                              )
                            : _buildLoginForm(context), // En pantallas pequeñas, solo mostramos el formulario
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

  // --- MÉTODOS AUXILIARES PARA MAYOR CLARIDAD ---

  // Widget para el formulario de Login
  Widget _buildLoginForm(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "INICIAR SESIÓN",
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
              decoration: const InputDecoration(labelText: "CORREO ELECTRÓNICO"),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty || !value.contains('@')) {
                  return 'Por favor, ingresa un email válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
              decoration: const InputDecoration(labelText: "CONTRASEÑA"),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa tu contraseña';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: AppTheme.accentButtonStyle(context),
                      onPressed: _login,
                      child: const Text("INGRESAR"),
                    ),
                  ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: Text(
                "¿No tienes una cuenta? Regístrate",
                style: TextStyle(color: isDark ? AppColorsDark.textSecondary : AppColorsLight.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para la imagen lateral
// Reemplaza la versión anterior de este método en ambos archivos.

Widget _buildImageSide(BuildContext context, {BoxFit fit = BoxFit.cover}) { // <-- 1. Añadimos el parámetro
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16.0),
        bottomRight: Radius.circular(16.0),
      ),
      image: DecorationImage(
        fit: fit, // <-- 2. Usamos el parámetro en lugar de un valor fijo
        image: const AssetImage('assets/login_image.jpg'),
      ),
    ),
  );
}
}