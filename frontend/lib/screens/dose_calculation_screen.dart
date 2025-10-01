// frontend/lib/screens/dose_calculation_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/treatment_service.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'dart:ui';

class DoseCalculationScreen extends StatefulWidget {
  const DoseCalculationScreen({super.key});

  @override
  State<DoseCalculationScreen> createState() => _DoseCalculationScreenState();
}

class _DoseCalculationScreenState extends State<DoseCalculationScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final AuthService _authService = AuthService();
  
  bool _isAdmin = false;
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
    _loadInitialData();
  }
    
  Future<void> _loadInitialData() async {
    await _checkAdminStatus();
    await _fetchEnfermedades();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _fetchEnfermedades() async {
    setState(() => _isLoadingEnfermedades = true);
    try {
      final enfermedades = await _treatmentService.getEnfermedades();
      if (mounted) {
        setState(() {
          _enfermedades = enfermedades;
          _isLoadingEnfermedades = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar enfermedades. Revisa tu conexión.';
          _isLoadingEnfermedades = false;
        });
      }
    }
  }

  Future<void> _fetchTratamientos(int enfermedadId) async {
    setState(() {
      _isLoadingTratamientos = true;
      _tratamientos = [];
      _selectedTratamiento = null;
      _errorMessage = null;
    });

    try {
      final tratamientos = await _treatmentService.getTratamientos(enfermedadId);
      if (mounted) {
        setState(() {
          _tratamientos = tratamientos;
          _isLoadingTratamientos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar tratamientos. Inténtalo de nuevo.';
          _isLoadingTratamientos = false;
        });
      }
    }
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
        // Ya estamos aquí
        break;
      case 4:
        if (_isAdmin) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
        }
        break;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(
        selectedIndex: 3,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      _buildHeaderSection(),
                      const SizedBox(height: 60),
                      _isLoadingEnfermedades
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _buildSelectionCard(),
                      const SizedBox(height: 30),
                      if (_selectedTratamiento != null)
                        _buildTratamientoDetailsCard(),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
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
    return Column(
      children: [
        const Text(
          'Guía de Tratamientos',
          textAlign: TextAlign.center,
          style: TextStyle(
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
            'Selecciona una enfermedad o plaga para ver los tratamientos recomendados, sus componentes y la dosis sugerida.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard() {
    return _buildGlassCard(
      child: Column(
        children: [
          _buildEnfermedadesDropdown(),
          const SizedBox(height: 20),
          if (_selectedEnfermedad != null) _buildTratamientosDropdown(),
        ],
      ),
    );
  }
  
  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
  
  Widget _buildEnfermedadesDropdown() {
    return DropdownButtonFormField<Enfermedad>(
      value: _selectedEnfermedad,
      hint: const Text('Seleccione una enfermedad o plaga', style: TextStyle(color: Colors.white70)),
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Enfermedad o Plaga',
        labelStyle: const TextStyle(color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      dropdownColor: Colors.grey[850],
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
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        : DropdownButtonFormField<Tratamiento>(
            value: _selectedTratamiento,
            hint: const Text('Seleccione un tratamiento', style: TextStyle(color: Colors.white70)),
            isExpanded: true,
             style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Tratamiento Recomendado',
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
               focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
            dropdownColor: Colors.grey[850],
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
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tratamiento.nombreComercial,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Divider(height: 30, thickness: 1, color: Colors.white30),
          _buildDetailRow('Ingrediente Activo:', tratamiento.ingredienteActivo),
          _buildDetailRow('Tipo de Tratamiento:', tratamiento.tipoTratamiento),
          _buildDetailRow('Dosis Recomendada:', '${tratamiento.dosis} ${tratamiento.unidadMedida}'),
          if (tratamiento.periodoCarencia != null && tratamiento.periodoCarencia!.isNotEmpty)
            _buildDetailRow('Periodo de Carencia:', '${tratamiento.periodoCarencia!} días'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.trim().isEmpty || value.trim() == "0.0" ) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
          children: <TextSpan>[
            TextSpan(text: '$label\n', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}