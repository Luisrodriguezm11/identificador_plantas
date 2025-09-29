// frontend/lib/screens/edit_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
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
  bool _isNavExpanded = true;

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
      final navigator = Navigator.of(context);
      if (index == 5) {
        _logout(context);
        return;
      }
      Widget page;
      switch (index) {
        case 0:
          page = const DashboardScreen();
          break;
        case 1:
          page = const HistoryScreen();
          break;
        case 2:
          page = const TrashScreen();
          break;
        case 3:
          page = const DoseCalculationScreen();
          break;
        case 4:
          page = const AdminDashboardScreen();
          break;
        default:
          return;
      }
      navigator.pushReplacement(NoTransitionRoute(page: page));
  }


  Future<void> _showEditDialog({Map<String, dynamic>? treatment}) async {
    final _formKey = GlobalKey<FormState>();
    final bool isEditing = treatment != null;

    final TextEditingController nameController = TextEditingController(text: isEditing ? treatment['nombre_comercial'] : '');
    final TextEditingController ingredientController = TextEditingController(text: isEditing ? treatment['ingrediente_activo'] : '');
    final TextEditingController typeController = TextEditingController(text: isEditing ? treatment['tipo_tratamiento'] : '');
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
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextFormField(controller: nameController, label: 'Nombre Comercial'),
                  _buildTextFormField(controller: ingredientController, label: 'Ingrediente Activo'),
                  _buildTextFormField(controller: typeController, label: 'Tipo (Sistémico, De Contacto...)'),
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
                if (_formKey.currentState!.validate()) {
                  final treatmentData = {
                    'id_enfermedad': widget.disease['id_enfermedad'],
                    'nombre_comercial': nameController.text,
                    'ingrediente_activo': ingredientController.text,
                    'tipo_tratamiento': typeController.text,
                    'frecuencia_aplicacion': frequencyController.text,
                    'notas_adicionales': notesController.text,
                    'dosis': null, 
                  };

                  try {
                    if (isEditing) {
                      await _detectionService.updateTreatment(treatment!['id_tratamiento'], treatmentData);
                    } else {
                      await _detectionService.addTreatment(treatmentData);
                    }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        tooltip: 'Añadir Tratamiento',
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/background.jpg"), fit: BoxFit.cover),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(),
            ),
          ),
          Row(
            children: [
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 4,
                isAdmin: true,
                onToggle: () => setState(() => _isNavExpanded = !_isNavExpanded),
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                       child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.disease['nombre_comun'],
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white70),
                            label: const Text("Volver", style: TextStyle(color: Colors.white70)),
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _errorMessage != null
                              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                              : _treatments.isEmpty
                                ? const Center(child: Text("No hay tratamientos para esta enfermedad.", style: TextStyle(color: Colors.white70, fontSize: 16)))
                                : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                  itemCount: _treatments.length,
                                  itemBuilder: (context, index) {
                                    final treatment = _treatments[index];
                                    return Card(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(treatment['nombre_comercial'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                            const Divider(color: Colors.white30, height: 20),
                                            _buildInfoRow('Ingrediente Activo:', treatment['ingrediente_activo']),
                                            _buildInfoRow('Tipo:', treatment['tipo_tratamiento']),
                                            _buildInfoRow('Frecuencia:', treatment['frecuencia_aplicacion']),
                                            _buildInfoRow('Notas:', treatment['notas_adicionales']),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                _buildGlassIconButton(
                                                  icon: Icons.edit,
                                                  color: Colors.blueAccent,
                                                  onPressed: () => _showEditDialog(treatment: treatment),
                                                ),
                                                const SizedBox(width: 8),
                                                _buildGlassIconButton(
                                                  icon: Icons.delete_forever,
                                                  color: Colors.redAccent,
                                                  onPressed: () => _deleteTreatment(treatment['id_tratamiento']),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return ClipRRect(
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Roboto'),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}