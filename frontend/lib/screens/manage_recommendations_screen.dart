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
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // --- INICIO DE LA CORRECCIÓN ---
          // Envolvemos el contenido principal con SingleChildScrollView
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
                      const SizedBox(height: 40), // Espacio al final para que no quede pegado
                    ],
                  ),
                ),
              ),
            ),
          ),
          // --- FIN DE LA CORRECCIÓN ---
        ],
      ),
    );
  }
  
  Widget _buildHeaderSection() {
    return Column(
      children: [
        const Text(
          'Gestionar Tratamientos',
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
            'Selecciona una condición para añadir, editar o eliminar las recomendaciones de tratamiento asociadas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDiseasesGrid() {
    return FutureBuilder<List<dynamic>>(
      future: _diseasesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No se encontraron enfermedades.', style: TextStyle(color: Colors.white)));
        }

        final diseases = snapshot.data!;

        return GridView.builder(
          shrinkWrap: true,
          // El scroll ahora lo maneja el SingleChildScrollView padre
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
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24.0),
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
                      const SizedBox(height: 8),
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