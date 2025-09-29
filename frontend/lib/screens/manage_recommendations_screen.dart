// frontend/lib/screens/manage_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'edit_recommendations_screen.dart';

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
  bool _isNavExpanded = true;

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
      final navigator = Navigator.of(context);
      if (index == 5) {
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

  // (Tu función _formatDiseaseName no necesita cambios)

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
                selectedIndex: 4,
                isAdmin: true,
                onToggle: () {
                  setState(() {
                    _isNavExpanded = !_isNavExpanded;
                  });
                },
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                     Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Gestionar Enfermedades",
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
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: FutureBuilder<List<dynamic>>(
                        future: _diseasesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(color: Colors.white));
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.redAccent)));
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text('No se encontraron enfermedades.',
                                    style: TextStyle(color: Colors.white)));
                          }

                          final diseases = snapshot.data!;

                          // --- CAMBIO: Usamos GridView.builder en lugar de ListView.builder ---
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400, // Un poco más anchas
                              childAspectRatio: 16 / 5, // Más rectangulares
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                            ),
                            itemCount: diseases.length,
                            itemBuilder: (context, index) {
                              final disease = diseases[index];
                              return _buildDiseaseCard(disease); // <-- Usamos el nuevo widget
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ¡NUEVO WIDGET PARA LA TARJETA DE ENFERMEDAD! ---
  Widget _buildDiseaseCard(Map<String, dynamic> disease) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditRecommendationsScreen(disease: disease),
          ),
        ).then((_) {
          // Recargamos por si hubo cambios al volver
          setState(() {
            _diseasesFuture = _detectionService.getAdminAllDiseases();
          });
        });
      },
      child: ClipRRect(
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
            child: Row(
              children: [
                const Icon(Icons.biotech_outlined, color: Colors.white, size: 40),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        disease['nombre_comun'] ?? 'Nombre no disponible',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clase: ${disease['roboflow_class']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.edit_note, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}