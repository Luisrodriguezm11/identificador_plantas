// frontend/lib/screens/register_screen.dart

import 'package:flutter/material.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import '../services/auth_service.dart';
import 'dart:ui';
import '../config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ongController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await _authService.register(
        _nombreController.text,
        _emailController.text,
        _passwordController.text,
        _ongController.text.isNotEmpty ? _ongController.text : "De la Gente",
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('¡Registro exitoso! Ahora puedes iniciar sesión.'),
              backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${result['error']}'),
              backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          
          //Container(
            //decoration: AppTheme.backgroundDecoration,
          //),
          //const AnimatedBubbleBackground(),
          
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
                      // 3. TARJETA ADAPTATIVA
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 4. TEXTOS Y CAMPOS USAN EL TEMA
                                      Text(
                                        "REGISTRO",
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 24),
                                      TextFormField(
                                        controller: _nombreController,
                                        style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
                                        decoration: const InputDecoration(labelText: "NOMBRE COMPLETO"),
                                        validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _emailController,
                                        style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
                                        decoration: const InputDecoration(labelText: "CORREO ELECTRÓNICO"),
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) => value!.isEmpty || !value.contains('@') ? 'Email inválido' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
                                        decoration: const InputDecoration(labelText: "CONTRASEÑA"),
                                        obscureText: true,
                                        validator: (value) => value!.length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _ongController,
                                        style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
                                        decoration: const InputDecoration(labelText: "ONG (OPCIONAL)"),
                                      ),
                                      const SizedBox(height: 32),
                                      _isLoading
                                          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                                          : SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                // 5. BOTÓN DE ACENTO
                                                style: AppTheme.accentButtonStyle(context),
                                                onPressed: _register,
                                                child: const Text("REGISTRARSE"),
                                              ),
                                            ),
                                      const SizedBox(height: 24),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          "Volver al inicio de sesión",
                                          style: TextStyle(color: isDark ? AppColorsDark.textSecondary : AppColorsLight.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                                  borderRadius: const BorderRadius.only(
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