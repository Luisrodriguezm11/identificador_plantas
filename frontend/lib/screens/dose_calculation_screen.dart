// frontend/lib/screens/dose_calculation_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart'; // <-- CAMBIO: Importación añadida
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/treatment_service.dart';
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'dart:ui';
class DoseCalculationScreen extends StatefulWidget {
  // --- INICIO DE LA CORRECCIÓN ---
  // Añadimos de nuevo la variable que tu app necesita para la navegación.
  final bool isNavExpanded;
  const DoseCalculationScreen({super.key, this.isNavExpanded = true});
  // --- FIN DE LA CORRECCIÓN ---

  @override
  State<DoseCalculationScreen> createState() => _DoseCalculationScreenState();
}

class _DoseCalculationScreenState extends State<DoseCalculationScreen> {
  // Instancia de nuestro servicio para hacer las llamadas a la API.
  final TreatmentService _treatmentService = TreatmentService();

  // Variables para manejar el estado de la pantalla.
  List<Enfermedad> _enfermedades = [];
  List<Tratamiento> _tratamientos = [];
  Enfermedad? _selectedEnfermedad;
  Tratamiento? _selectedTratamiento;
  
  bool _isLoadingEnfermedades = true;
  bool _isLoadingTratamientos = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Cuando la pantalla se inicia, cargamos la lista de enfermedades.
    _fetchEnfermedades();
  }

  // Función para obtener la lista de enfermedades desde el servicio.
  Future<void> _fetchEnfermedades() async {
    try {
      final enfermedades = await _treatmentService.getEnfermedades();
      setState(() {
        _enfermedades = enfermedades;
        _isLoadingEnfermedades = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar enfermedades. Revisa tu conexión.';
        _isLoadingEnfermedades = false;
      });
    }
  }

  // Función para obtener los tratamientos de la enfermedad seleccionada.
  Future<void> _fetchTratamientos(int enfermedadId) async {
    // Activamos el indicador de carga para los tratamientos.
    setState(() {
      _isLoadingTratamientos = true;
      _tratamientos = []; // Limpiamos la lista anterior
      _selectedTratamiento = null; // Reseteamos la selección anterior
      _errorMessage = null; // Limpiamos errores previos
    });

    try {
      final tratamientos = await _treatmentService.getTratamientos(enfermedadId);
      setState(() {
        _tratamientos = tratamientos;
        _isLoadingTratamientos = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar tratamientos. Inténtalo de nuevo.';
        _isLoadingTratamientos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calcular Dosis'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoadingEnfermedades
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEnfermedadesDropdown(),
                      const SizedBox(height: 20),
                      if (_selectedEnfermedad != null)
                        _buildTratamientosDropdown(),
                      const SizedBox(height: 30),
                      if (_selectedTratamiento != null)
                        _buildTratamientoDetailsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEnfermedadesDropdown() {
    return DropdownButtonFormField<Enfermedad>(
      value: _selectedEnfermedad,
      hint: const Text('Seleccione una enfermedad'),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Enfermedad o Plaga',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _enfermedades.map((Enfermedad enfermedad) {
        return DropdownMenuItem<Enfermedad>(
          value: enfermedad,
          child: Text(enfermedad.nombreComun),
        );
      }).toList(),
      onChanged: (Enfermedad? newValue) {
        setState(() {
          _selectedEnfermedad = newValue;
        });
        if (newValue != null) {
          _fetchTratamientos(newValue.id);
        }
      },
    );
  }
  
  Widget _buildTratamientosDropdown() {
    return _isLoadingTratamientos
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : DropdownButtonFormField<Tratamiento>(
            value: _selectedTratamiento,
            hint: const Text('Seleccione un tratamiento'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Tratamiento Recomendado',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _tratamientos.map((Tratamiento tratamiento) {
              return DropdownMenuItem<Tratamiento>(
                value: tratamiento,
                child: Text(tratamiento.nombreComercial),
              );
            }).toList(),
            onChanged: (Tratamiento? newValue) {
              setState(() {
                _selectedTratamiento = newValue;
              });
            },
          );
  }

  Widget _buildTratamientoDetailsCard() {
    final tratamiento = _selectedTratamiento!;
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tratamiento.nombreComercial,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.teal[800]),
            ),
            const Divider(height: 20, thickness: 1),
            _buildDetailRow('Ingrediente Activo:', tratamiento.ingredienteActivo),
            _buildDetailRow('Tipo:', tratamiento.tipoTratamiento),
            _buildDetailRow('Dosis:', '${tratamiento.dosis} ${tratamiento.unidadMedida}'),
            if (tratamiento.periodoCarencia != null && tratamiento.periodoCarencia!.isNotEmpty)
              _buildDetailRow('Periodo de Carencia:', '${tratamiento.periodoCarencia!} días'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
          children: <TextSpan>[
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}