// frontend/lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/config/app_theme.dart';
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
//import 'package:frontend/widgets/animated_bubble_background.dart';

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
  String _userName = '';
  List<dynamic> _recentAnalyses = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _checkAdminStatus(),
      _fetchRecentAnalyses(),
      _fetchUserName(),
    ]);
  }

  Future<void> _fetchUserName() async {
    final fullName = await _authService.getUserName();
    if (mounted && fullName != null && fullName.isNotEmpty) {
      final nameParts = fullName.split(' ');
      String displayName = nameParts.first; // Empieza con el primer nombre

      // Si hay al menos un apellido, lo añade
      if (nameParts.length > 2) {
        displayName += ' ${nameParts[2]}'; // <-- ¡AQUÍ ESTÁ LA MAGIA!
      }
      
      setState(() {
        _userName = displayName;
      });
    } else if (mounted) {
      setState(() {
        _userName = 'Usuario';
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
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cargar análisis: $e'),
              backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger),
        );
      }
    }
  }

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
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
        if (_isAdmin) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
        }
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
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 0,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
        //const AnimatedBubbleBackground(),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- 👇 CAMBIO: Menos espacio arriba ---
                      SizedBox(height: kToolbarHeight + 30), // Antes era + 60
                      _buildWelcomeSection(),
                      // --- 👇 CAMBIO: Menos espacio aquí ---
                      const SizedBox(height: 30), // Antes era 40
                      _buildActionButtons(),
                      // --- 👇 CAMBIO: Menos espacio aquí ---
                      const SizedBox(height: 40), // Antes era 60
                      _buildMainAnalysisCard(),
                      // --- 👇 CAMBIO: Menos espacio aquí ---
                      const SizedBox(height: 40), // Antes era 60
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

  // --- WIDGETS DE CONSTRUCCIÓN ADAPTADOS AL TEMA ---

  Widget _buildWelcomeSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // <--- CAMBIO: Usa la variable _userName ---
        Text(
          '¡Bienvenido, $_userName!',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52, letterSpacing: -1.5),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Tu asistente inteligente para el monitoreo de cultivos de café. Empieza un nuevo análisis o revisa tu historial.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

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
  
  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

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
            // 3. TARJETAS ADAPTATIVAS
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.textTheme.bodyMedium?.color, size: 28),
                const SizedBox(height: 12),
                Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainAnalysisCard() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Detectar Plagas y Enfermedades",
                      style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sube una imagen de la hoja de tu planta de café para obtener un diagnóstico instantáneo y recomendaciones de tratamiento.",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              // 4. BOTÓN DE ACENTO
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 24),
                label: const Text("Iniciar Nuevo Análisis"),
                onPressed: () async {
                  final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DetectionScreen()));
                  if (result == true && mounted) {
                    _fetchRecentAnalyses();
                  }
                },
                style: AppTheme.accentButtonStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

// --- 👇 PASO 1: REEMPLAZA ESTA FUNCIÓN COMPLETA 👇 ---
  Widget _buildRecentHistorySection() {
    final theme = Theme.of(context);
    // Tomamos los primeros 4 análisis para mostrar
    final analysesToShow = _recentAnalyses.take(4).toList();
    // Verificamos si hay más de 4 para decidir si mostramos la tarjeta extra
    final bool showViewAllCard = _recentAnalyses.length > 4;
    // El número de items en el grid será 4, o 5 si hay más análisis
    final int itemCount = showViewAllCard ? analysesToShow.length + 1 : analysesToShow.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mis Análisis Recientes",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            height: 0.1, // Mantenemos el ajuste de altura
          ),
        ),
        const SizedBox(height: 16), // Espacio ajustado
        _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : _recentAnalyses.isEmpty
                ? Center(
                    child: Text(
                      "Aún no has analizado ningún archivo.",
                      style: theme.textTheme.bodyMedium,
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
                    itemCount: itemCount, // <-- Usamos el nuevo contador de items
                    itemBuilder: (context, index) {
                      // Si debemos mostrar la tarjeta extra Y este es el último item...
                      if (showViewAllCard && index == analysesToShow.length) {
                        // ...construimos la tarjeta "Ver Todo".
                        return _buildViewAllCard();
                      }
                      // De lo contrario, mostramos la tarjeta de análisis normal.
                      final analysis = analysesToShow[index];
                      return _buildAnalysisCard(analysis);
                    },
                  ),
      ],
    );
  }

  // --- 👇 PASO 2: AÑADE ESTA NUEVA FUNCIÓN A TU CLASE 👇 ---
  Widget _buildViewAllCard() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      // Navegación a la pantalla de historial
      onTap: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const HistoryScreen())),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 60, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Ver Historial Completo",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final fecha = DateTime.parse(analysis['fecha_analisis']);
    final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
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
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined, color: isDark ? Colors.white70 : Colors.black54, size: 40),
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
                            color: Colors.white, // El texto aquí siempre será blanco por el gradiente
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
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext dialogContext) {
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: AnalysisDetailScreen(analysis: analysis),
                                          );
                                        },
                                      );
                                    },
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