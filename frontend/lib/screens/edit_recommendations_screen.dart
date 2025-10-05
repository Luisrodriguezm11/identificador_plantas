// frontend/lib/screens/edit_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'dart:ui';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

class EditRecommendationsScreen extends StatefulWidget {
  final Map<String, dynamic> disease;

  const EditRecommendationsScreen({super.key, required this.disease});

  @override
  State<EditRecommendationsScreen> createState() =>
      _EditRecommendationsScreenState();
}

class _EditRecommendationsScreenState extends State<EditRecommendationsScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic> _treatments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTreatments();
  }

  Future<void> _fetchTreatments() async {
    setState(() => _isLoading = true);
    try {
      final details = await _detectionService
          .getDiseaseDetails(widget.disease['roboflow_class']);
      if (mounted) {
        setState(() {
          _treatments = details['recommendations'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error al cargar tratamientos: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const TrashScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const DoseCalculationScreen()));
        break;
      case 4:
        Navigator.of(context).pop();
        break;
    }
  }

  Future<void> _showEditDialog({Map<String, dynamic>? treatment}) async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    final bool isEditing = treatment != null;

    final nameController = TextEditingController(text: isEditing ? treatment['nombre_comercial'] : '');
    final ingredientController = TextEditingController(text: isEditing ? treatment['ingrediente_activo'] : '');
    final typeController = TextEditingController(text: isEditing ? treatment['tipo_tratamiento'] : '');
    final doseController = TextEditingController(text: isEditing ? treatment['dosis'] : '');
    final frequencyController = TextEditingController(text: isEditing ? treatment['frecuencia_aplicacion'] : '');
    final notesController = TextEditingController(text: isEditing ? treatment['notas_adicionales'] : '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          // 4. ESTILOS DEL DIÁLOGO ADAPTADOS AL TEMA
          backgroundColor: isDark ? Colors.grey[900]?.withOpacity(0.9) : AppColorsLight.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Editar Tratamiento' : 'Añadir Tratamiento'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextFormField(controller: nameController, label: 'Nombre Comercial'),
                  _buildTextFormField(controller: ingredientController, label: 'Ingrediente Activo'),
                  _buildTextFormField(controller: typeController, label: 'Tipo (Sistémico, De Contacto...)'),
                  _buildTextFormField(controller: doseController, label: 'Dosis del Producto (ej: 10ml/L)', isOptional: true),
                  _buildTextFormField(controller: frequencyController, label: 'Frecuencia de Aplicación', isOptional: true),
                  _buildTextFormField(controller: notesController, label: 'Notas Adicionales', isOptional: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final treatmentData = {
                    'id_enfermedad': widget.disease['id_enfermedad'],
                    'nombre_comercial': nameController.text,
                    'ingrediente_activo': ingredientController.text,
                    'tipo_tratamiento': typeController.text,
                    'dosis': doseController.text,
                    'frecuencia_aplicacion': frequencyController.text,
                    'notas_adicionales': notesController.text,
                  };
                  try {
                    if (isEditing) {
                      await _detectionService.updateTreatment(treatment['id_tratamiento'], treatmentData);
                    } else {
                      await _detectionService.addTreatment(treatmentData);
                    }
                    if (mounted) Navigator.of(context).pop(true);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                      ));
                    }
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _fetchTreatments();
    }
  }

  Future<void> _deleteTreatment(int treatmentId) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirmar Eliminación'),
              content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Eliminar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger))),
              ],
            ));

    if (confirmed == true) {
      try {
        await _detectionService.deleteTreatment(treatmentId);
        _fetchTreatments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
          ));
        }
      }
    }
  }

@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final bool isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    backgroundColor: Colors.transparent,
    appBar: TopNavigationBar(
      selectedIndex: 4,
      isAdmin: true,
      onItemSelected: _onNavItemTapped,
      onLogout: () => _logout(context),
    ),
    extendBodyBehindAppBar: true,
    // --- El FloatingActionButton ha sido eliminado de aquí ---
    body: Stack(
      children: [
 
        //Container(
          //decoration: AppTheme.backgroundDecoration,
        //),
        //const AnimatedBubbleBackground(),


        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    SizedBox(height: kToolbarHeight + 60),
                    _buildHeaderSection(),
                    const SizedBox(height: 60),
                    _buildTreatmentsList(),
                    // Añadimos un espacio extra al final para que el botón no tape el último elemento
                    const SizedBox(height: 100), 
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. BOTÓN DE REGRESO
        Positioned(
          top: kToolbarHeight + 10,
          left: 20,
          child: ClipRRect(
            // ... (el código del botón de regreso se mantiene igual)
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
                  tooltip: 'Volver a Gestionar Tratamientos',
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),

        // --- 👇 ¡AQUÍ ESTÁ EL NUEVO BOTÓN PERSONALIZADO! 👇 ---
        Positioned(
          bottom: 32,
          right: 32,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showEditDialog(),
                  borderRadius: BorderRadius.circular(28.0),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(isDark ? 0.3 : 0.4),
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
                        const SizedBox(width: 12),
                        Text(
                          "Añadir Tratamiento",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ],
    ),
  );
}

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 3. TEXTOS ADAPTADOS AL TEMA
        Text(
          widget.disease['nombre_comun'],
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Añade, edita o elimina las recomendaciones de tratamientos para esta condición.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentsList() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger)))
            : _treatments.isEmpty
                ? Center(child: Text("No hay tratamientos para esta enfermedad.", style: theme.textTheme.bodyMedium))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _treatments.length,
                    itemBuilder: (context, index) {
                      final treatment = _treatments[index];
                      return _buildTreatmentCard(treatment);
                    },
                  );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          treatment['nombre_comercial'] ?? 'Sin Nombre',
                          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
                        ),
                      ),
                      Row(
                        children: [
                          _buildGlassIconButton(
                            icon: Icons.edit_outlined,
                            color: isDark ? AppColorsDark.info : AppColorsLight.info,
                            onPressed: () => _showEditDialog(treatment: treatment),
                            tooltip: 'Editar Tratamiento',
                          ),
                          const SizedBox(width: 12),
                          _buildGlassIconButton(
                            icon: Icons.delete_forever_outlined,
                            color: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                            onPressed: () => _deleteTreatment(treatment['id_tratamiento']),
                            tooltip: 'Eliminar Tratamiento',
                          ),
                        ],
                      )
                    ],
                  ),
                  Divider(color: isDark ? Colors.white30 : Colors.black26, height: 30, thickness: 1),
                  _buildInfoRow('Ingrediente Activo:', treatment['ingrediente_activo']),
                  _buildInfoRow('Tipo de Tratamiento:', treatment['tipo_tratamiento']),
                  _buildInfoRow('Dosis:', treatment['dosis']),
                  _buildInfoRow('Frecuencia:', treatment['frecuencia_aplicacion']),
                  _buildInfoRow('Notas Adicionales:', treatment['notas_adicionales']),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: Icon(icon, color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, bool isOptional = false}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.primary)),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Este campo es requerido';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}