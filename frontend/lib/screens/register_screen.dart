// frontend/lib/screens/register_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import '../services/auth_service.dart';
import 'dart:ui';
import '../config/app_theme.dart';

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
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImageFile; // Para guardar la imagen seleccionada

  bool _isLoading = false;

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = pickedFile;
      });
    }
  }

  Future<void> _register() async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String? imageUrl;
      // Subir la imagen 
      if (_profileImageFile != null) {
        final storageService = StorageService();
        imageUrl = await storageService.uploadProfileImage(_profileImageFile!);
      }
      final result = await _authService.register(
        _nombreController.text,
        _emailController.text,
        _passwordController.text,
        _ongController.text.isNotEmpty ? _ongController.text : "De la Gente",
        profileImageUrl: imageUrl, 
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

    final screenWidth = MediaQuery.of(context).size.width;
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
                        child: isWideScreen
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 3, child: _buildRegisterForm(context)),
                                  Expanded(flex: 2, child: _buildScalableImageSide(context)),
                                ],
                              )
                            : _buildRegisterForm(context),
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

  Widget _buildRegisterForm(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("REGISTRO", style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                backgroundImage: _profileImageFile != null
                    ? (kIsWeb
                        ? NetworkImage(_profileImageFile!.path)
                        : FileImage(File(_profileImageFile!.path))) as ImageProvider
                    : null,
                child: _profileImageFile == null
                    ? Icon(Icons.camera_alt, color: isDark ? Colors.white70 : Colors.black54, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text('Añadir foto de perfil', style: theme.textTheme.bodyMedium),
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'El correo es requerido';
                String pattern = r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
                RegExp regex = RegExp(pattern);
                if (!regex.hasMatch(value)) return 'Introduce un correo electrónico válido';
                return null;
              },
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
    );
  }


Widget _buildScalableImageSide(BuildContext context) {
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      color: Colors.white, // Mantenemos el fondo blanco sólido
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(16.0),
        bottomRight: Radius.circular(16.0),
      ),
    ),
    child: Image.asset(
      'assets/login_image.jpg', 
      fit: BoxFit.contain,
    ),
  );
}
}