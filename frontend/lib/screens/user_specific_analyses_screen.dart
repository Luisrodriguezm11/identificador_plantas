// frontend/lib/screens/user_specific_analyses_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'analysis_detail_screen.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/helpers/custom_route.dart';

class UserSpecificAnalysesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserSpecificAnalysesScreen({super.key, required this.user});

  @override
  State<UserSpecificAnalysesScreen> createState() =>
      _UserSpecificAnalysesScreenState();
}

class _UserSpecificAnalysesScreenState
    extends State<UserSpecificAnalysesScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  late Future<List<dynamic>> _analysesFuture;

  @override
  void initState() {
    super.initState();
    _analysesFuture =
        _detectionService.getAnalysesForUser(widget.user['id_usuario']);
  }

  void _refreshAnalyses() {
    setState(() {
      _analysesFuture =
          _detectionService.getAnalysesForUser(widget.user['id_usuario']);
    });
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
        Navigator.of(context).pop();
        break;
    }
  }

  String _formatPredictionName(String originalName) {
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName =
        originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) return 'Desconocido';
    return formattedName[0].toUpperCase() + formattedName.substring(1);
  }

  Future<void> _deleteItem(int analysisId) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text('¿Enviar este análisis a la papelera?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enviar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _detectionService.adminDeleteHistoryItem(analysisId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Análisis enviado a la papelera'),
              backgroundColor: Colors.green),
        );
        _refreshAnalyses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
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
                  fit: BoxFit.cover),
            ),
          ),
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
                      _buildAnalysesGrid(),
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
    return Column(
      children: [
        Text(
          'Análisis de ${widget.user['nombre_completo']}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Revisa el historial completo de análisis para este productor. Puedes ver los detalles de cada uno o enviarlos a la papelera.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysesGrid() {
    return FutureBuilder<List<dynamic>>(
      future: _analysesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text('Este usuario no tiene análisis.',
                  style: TextStyle(color: Colors.white)));
        }

        final analyses = snapshot.data!;

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
          itemCount: analyses.length,
          itemBuilder: (context, index) {
            final analysis = analyses[index];
            return _buildAnalysisCard(analysis);
          },
        );
      },
    );
  }
  
  // Los widgets _buildAnalysisCard y _buildActionButton no necesitan cambios
  Widget _buildAnalysisCard(Map<String, dynamic> analysis) {
    // ... (Tu código original de _buildAnalysisCard va aquí, sin cambios)
    final fecha = DateTime.parse(analysis['fecha_analisis']);
    final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
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
                  Image.network(
                    analysis['url_imagen'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
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
                          _formatPredictionName(analysis['resultado_prediccion']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fechaFormateada,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: Icons.info_outline,
                                  color: Colors.blue,
                                  tooltip: 'Más info',
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: AnalysisDetailScreen(analysis: analysis),
                                      ),
                                    );
                                    if(result == true) {
                                      _refreshAnalyses();
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.delete_outline,
                                  color: Colors.red,
                                  tooltip: 'Enviar a la papelera',
                                  onPressed: () => _deleteItem(analysis['id_analisis']),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, required String tooltip}) {
    // ... (Tu código original de _buildActionButton va aquí, sin cambios)
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 20),
            tooltip: tooltip,
          ),
        ),
      ),
    );
  }
}