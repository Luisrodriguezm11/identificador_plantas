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
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'dart:ui';
import 'package:frontend/config/app_theme.dart';

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
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 3,
        isAdmin: _isAdmin,
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
                    tooltip: 'Volver al Dashboard',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
                    onPressed: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen())),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassDropdown<Enfermedad>(
            value: _selectedEnfermedad,
            hintText: 'Seleccione una enfermedad o plaga',
            items: _enfermedades.map((Enfermedad e) {
              return DropdownMenuItem<Enfermedad>(
                value: e,
                child: Text(e.nombreComun),
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
          ),
          const SizedBox(height: 20),
          if (_selectedEnfermedad != null)
            _isLoadingTratamientos
              ? const Center(child: CircularProgressIndicator())
              : _buildGlassDropdown<Tratamiento>(
                  value: _selectedTratamiento,
                  hintText: 'Seleccione un tratamiento',
                  items: _tratamientos.map((Tratamiento t) {
                    return DropdownMenuItem<Tratamiento>(
                      value: t,
                      child: Text(t.nombreComercial),
                    );
                  }).toList(),
                  onChanged: (Tratamiento? newValue) {
                    setState(() {
                      _selectedTratamiento = newValue;
                    });
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildGlassDropdown<T>({
    required String hintText,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<T>(
              value: value,
              isExpanded: true,
              hint: Text(hintText, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
              onChanged: onChanged,
              items: items,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16),
              dropdownColor: isDark ? Colors.grey[850] : AppColorsLight.surface,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: InputBorder.none,
              ),
              icon: Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
            ),
          ),
        ),
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