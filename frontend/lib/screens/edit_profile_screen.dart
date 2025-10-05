// frontend/lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../config/app_theme.dart';
import '../widgets/top_navigation_bar.dart';
import 'login_screen.dart';

import '../helpers/custom_route.dart';
import 'history_screen.dart';
import 'trash_screen.dart';
import 'dose_calculation_screen.dart';
import 'dashboard_screen.dart';


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

  late AuthService _authService;

  String _userEmail = '';
  String? _currentImageUrl;
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _newProfileImageFile;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
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

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const TrashScreen()));
        break;
      case 3:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const DoseCalculationScreen()));
        break;
    }
  }


  Future<void> _loadUserData() async {
    final result = await _authService.getUserProfile();
    if (mounted) {
      if (result['success']) {
        final userData = result['data'];
        setState(() {
          _nameController.text = userData['nombre_completo'] ?? '';
          _userEmail = userData['email'] ?? 'Correo no disponible';
          _currentImageUrl = userData['profile_image_url'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error al cargar datos: ${result['error']}');
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
      if (pickedFile != null) {
        setState(() {
          _newProfileImageFile = pickedFile;
        });
      }
    } catch (e) {
      _showErrorSnackBar('No se pudo seleccionar la imagen: $e');
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate() || _isSavingProfile) return;
    
    setState(() => _isSavingProfile = true);
    final storageService = StorageService();
    String? newImageUrl;

    try {
      if (_newProfileImageFile != null) {
        newImageUrl = await storageService.uploadProfileImage(_newProfileImageFile!);
      }
      final result = await _authService.updateProfile(
        nombreCompleto: _nameController.text,
        profileImageUrl: newImageUrl,
      );
      if (mounted) {
        if (result['success']) {
          _showSuccessSnackBar('Perfil actualizado con éxito');
          if (newImageUrl != null) {
            setState(() {
              _currentImageUrl = newImageUrl;
              _newProfileImageFile = null;
            });
          }
        } else {
          _showErrorSnackBar('Error al actualizar: ${result['error']}');
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate() || _isChangingPassword) return;

    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;

    if (currentPass.isEmpty || newPass.isEmpty) {
      _showErrorSnackBar('Por favor, completa los campos de contraseña.');
      return;
    }
    if (newPass.length < 6) {
      _showErrorSnackBar('La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final result = await _authService.changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
      );
      if (mounted) {
        if (result['success']) {
          _showSuccessSnackBar('Contraseña actualizada con éxito');
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          _showErrorSnackBar('Error: ${result['error']}');
        }
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Ocurrió un error al cambiar la contraseña: $e');
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _logout() async {
    await _authService.deleteToken();
    if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
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

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Editar Mi Perfil',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Actualiza tu información personal, tu foto de perfil o cambia tu contraseña.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildGlassCard({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              const Divider(height: 30, thickness: 1),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: TopNavigationBar(
        selectedIndex: -1,
        isAdmin: false,
        onItemSelected: _onNavItemTapped,
        onLogout: _logout,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(height: kToolbarHeight + 60), // Un poco más de espacio
                        _buildHeaderSection(),
                        _buildGlassCard(
                          title: 'Información del Perfil',
                          children: [
                            const SizedBox(height: 16),
                            Center(
                              child: GestureDetector(
                                onTap: _pickProfileImage,
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: isDark ? Colors.white24 : Colors.black12,
                                  backgroundImage: _getProfileImage(),
                                  child: _getProfileImage() == null
                                      ? Icon(Icons.camera_alt, size: 50, color: isDark ? Colors.white70 : Colors.black54)
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Center(child: Text('Toca la imagen para cambiarla')),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Nombre Completo'),
                              validator: (value) => value!.trim().isEmpty ? 'El nombre no puede estar vacío' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _userEmail,
                              decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                              enabled: false,
                            ),
                            const SizedBox(height: 32),
                            Center(
                              child: _isSavingProfile
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: _saveProfileChanges,
                                      child: const Text('Guardar Cambios'),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _buildGlassCard(
                          title: 'Cambiar Contraseña',
                          children: [
                            const SizedBox(height: 16),
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
                            Center(
                              child: _isChangingPassword
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      style: AppTheme.accentButtonStyle(context),
                                      onPressed: _changePassword,
                                      child: const Text('Actualizar Contraseña'),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // <-- CAMBIO: AQUÍ ESTÁ EL NUEVO BOTÓN DE REGRESO -->
          // Lo posicionamos de forma absoluta en la pantalla, como en history_screen.dart
          Positioned(
            top: kToolbarHeight + 10,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    tooltip: 'Regresar',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
                    // La acción es simple: pop() para cerrar esta pantalla.
                    onPressed: () => Navigator.of(context).pop(),
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