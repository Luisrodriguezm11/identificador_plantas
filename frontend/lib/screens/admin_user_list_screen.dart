// frontend/lib/screens/admin_user_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'admin_analyses_screen.dart';
import 'user_specific_analyses_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _usersFuture;
  bool _isNavExpanded = true;

  @override
  void initState() {
    super.initState();
    _usersFuture = _detectionService.getUsersWithAnalyses();
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
      if (index == 5) { // Assuming 5 is logout
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: FutureBuilder<List<dynamic>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Ningún usuario ha realizado análisis aún.', style: TextStyle(color: Colors.white)));
                    }

                    final users = snapshot.data!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Monitor de Productores",
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                               TextButton.icon(
                                icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white70),
                                label: const Text("Volver al Panel", style: TextStyle(color: Colors.white70)),
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                              ),
                            ],
                          )
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: _buildGlassButton(
                            context,
                            icon: Icons.grid_view_rounded,
                            label: 'Ver todos los análisis juntos',
                            onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAnalysesScreen()));
                            }
                          ),
                        ),
                        const SizedBox(height: 24),
                        // --- CAMBIO: Usamos GridView.builder para las tarjetas de usuario ---
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0), // Quitar padding vertical si no se quiere
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 250, // Ancho máximo de cada tarjeta
                              childAspectRatio: 2 / 2.8, // Relación de aspecto similar a las de análisis
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _buildUserCard(user); // <-- Nuestro nuevo widget de tarjeta de usuario
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ¡NUEVO WIDGET _buildUserCard, inspirado en la tarjeta de análisis! ---
  Widget _buildUserCard(Map<String, dynamic> user) {
    // Usamos una imagen de placeholder por ahora, ya que la subida de foto no está implementada.
    // Podrías tener una imagen por defecto o cargar una real si la tuvieras.
    final String userImageUrl = user['profile_image_url'] ?? 'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=USER'; // URL de imagen por defecto o real
    final String userName = user['nombre_completo'] ?? 'Usuario Desconocido';
    final String userEmail = user['email'] ?? 'correo@ejemplo.com';
    final int analysisCount = user['analysis_count'] ?? 0; // Obtener el conteo de análisis

    return GestureDetector(
      onTap: () {
        // Navega a la pantalla de análisis específicos del usuario
        Navigator.push(context, MaterialPageRoute(builder: (context) => UserSpecificAnalysesScreen(user: user)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0), // Bordes más redondeados
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fondo con imagen de usuario (placeholder por ahora)
                    Image.network(
                      userImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.person_outline, color: Colors.white70, size: 40),
                        ),
                      ),
                    ),
                    // Gradiente oscuro en la parte inferior para mejorar la legibilidad del texto
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          // Chip para mostrar el número de análisis
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Chip(
                              avatar: const Icon(Icons.analytics_outlined, color: Colors.white70, size: 18),
                              label: Text('$analysisCount análisis', style: const TextStyle(color: Colors.white)),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Widget para botones de cristal (mantener) ---
  Widget _buildGlassButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: ElevatedButton.icon(
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.3))
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}