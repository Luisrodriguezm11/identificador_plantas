// frontend/lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../config/app_theme.dart'; // Para los colores de los SnackBar

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _userEmail = ''; // Para mostrar el email (no editable)
  String? _currentImageUrl;
  bool _isLoading = true;
  
  final ImagePicker _picker = ImagePicker();
  XFile? _newProfileImageFile;

  @override
  void initState() {
    super.initState();
    // Aquí llamaremos a la función para cargar los datos del usuario
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE LA PANTALLA (la implementaremos en la siguiente etapa) ---
// frontend/lib/screens/edit_profile_screen.dart

Future<void> _loadUserData() async {
  // --- PUNTO DE CONTROL 1 ---
  print('[DEBUG] 1. Iniciando _loadUserData...'); 
  
  final authService = Provider.of<AuthService>(context, listen: false);
  final result = await authService.getUserProfile();

  // --- PUNTO DE CONTROL 4 ---
  print('[DEBUG] 4. Resultado recibido del servicio: $result');

  if (result['success']) {
    final userData = result['data'];
    print('[DEBUG] 5. Éxito. Procesando datos: $userData'); 

    setState(() {
      _nameController.text = userData['nombre_completo'] ?? '';
      _userEmail = userData['email'] ?? 'Correo no disponible';
      _currentImageUrl = userData['profile_image_url'];
      _isLoading = false;
    });
  } else {
    // --- PUNTO DE CONTROL DE ERROR ---
    print('[DEBUG] 6. Error recibido del servicio: ${result['error']}');
    setState(() => _isLoading = false);
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: ${result['error']}'))
      );
    }
  }
}

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfileImageFile = pickedFile;
      });
    }
  }

Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final storageService = StorageService();
    String? newImageUrl;

    // 1. Subir nueva imagen si existe
    if (_newProfileImageFile != null) {
      newImageUrl = await storageService.uploadProfileImage(_newProfileImageFile!);
      if (newImageUrl == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la imagen')));
        }
        setState(() => _isLoading = false);
        return;
      }
    }
    
    // 2. Actualizar perfil
    final result = await authService.updateProfile(
      nombreCompleto: _nameController.text,
      profileImageUrl: newImageUrl, // Será null si no se cambió la imagen
    );

    setState(() => _isLoading = false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Perfil actualizado con éxito'), backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success)
        );
        // Actualizar la imagen en la UI si se cambió
        if (newImageUrl != null) {
          setState(() {
            _currentImageUrl = newImageUrl;
            _newProfileImageFile = null;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger)
        );
      }
    }
  }


Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;

    if (currentPass.isEmpty || newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, rellena todos los campos de contraseña'))
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
    );

    setState(() => _isLoading = false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (result['success']) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Contraseña actualizada con éxito'), backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success)
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}'), backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger)
        );
      }
    }
  }


  // --- INTERFAZ DE USUARIO ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Sección de Foto de Perfil
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: isDark ? Colors.white24 : Colors.black12,
                        backgroundImage: _getProfileImage(),
                        child: _newProfileImageFile == null && _currentImageUrl == null
                            ? Icon(Icons.camera_alt, size: 50, color: isDark ? Colors.white70 : Colors.black54)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Toca la imagen para cambiarla'),
                    const SizedBox(height: 32),
                    
                    // Sección de Datos Personales
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre Completo'),
                      validator: (value) => value!.isEmpty ? 'El nombre no puede estar vacío' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _userEmail,
                      decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                      enabled: false, // El email no se puede editar
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveProfileChanges,
                      child: const Text('Guardar Cambios'),
                    ),
                    const Divider(height: 60),

                    // Sección de Cambio de Contraseña
                    Text('Cambiar Contraseña', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: const InputDecoration(labelText: 'Contraseña Actual'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(labelText: 'Nueva Contraseña'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirmar Nueva Contraseña'),
                      obscureText: true,
                      validator: (value) {
                        if (_newPasswordController.text.isNotEmpty && value != _newPasswordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                      onPressed: _changePassword,
                      child: const Text('Actualizar Contraseña'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_newProfileImageFile != null) {
      return kIsWeb ? NetworkImage(_newProfileImageFile!.path) : FileImage(File(_newProfileImageFile!.path));
    }
    if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return NetworkImage(_currentImageUrl!);
    }
    return null;
  }
}