// frontend/lib/screens/user_specific_analyses_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
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
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
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
              child: Text('Enviar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _detectionService.adminDeleteHistoryItem(analysisId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Análisis enviado a la papelera'),
              backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success),
        );
        _refreshAnalyses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger),
        );
      }
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 4,
        isAdmin: true,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          
          //Container(
            //decoration: AppTheme.backgroundDecoration,
          //),
          //const AnimatedBubbleBackground(),


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

          // BOTÓN DE REGRESO AÑADIDO
          Positioned(
            top: kToolbarHeight + 10,
            left: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : AppColorsLight.surface.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  child: IconButton(
                    tooltip: 'Volver a Monitor de Productores',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).iconTheme.color),
                    onPressed: () {
                      Navigator.pop(context);
                    },
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
          'Análisis de ${widget.user['nombre_completo']}',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Revisa el historial completo de análisis para este productor. Puedes ver los detalles de cada uno o enviarlos a la papelera.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysesGrid() {
    final theme = Theme.of(context);
    return FutureBuilder<List<dynamic>>(
      future: _analysesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text('Este usuario no tiene análisis.',
                  style: theme.textTheme.bodyMedium));
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
          // 4. TARJETAS ADAPTATIVAS
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
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, shadows: [const Shadow(blurRadius: 4, color: Colors.black54)]),
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
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                            ),
                            Row(
                              children: [
                                // 5. BOTONES DE ACCIÓN ADAPTATIVOS
                                _buildActionButton(
                                  icon: Icons.info_outline,
                                  color: isDark ? AppColorsDark.info : AppColorsLight.info,
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
                                  color: isDark ? AppColorsDark.danger : AppColorsLight.danger,
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.3 : 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            icon: Icon(icon, color: isDark ? Colors.white : theme.colorScheme.primary, size: 20),
            tooltip: tooltip,
          ),
        ),
      ),
    );
  }
}