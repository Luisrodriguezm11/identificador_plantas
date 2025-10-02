// frontend/lib/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'manage_recommendations_screen.dart';
import 'admin_user_list_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();

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
        // Ya estamos en el panel de admin, no hacemos nada.
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
        selectedIndex: 4,
        isAdmin: true,
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
                      _buildAdminCard(
                        context,
                        icon: Icons.spa_outlined,
                        title: 'Gestionar Tratamientos',
                        subtitle:
                            'Añade, edita o elimina tratamientos y recomendaciones para cada enfermedad.',
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageRecommendationsScreen()));
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildAdminCard(
                        context,
                        icon: Icons.people_outline,
                        title: 'Monitor de Productores',
                        subtitle:
                            'Revisa los análisis enviados por todos los productores y gestiona sus datos.',
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AdminUserListScreen()));
                        },
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
          'Panel de Administrador',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Desde aquí puedes gestionar los tratamientos de la plataforma y supervisar la actividad de los productores.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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
            child: Row(
              children: [
                Icon(icon, color: theme.textTheme.headlineMedium?.color, size: 48),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Icon(Icons.arrow_forward_ios, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}