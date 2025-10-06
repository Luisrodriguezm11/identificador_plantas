// frontend/lib/screens/manage_recommendations_screen.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/detection_service.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'dart:ui';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_recommendations_screen.dart';
import 'package:frontend/config/app_theme.dart'; 
import 'package:frontend/services/storage_service.dart';

class ManageRecommendationsScreen extends StatefulWidget {
  const ManageRecommendationsScreen({super.key});

  @override
  State<ManageRecommendationsScreen> createState() =>
      _ManageRecommendationsScreenState();
}

class _ManageRecommendationsScreenState extends State<ManageRecommendationsScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _diseasesFuture;

  @override
  void initState() {
    super.initState();
    _diseasesFuture = _detectionService.getAdminAllDiseases();
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
      case 4:
        Navigator.of(context).pop();
        break;
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
                      _buildDiseasesGrid(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                    tooltip: 'Volver al Panel de Administrador',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
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


  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 3. TEXTOS DINÁMICOS
        Text(
          'Gestionar Tratamientos',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Selecciona una condición para añadir, editar o eliminar las recomendaciones de tratamiento asociadas.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDiseasesGrid() {
    final theme = Theme.of(context);
    return FutureBuilder<List<dynamic>>(
      future: _diseasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No se encontraron enfermedades.', style: theme.textTheme.bodyMedium));
        }

        final diseases = snapshot.data!;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            childAspectRatio: 16 / 6,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: diseases.length,
          itemBuilder: (context, index) {
            final disease = diseases[index];
            return _buildDiseaseCard(disease);
          },
        );
      },
    );
  }

Widget _buildDiseaseCard(Map<String, dynamic> disease) {
  final theme = Theme.of(context);
  final bool isDark = theme.brightness == Brightness.dark;

  // Un GestureDetector para la acción principal (tocar la tarjeta)
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditRecommendationsScreen(disease: disease),
        ),
      ).then((_) {
        // Refresca la lista por si hubo cambios en la pantalla de edición
        setState(() {
          _diseasesFuture = _detectionService.getAdminAllDiseases();
        });
      });
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.biotech_outlined, color: theme.textTheme.bodyMedium?.color, size: 40),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // <-- CAMBIO: Centramos el texto verticalmente
                  children: [
                    Text(
                      disease['nombre_comun'] ?? 'Nombre no disponible',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2, // Permitimos hasta 2 líneas para el nombre
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clase: ${disease['roboflow_class']}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // --- V CAMBIO: AÑADIMOS UN BOTÓN DE EDITAR DETALLES ---
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: 'Editar Tratamientos',
                    child: Icon(Icons.edit_note, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 12),
                  // Este es el nuevo botón
                  Tooltip(
                    message: 'Editar Detalles de la Enfermedad',
                child: IconButton(
                  icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
                  onPressed: () {
                    // ¡Ahora llamamos a la función del diálogo!
                    _showEditDiseaseDialog(disease);
                  },
                ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    ),
  );
}

// frontend/lib/screens/manage_recommendations_screen.dart

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
    final details = await _detectionService.getDiseaseDetails(disease['roboflow_class']);
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
  // --- V NUEVA VARIABLE PARA SABER QUÉ BORRAR ---
  String? imageUrlToDelete;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: isDark ? Colors.grey[900]?.withOpacity(0.9) : AppColorsLight.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Editar Detalles de "${disease['nombre_comun']}"'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                              // --- V LÓGICA DE BORRADO AL CAMBIAR IMAGEN ---
                              // Si ya había una imagen, la marcamos para borrar
                              if (currentImageUrl.isNotEmpty) {
                                imageUrlToDelete = currentImageUrl;
                              }
                              newImageFile = pickedFile;
                              currentImageUrl = ''; // Limpiamos la URL actual para que se muestre la nueva
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
                                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo_outlined, size: 40), SizedBox(height: 8), Text("Toca para añadir una imagen")]))
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
                                  // --- V LÓGICA DE BORRADO AL PRESIONAR 'X' ---
                                  // Marcamos la imagen actual para ser borrada
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
                // ... (los TextFormField no cambian)
                TextFormField( controller: tipoController, decoration: const InputDecoration(labelText: 'Tipo de Afección'), ),
                const SizedBox(height: 16),
                TextFormField( controller: prevencionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Métodos de Prevención'),),
                const SizedBox(height: 16),
                TextFormField( controller: riesgoController, maxLines: 3, decoration: const InputDecoration(labelText: 'Época de Mayor Riesgo'),),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  // --- V LÓGICA DE GUARDADO ACTUALIZADA ---
                  
                  // 1. Borra la imagen antigua si se marcó para borrar
                  if (imageUrlToDelete != null && imageUrlToDelete!.isNotEmpty) {
                    await storageService.deleteImageFromUrl(imageUrlToDelete!);
                  }

                  // 2. Sube la nueva imagen si existe
                  String? finalImageUrl;
                  if (newImageFile != null) {
                    finalImageUrl = await storageService.uploadDiseaseImage(newImageFile!);
                    if (finalImageUrl == null) throw Exception("No se pudo subir la nueva imagen.");
                  } else {
                    finalImageUrl = currentImageUrl;
                  }

                  // 3. Actualiza la base de datos
                  final updatedData = {
                    'imagen_url': finalImageUrl,
                    'tipo': tipoController.text,
                    'prevencion': prevencionController.text,
                    'riesgo': riesgoController.text,
                  };
                  
                  final success = await _detectionService.updateDiseaseDetails(disease['id_enfermedad'], updatedData);
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
      );
    },
  );
  
  if (result == true) {
    setState(() {
      _diseasesFuture = _detectionService.getAdminAllDiseases();
    });
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('¡Enfermedad actualizada con éxito!'),
        backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
      ));
    }
  }
}
}
