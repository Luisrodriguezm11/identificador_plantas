// frontend/lib/screens/history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import '../services/detection_service.dart';
import 'trash_screen.dart';
import 'dart:ui';
import 'analysis_detail_screen.dart';
import 'detection_screen.dart';
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

class HistoryScreen extends StatefulWidget {
  final int? highlightedAnalysisId;

  const HistoryScreen({super.key, this.highlightedAnalysisId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic>? _historyList;
  bool _isLoading = true;
  String? _errorMessage;

  bool _isAdmin = false;

  int? _highlightedId;
  AnimationController? _highlightController;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.highlightedAnalysisId;

    _loadInitialData();

    if (_highlightedId != null) {
      _highlightController = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      )..repeat(reverse: true);

      Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _highlightController?.stop();
          setState(() {
            _highlightedId = null;
          });
        }
      });
    }
  }

  Future<void> _loadInitialData() async {
    await _checkAdminStatus();
    await _fetchHistory();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final history = await _detectionService.getHistory();
      if (mounted) {
        setState(() {
          _historyList = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatPredictionName(String originalName) {
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName =
        originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) {
      return 'Desconocido';
    }
    return formattedName[0].toUpperCase() + formattedName.substring(1);
  }

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
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

  Future<void> _deleteItem(int analysisId, int index) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text('¿Enviar este análisis a la papelera?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Enviar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _detectionService.deleteHistoryItem(analysisId);
      if (success) {
        setState(() => _historyList!.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Análisis enviado a la papelera'),
              backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
          ),
        );
      }
    }
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 1,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      _buildHeaderSection(),
                      const SizedBox(height: 60),
                      _buildHistoryGrid(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            // ... (botón de regreso sin cambios)
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
                    color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    tooltip: 'Volver al Dashboard',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
                    onPressed: () => Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen())),
                  ),
                ),
              ),
            ),
          ),
          // El botón "+ Nuevo Análisis" se ha eliminado de aquí.
        ],
      ),

      // --- 👇 AQUÍ ESTÁ EL NUEVO BOTÓN INTEGRADO ---
      floatingActionButton: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const DetectionScreen(),
                ));
                if (result == true && mounted) {
                  _fetchHistory();
                }
              },
              borderRadius: BorderRadius.circular(28.0),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(isDark ? 0.3 : 0.4),
                  borderRadius: BorderRadius.circular(28.0),
                  border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 12),
                    Text(
                      "Nuevo Análisis",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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


  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 3. TEXTOS DINÁMICOS
        Text(
          'Historial de Análisis',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Aquí encontrarás todos los diagnósticos que has realizado. Puedes ver los detalles o enviar un análisis a la papelera.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryGrid() {
    final theme = Theme.of(context);
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : _errorMessage != null
            ? Center(child: Text('Error: $_errorMessage', style: TextStyle(color: theme.colorScheme.error)))
            : _historyList == null || _historyList!.isEmpty
                ? Center(
                    child: Text(
                      'No hay análisis en tu historial.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchHistory,
                    color: theme.colorScheme.primary,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        childAspectRatio: 2 / 2.8,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _historyList!.length,
                      itemBuilder: (context, index) {
                        final analysis = _historyList![index];
                        return _buildHistoryCard(analysis, index);
                      },
                    ),
                  );
  }

  Widget _buildHistoryCard(Map<String, dynamic> analysis, int index) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final fecha = DateTime.parse(analysis['fecha_analisis']);
    final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";
    final bool isHighlighted = analysis['id_analisis'] == _highlightedId;

    Widget cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          // 5. TARJETAS ADAPTATIVAS
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
                            color: Colors.white, // El texto sobre el gradiente oscuro se mantiene blanco
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
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: Icons.info_outline,
                                  color: isDark ? AppColorsDark.info : AppColorsLight.info,
                                  tooltip: 'Más info',
                                  onPressed: () async {
                                    final result = await showDialog(
                                      context: context,
                                      builder: (BuildContext dialogContext) {
                                        return Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: AnalysisDetailScreen(analysis: analysis),
                                        );
                                      },
                                    );
                                    if (result == true) {
                                      _fetchHistory();
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.delete_outline,
                                  color: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                                  tooltip: 'Enviar a la papelera',
                                  onPressed: () => _deleteItem(analysis['id_analisis'], index),
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

    if (isHighlighted && _highlightController != null) {
      return AnimatedBuilder(
        animation: _highlightController!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24.0),
              // 6. BORDE ANIMADO ADAPTADO AL TEMA
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(_highlightController!.value),
                width: 3,
              ),
            ),
            child: child,
          );
        },
        child: cardContent,
      );
    }

    return cardContent;
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
            // --- 👇 CAMBIO AQUÍ: El color del ícono ahora es siempre blanco 👇 ---
            icon: Icon(icon, color: Colors.white, size: 20),
            tooltip: tooltip,
          ),
        ),
      ),
    );
  }
}