// frontend/lib/screens/edit_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/top_navigation_bar.dart'; // Importa la barra de navegación superior
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/helpers/custom_route.dart';


class EditRecommendationsScreen extends StatefulWidget {
  final Map<String, dynamic> disease;

  const EditRecommendationsScreen({super.key, required this.disease});

  @override
  State<EditRecommendationsScreen> createState() => _EditRecommendationsScreenState();
}

class _EditRecommendationsScreenState extends State<EditRecommendationsScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic> _treatments = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // 'isNavExpanded' ya no es necesaria
  // bool _isNavExpanded = true;

  @override
  void initState() {
    super.initState();
    _fetchTreatments();
  }

  Future<void> _fetchTreatments() async {
    setState(() => _isLoading = true);
    try {
      final details = await _detectionService.getDiseaseDetails(widget.disease['roboflow_class']);
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
      // Navegación consistente con las otras pantallas
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
          // Podríamos ir al AdminDashboard, pero por ahora un pop() es más intuitivo
          // ya que esta pantalla es hija de una de las opciones del admin dashboard.
          Navigator.of(context).pop();
          break;
      }
  }


  Future<void> _showEditDialog({Map<String, dynamic>? treatment}) async {
    // Tu código original para el diálogo no necesita cambios
    final formKey = GlobalKey<FormState>();
    final bool isEditing = treatment != null;

    final TextEditingController nameController = TextEditingController(text: isEditing ? treatment['nombre_comercial'] : '');
    final TextEditingController ingredientController = TextEditingController(text: isEditing ? treatment['ingrediente_activo'] : '');
    final TextEditingController typeController = TextEditingController(text: isEditing ? treatment['tipo_tratamiento'] : '');
    final TextEditingController doseController = TextEditingController(text: isEditing ? treatment['dosis'] : '');
    final TextEditingController frequencyController = TextEditingController(text: isEditing ? treatment['frecuencia_aplicacion'] : '');
    final TextEditingController notesController = TextEditingController(text: isEditing ? treatment['notas_adicionales'] : '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900]?.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Editar Tratamiento' : 'Añadir Tratamiento', style: const TextStyle(color: Colors.white)),
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
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(true);
                  } catch (e) {
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
    // Tu código original para eliminar no necesita cambios
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este tratamiento? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
          ],
        ));

    if (confirmed == true) {
      try {
        await _detectionService.deleteTreatment(treatmentId);
        _fetchTreatments();
      } catch(e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(
        selectedIndex: 4, // Mantenemos seleccionado el Panel de Admin
        isAdmin: true,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        tooltip: 'Añadir Tratamiento',
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/background.jpg"), fit: BoxFit.cover),
            ),
          ),
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
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Text(
          widget.disease['nombre_comun'],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: const Text(
            'Añade, edita o elimina las recomendaciones de tratamientos para esta condición.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatmentsList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
            : _treatments.isEmpty
                ? const Center(child: Text("No hay tratamientos para esta enfermedad.", style: TextStyle(color: Colors.white70, fontSize: 16)))
                : ListView.builder( // Usamos ListView.builder para eficiencia
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                           _buildGlassIconButton(
                              icon: Icons.edit_outlined,
                              color: Colors.blueAccent,
                              onPressed: () => _showEditDialog(treatment: treatment),
                              tooltip: 'Editar Tratamiento',
                            ),
                            const SizedBox(width: 12),
                           _buildGlassIconButton(
                              icon: Icons.delete_forever_outlined,
                              color: Colors.redAccent,
                              onPressed: () => _deleteTreatment(treatment['id_tratamiento']),
                              tooltip: 'Eliminar Tratamiento',
                            ),
                        ],
                      )
                    ],
                  ),
                  const Divider(color: Colors.white30, height: 30, thickness: 1),
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
              icon: Icon(icon, color: Colors.white),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1)
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
           const SizedBox(height: 4),
           Text(value, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
        ],
      ),
    );
  }
}