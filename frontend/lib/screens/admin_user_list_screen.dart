// frontend/lib/screens/admin_user_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'admin_analyses_screen.dart';
import 'user_specific_analyses_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _usersFuture;
  // La variable _isNavExpanded ya no es necesaria

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
          // Navegamos hacia atrás porque esta pantalla es hija del Admin Dashboard
          Navigator.of(context).pop();
          break;
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Añadimos la barra de navegación superior
      appBar: TopNavigationBar(
        selectedIndex: 4,
        isAdmin: true,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/background.jpg"), fit: BoxFit.cover),
            ),
          ),
          // 2. Reestructuramos el layout para ser consistente
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      _buildHeaderSection(),
                      const SizedBox(height: 60),
                      _buildUsersGrid(),
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
  
  // 3. Nuevo widget para el encabezado de la sección
  Widget _buildHeaderSection() {
    return Column(
      children: [
        const Text(
          'Monitor de Productores',
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
            'Visualiza la lista de productores que han realizado análisis. Selecciona uno para ver su historial específico o mira todos los análisis juntos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        // Botón para ver todos los análisis
         _buildGlassButton(
            context,
            icon: Icons.grid_view_rounded,
            label: 'Ver todos los análisis juntos',
            onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAnalysesScreen()));
            }
          ),
      ],
    );
  }

  // 4. Nuevo widget para la grilla de usuarios
  Widget _buildUsersGrid() {
    return FutureBuilder<List<dynamic>>(
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
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            childAspectRatio: 2 / 2.8,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  // El widget _buildUserCard y _buildGlassButton se mantienen, ya que su diseño es consistente
  Widget _buildUserCard(Map<String, dynamic> user) {
    // ... (Tu código original de _buildUserCard va aquí, sin cambios)
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

  Widget _buildGlassButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) {
    // ... (Tu código original de _buildGlassButton va aquí, sin cambios)
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
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