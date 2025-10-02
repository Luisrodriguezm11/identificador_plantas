// frontend/lib/screens/manage_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'edit_recommendations_screen.dart';
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

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
      appBar: TopNavigationBar(
        selectedIndex: 4,
        isAdmin: true,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,

      // --- 👇 CAMBIO: Eliminamos el FloatingActionButton de aquí 👇 ---
      
      body: Stack(
        children: [
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditRecommendationsScreen(disease: disease),
          ),
        ).then((_) {
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            // 4. TARJETAS ADAPTATIVAS
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        disease['nombre_comun'] ?? 'Nombre no disponible',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clase: ${disease['roboflow_class']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.edit_note, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}