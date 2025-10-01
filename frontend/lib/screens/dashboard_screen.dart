// frontend/lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/detection_service.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'detection_screen.dart';
import 'history_screen.dart';
import 'dart:ui';
import 'analysis_detail_screen.dart';
import 'admin_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DetectionService _detectionService = DetectionService();
  bool _isLoading = true;
  bool _isAdmin = false;
  String _userName = ''; // Estado para guardar el nombre del usuario
  List<dynamic> _recentAnalyses = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Obtenemos todos los datos necesarios en paralelo
    await Future.wait([
      _checkAdminStatus(),
      _fetchRecentAnalyses(),
      _fetchUserName(), // <-- Nueva función para obtener el nombre
    ]);
  }

  Future<void> _fetchUserName() async {
    final name = await _authService.getUserName();
    if (mounted) {
      setState(() {
        _userName = name ?? 'Usuario';
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _fetchRecentAnalyses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar análisis: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onNavItemTapped(int index) {
    // Lógica de navegación no cambia
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(context,
            NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const TrashScreen()));
        break;
      case 3:
        Navigator.pushReplacement(context,
            NoTransitionRoute(page: const DoseCalculationScreen()));
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
    // --- CORRECCIÓN AQUÍ ---
    // Cambiamos logout() de vuelta a deleteToken() para que coincida con tu auth_service.dart
    await _authService.deleteToken(); 
    // --- FIN DE LA CORRECCIÓN ---
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopNavigationBar(
        selectedIndex: 0,
        isAdmin: _isAdmin,
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
          // Usamos un SingleChildScrollView para evitar overflow en pantallas pequeñas
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      // --- NUEVA SECCIÓN DE BIENVENIDA ---
                      _buildWelcomeSection(),
                      const SizedBox(height: 40),
                      // --- NUEVA SECCIÓN DE BOTONES DE ACCIÓN ---
                      _buildActionButtons(),
                      const SizedBox(height: 60),
                      // --- NUEVA TARJETA PRINCIPAL DE ANÁLISIS ---
                      _buildMainAnalysisCard(),
                      const SizedBox(height: 60),
                      // --- SECCIÓN DE HISTORIAL RECIENTE (MODIFICADA) ---
                      _buildRecentHistorySection(),
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

  // --- WIDGET DE BIENVENIDA ---
  Widget _buildWelcomeSection() {
    return Column(
      children: [
        Text(
          '¡Bienvenido, $_userName!',
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
          child: const Text(
            'Tu asistente inteligente para el monitoreo de cultivos de café. Empieza un nuevo análisis o revisa tu historial.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }

  // --- WIDGET PARA BOTONES DE ACCIÓN ---
  Widget _buildActionButtons() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _buildActionButton(
          icon: Icons.history_outlined,
          label: 'Historial Completo',
          onTap: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const HistoryScreen())),
        ),
        _buildActionButton(
          icon: Icons.calculate_outlined,
          label: 'Guía de Tratamientos',
          onTap: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const DoseCalculationScreen())),
        ),
        _buildActionButton(
          icon: Icons.delete_sweep_outlined,
          label: 'Papelera',
          onTap: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const TrashScreen())),
        ),
      ],
    );
  }
  
  // Widget para un botón de acción individual
  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- WIDGET PARA LA TARJETA PRINCIPAL DE ANÁLISIS ---
  Widget _buildMainAnalysisCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Detectar Plagas y Enfermedades",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Sube una imagen de la hoja de tu planta de café para obtener un diagnóstico instantáneo y recomendaciones de tratamiento.",
                      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 24),
                label: const Text("Iniciar Nuevo Análisis"),
                onPressed: () async {
                  final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DetectionScreen()));
                  if (result == true && mounted) {
                    _fetchRecentAnalyses();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET PARA LA SECCIÓN DE HISTORIAL ---
  Widget _buildRecentHistorySection() {
    final analysesToShow = _recentAnalyses.take(4).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Mis Análisis Recientes",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recentAnalyses.isEmpty
                ? const Center(
                    child: Text(
                      "Aún no has analizado ningún archivo.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      childAspectRatio: 2 / 2.8,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: analysesToShow.length,
                    itemBuilder: (context, index) {
                      final analysis = analysesToShow[index];
                      return _buildAnalysisCard(analysis);
                    },
                  ),
      ],
    );
  }

  // --- El resto de tus widgets (_formatPredictionName, _buildAnalysisCard) no necesitan cambios ---
  String _formatPredictionName(String originalName) {
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName = originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) {
      return 'Desconocido';
    }
    return formattedName[0].toUpperCase() + formattedName.substring(1);
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
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.white70, size: 40),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8)
                        ],
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
                          _formatPredictionName(
                              analysis['resultado_prediccion']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black54)
                            ],
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
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30.0),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30.0),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext dialogContext) {
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: AnalysisDetailScreen(
                                                analysis: analysis),
                                          );
                                        },
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
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