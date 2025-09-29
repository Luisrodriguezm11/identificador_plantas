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
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'dart:ui';

class DoseCalculationScreen extends StatefulWidget {
  final bool isNavExpanded;
  const DoseCalculationScreen({super.key, this.isNavExpanded = true});

  @override
  State<DoseCalculationScreen> createState() => _DoseCalculationScreenState();
}

class _DoseCalculationScreenState extends State<DoseCalculationScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final AuthService _authService = AuthService();
  
  late bool _isNavExpanded;
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
    _isNavExpanded = widget.isNavExpanded;
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
    // Lógica de navegación (puedes copiarla de history_screen.dart)
     switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)),);
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: HistoryScreen(isNavExpanded: _isNavExpanded)),);
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: TrashScreen(isNavExpanded: _isNavExpanded)),);
        break;
      case 3:
        // Ya estamos aquí
        break;
      case 4:
        if (_isAdmin) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
        } else {
            _logout(context);
        }
        break;
      case 5:
        _logout(context);
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
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
                selectedIndex: 3,
                isAdmin: _isAdmin,
                onToggle: () {
                  setState(() {
                    _isNavExpanded = !_isNavExpanded;
                  });
                },
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _isLoadingEnfermedades
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : _buildContent(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Calcular Dosis de Tratamiento",
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          "Selecciona una enfermedad y un tratamiento para ver los detalles.",
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const SizedBox(height: 32),
        _buildGlassCard(
          child: Column(
            children: [
              _buildEnfermedadesDropdown(),
              const SizedBox(height: 20),
              if (_selectedEnfermedad != null) _buildTratamientosDropdown(),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (_selectedTratamiento != null)
          _buildTratamientoDetailsCard(),
        if (_errorMessage != null)
          Center(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16.0),
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
      hint: const Text('Seleccione una enfermedad', style: TextStyle(color: Colors.white70)),
      isExpanded: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Enfermedad o Plaga',
        labelStyle: const TextStyle(color: Colors.white),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
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
             style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Tratamiento Recomendado',
              labelStyle: const TextStyle(color: Colors.white),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
               focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Divider(height: 20, thickness: 1, color: Colors.white30),
            _buildDetailRow('Ingrediente Activo:', tratamiento.ingredienteActivo),
            _buildDetailRow('Tipo:', tratamiento.tipoTratamiento),
            _buildDetailRow('Dosis:', '${tratamiento.dosis} ${tratamiento.unidadMedida}'),
            if (tratamiento.periodoCarencia != null && tratamiento.periodoCarencia!.isNotEmpty)
              _buildDetailRow('Periodo de Carencia:', '${tratamiento.periodoCarencia!} días'),
          ],
        ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
          children: <TextSpan>[
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}