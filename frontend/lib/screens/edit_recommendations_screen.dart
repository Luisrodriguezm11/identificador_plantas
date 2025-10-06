// frontend/lib/screens/edit_recommendations_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'package:frontend/services/storage_service.dart';
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
import 'package:frontend/config/app_theme.dart';
import 'package:image_picker/image_picker.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

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

  // --- Los controladores se mantienen igual ---
  final nameController = TextEditingController(text: isEditing ? treatment['nombre_comercial'] : '');
  final ingredientController = TextEditingController(text: isEditing ? treatment['ingrediente_activo'] : '');
  final typeController = TextEditingController(text: isEditing ? treatment['tipo_tratamiento'] : '');
  final doseController = TextEditingController(text: isEditing ? treatment['dosis'] : '');
  final frequencyController = TextEditingController(text: isEditing ? treatment['frecuencia_aplicacion'] : '');
  final notesController = TextEditingController(text: isEditing ? treatment['notas_adicionales'] : '');

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      // --- V ENVOLVEMOS CON BACKDROPFILTER PARA EL EFECTO BLUR V ---
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          // --- V NUEVOS ESTILOS PARA EL DIÁLOGO V ---
          backgroundColor: isDark ? const Color(0xFF1E1E1E).withOpacity(0.85) : AppColorsLight.surface.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          title: Text(isEditing ? 'Editar Tratamiento' : 'Añadir Tratamiento', textAlign: TextAlign.center),
          titleTextStyle: theme.textTheme.headlineSmall,
          content: Container(
            // --- V LIMITAMOS EL ANCHO DEL DIÁLOGO V ---
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- V USAMOS NUESTRO MÉTODO REUTILIZABLE _buildStyledTextFormField V ---
                    _buildStyledTextFormField(controller: nameController, label: 'Nombre Comercial'),
                    _buildStyledTextFormField(controller: ingredientController, label: 'Ingrediente Activo'),
                    _buildStyledTextFormField(controller: typeController, label: 'Tipo (Sistémico, De Contacto...)'),
                    _buildStyledTextFormField(controller: doseController, label: 'Dosis del Producto (ej: 10ml/L)'),
                    _buildStyledTextFormField(controller: frequencyController, label: 'Frecuencia de Aplicación'),
                    _buildStyledTextFormField(controller: notesController, label: 'Notas Adicionales', maxLines: 3),
                  ],
                ),
              ),
            ),
          ),
          // --- V BOTONES REDISEÑADOS IGUAL QUE EN EL OTRO DIÁLOGO V ---
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                side: BorderSide(color: (isDark ? AppColorsDark.danger : AppColorsLight.danger).withOpacity(0.7)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // ... La lógica de guardado no cambia ...
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
        ),
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
  return Row( // <-- CAMBIAMOS COLUMN POR ROW
    mainAxisAlignment: MainAxisAlignment.center, // Centramos horizontalmente
    crossAxisAlignment: CrossAxisAlignment.center, // Centramos verticalmente
    children: [
      // Usamos Expanded para que el texto ocupe el espacio disponible y no se desborde
      Expanded(
        child: Column(
          children: [
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
        ),
      ),
      const SizedBox(width: 24), // Espacio entre el texto y el botón
      // --- V NUEVO BOTÓN PARA ABRIR EL DIÁLOGO V ---
      Tooltip(
        message: 'Editar Detalles de la Enfermedad',
        child: IconButton(
          icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary, size: 32),
          onPressed: () {
            // ¡Llamamos al método que movimos!
            _showEditDiseaseDialog(widget.disease);
          },
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

Future<void> _showEditDiseaseDialog(Map<String, dynamic> disease) async {
  final theme = Theme.of(context);
  final bool isDark = theme.brightness == Brightness.dark;
  final formKey = GlobalKey<FormState>();
  final storageService = StorageService();
  final imagePicker = ImagePicker();

  XFile? newImageFile;
  final imageStateNotifier = ValueNotifier<int>(0);

  Map<String, dynamic> fullDiseaseDetails;
  try {
    final details = await _detectionService.getDiseaseDetails(widget.disease['roboflow_class']);
    fullDiseaseDetails = details['info'] ?? {};
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al cargar detalles: $e'),
        backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
      ));
    }
    return;
  }

  final tipoController = TextEditingController(text: fullDiseaseDetails['tipo'] ?? '');
  final prevencionController = TextEditingController(text: fullDiseaseDetails['prevencion'] ?? '');
  final riesgoController = TextEditingController(text: fullDiseaseDetails['riesgo'] ?? '');
  
  var currentImageUrl = fullDiseaseDetails['imagen_url'] ?? '';
  String? imageUrlToDelete;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      // Para que el fondo se vea borroso, envolvemos el diálogo
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E).withOpacity(0.85) : AppColorsLight.surface.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Bordes más redondeados
            side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          title: Text('Editar Detalles de "${widget.disease['nombre_comun']}"', textAlign: TextAlign.center),
          titleTextStyle: theme.textTheme.headlineSmall,
          content: Container(
            // --- ¡AQUÍ LIMITAMOS EL ANCHO! ---
            width: 500, 
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ... (La lógica del selector de imagen se mantiene igual)
                    ValueListenableBuilder<int>(
                      valueListenable: imageStateNotifier,
                      builder: (context, _, __) {
                        ImageProvider? imageProvider;
                        if (newImageFile != null) {
                          imageProvider = kIsWeb ? NetworkImage(newImageFile!.path) : FileImage(File(newImageFile!.path));
                        } else if (currentImageUrl.isNotEmpty) {
                          imageProvider = NetworkImage(currentImageUrl);
                        }

                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
                                if (pickedFile != null) {
                                  if (currentImageUrl.isNotEmpty) {
                                    imageUrlToDelete = currentImageUrl;
                                  }
                                  newImageFile = pickedFile;
                                  currentImageUrl = '';
                                  imageStateNotifier.value++;
                                }
                              },
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                                  image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
                                ),
                                child: imageProvider == null
                                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo_outlined, size: 40, color: theme.iconTheme.color?.withOpacity(0.6)), const SizedBox(height: 8), Text("Toca para añadir una imagen")]))
                                    : null,
                              ),
                            ),
                            if (imageProvider != null)
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.close, color: Colors.white, size: 14),
                                    onPressed: () {
                                      if (currentImageUrl.isNotEmpty) {
                                          imageUrlToDelete = currentImageUrl;
                                      }
                                      newImageFile = null;
                                      currentImageUrl = '';
                                      imageStateNotifier.value++;
                                    },
                                    tooltip: 'Quitar imagen',
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // --- ¡AQUÍ USAMOS NUESTRO NUEVO ESTILO! ---
                    _buildStyledTextFormField(controller: tipoController, label: 'Tipo de Afección'),
                    _buildStyledTextFormField(controller: prevencionController, label: 'Métodos de Prevención', maxLines: 3),
                    _buildStyledTextFormField(controller: riesgoController, label: 'Época de Mayor Riesgo', maxLines: 3),
                  ],
                ),
              ),
            ),
          ),
          // --- ¡AQUÍ ESTÁN LOS BOTONES REDISEÑADOS! ---
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                side: BorderSide(color: (isDark ? AppColorsDark.danger : AppColorsLight.danger).withOpacity(0.7)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // ... (La lógica de guardado se mantiene exactamente igual)
                   try {
                    if (imageUrlToDelete != null && imageUrlToDelete!.isNotEmpty) {
                      await storageService.deleteImageFromUrl(imageUrlToDelete!);
                    }

                    String? finalImageUrl;
                    if (newImageFile != null) {
                      finalImageUrl = await storageService.uploadDiseaseImage(newImageFile!);
                      if (finalImageUrl == null) throw Exception("No se pudo subir la nueva imagen.");
                    } else {
                      finalImageUrl = currentImageUrl;
                    }

                    final updatedData = {
                      'imagen_url': finalImageUrl,
                      'tipo': tipoController.text,
                      'prevencion': prevencionController.text,
                      'riesgo': riesgoController.text,
                    };
                    
                    final success = await _detectionService.updateDiseaseDetails(widget.disease['id_enfermedad'], updatedData);
                    if (success) {
                      if (mounted) Navigator.of(context).pop(true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                      ));
                    }
                  }
                }
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      );
    },
  );
  
  // ... (El resto del método `if (result == true)` se mantiene igual)
  if (result == true) {
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('¡Enfermedad actualizada con éxito!'),
        backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
      ));
    }
  }
}

// NUEVO MÉTODO AUXILIAR PARA ESTILIZAR LOS CAMPOS DE TEXTO
Widget _buildStyledTextFormField({
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
}) {
  final theme = Theme.of(context);
  final bool isDark = theme.brightness == Brightness.dark;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary),
        // Estilo del fondo
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        // Estilo de los bordes
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Sin borde visible por defecto
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    ),
  );
}

}