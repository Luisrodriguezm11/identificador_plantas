// frontend/lib/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:frontend/widgets/side_navigation_rail.dart'; // Importa tu barra de navegación
import 'package:frontend/services/auth_service.dart'; // Para el logout
import 'package:frontend/screens/login_screen.dart'; // Para redirigir al login
import 'manage_recommendations_screen.dart';
import 'admin_user_list_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/detection_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isNavExpanded = true;
  final AuthService _authService = AuthService();

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
          // Fondo con efecto blur (¡ya lo tienes!)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                // color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          Row(
            children: [
              // Barra de navegación lateral
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 4, // El índice para el "Panel Admin"
                isAdmin: true,
                onToggle: () {
                  setState(() {
                    _isNavExpanded = !_isNavExpanded;
                  });
                },
onItemSelected: (index) {
  final navigator = Navigator.of(context);
  if (index == 5) { // Cerrar Sesión
    _logout(context);
    return;
  }
  if (index == 4) return; // Ya estamos en el panel de admin

  Widget page;
  switch (index) {
    case 0:
      page = const DashboardScreen();
      break;
    case 1:
      page = const DetectionScreen();
      break;
    case 2:
      page = const HistoryScreen();
      break;
    case 3:
      page = const TrashScreen();
      break;
    default:
      return;
  }
  // Usamos pushReplacement para no apilar las pantallas del menú principal
  navigator.pushReplacement(MaterialPageRoute(builder: (context) => page));
},
                onLogout: () => _logout(context),
              ),
              // Contenido principal
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAdminCard(
                          context,
                          icon: Icons.edit_note,
                          title: 'Gestionar Recomendaciones',
                          subtitle: 'Añade, edita o elimina tratamientos para cada enfermedad.',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageRecommendationsScreen()));
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildAdminCard(
                          context,
                          icon: Icons.bar_chart,
                          title: 'Ver Análisis de Usuarios',
                          subtitle: 'Monitorea todos los análisis enviados por los productores.',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUserListScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tu widget _buildAdminCard no necesita cambios, ¡ya está perfecto!
  Widget _buildAdminCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    // ... (tu código existente)
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 48),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}