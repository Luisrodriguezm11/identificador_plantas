// frontend/lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart'; // Importa la nueva ruta
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/detection_service.dart';
import 'package:frontend/widgets/side_navigation_rail.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'detection_screen.dart';
import 'history_screen.dart';
import 'dart:ui'; // Para el efecto de blur

class DashboardScreen extends StatefulWidget {
  final bool isNavExpanded;

  const DashboardScreen({super.key, this.isNavExpanded = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DetectionService _detectionService = DetectionService();
  late bool _isNavExpanded;
  bool _isLoading = true;
  List<dynamic> _recentAnalyses = [];

  @override
  void initState() {
    super.initState();
    _isNavExpanded = widget.isNavExpanded;
    _fetchRecentAnalyses();
  }

  Future<void> _fetchRecentAnalyses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final history = await _detectionService.getHistory();
      if (mounted) {
        setState(() {
          _recentAnalyses = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar análisis: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: HistoryScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: TrashScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 3:
        _logout(context);
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
    // El resto del código de build no cambia...
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
          ),
          Row(
            children: [
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 0,
                onToggle: () {
                  setState(() {
                    _isNavExpanded = !_isNavExpanded;
                  });
                },
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dashboard",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.3))]),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : RefreshIndicator(
                                onRefresh: _fetchRecentAnalyses,
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 250,
                                    childAspectRatio: 2 / 2.8,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                                  itemCount: _recentAnalyses.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _buildAddNewCard();
                                    }
                                    final analysis = _recentAnalyses[index - 1];
                                    return _buildAnalysisCard(analysis);
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAddNewCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DetectionScreen()));
        _fetchRecentAnalyses();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 50),
                  SizedBox(height: 16),
                  Text("Analizar Nueva Hoja", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> analysis) {
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
                          analysis['resultado_prediccion'],
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              fechaFormateada,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30.0),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30.0),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: TextButton(
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Más info'),
                                  ),
                                ),
                              ),
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
}