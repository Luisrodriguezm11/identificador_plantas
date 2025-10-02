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
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

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
      final tratamientos =
          await _treatmentService.getTratamientos(enfermedadId);
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
        // Ya estamos aquí
        break;
      case 4:
        if (_isAdmin) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
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
    final theme = Theme.of(context);

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
          // 2. FONDO UNIFICADO
          Container(
            decoration: AppTheme.backgroundDecoration,
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
                          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                          : _buildSelectionCard(),
                      const SizedBox(height: 30),
                      if (_selectedTratamiento != null)
                        _buildTratamientoDetailsCard(),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        // 3. TEXTOS DINÁMICOS
        Text(
          'Guía de Tratamientos',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Selecciona una enfermedad o plaga para ver los tratamientos recomendados, sus componentes y la dosis sugerida.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          // 4. TARJETAS ADAPTATIVAS
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildEnfermedadesDropdown() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<Enfermedad>(
      value: _selectedEnfermedad,
      hint: Text('Seleccione una enfermedad o plaga', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
      isExpanded: true,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
      // 5. ESTILOS DE DROPDOWN ADAPTATIVOS
      decoration: InputDecoration(
        labelText: 'Enfermedad o Plaga',
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
      ),
      dropdownColor: isDark ? Colors.grey[850] : AppColorsLight.surface,
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return _isLoadingTratamientos
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
          )
        : DropdownButtonFormField<Tratamiento>(
            value: _selectedTratamiento,
            hint: Text('Seleccione un tratamiento', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            isExpanded: true,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Tratamiento Recomendado',
              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            ),
            dropdownColor: isDark ? Colors.grey[850] : AppColorsLight.surface,
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
    final theme = Theme.of(context);
    final tratamiento = _selectedTratamiento!;
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tratamiento.nombreComercial,
            style: theme.textTheme.headlineMedium,
          ),
          Divider(height: 30, thickness: 1, color: theme.dividerColor),
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
    if (value.trim().isEmpty || value.trim() == "0.0") return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: <TextSpan>[
            TextSpan(text: '$label\n', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}