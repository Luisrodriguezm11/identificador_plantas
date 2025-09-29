// frontend/lib/screens/history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart'; // <-- CAMBIO: Importación añadida
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/side_navigation_rail.dart';
import '../services/detection_service.dart';
import 'trash_screen.dart';
import 'dart:ui';
import 'analysis_detail_screen.dart';
import 'detection_screen.dart';

class HistoryScreen extends StatefulWidget {
  final bool isNavExpanded;
  final int? highlightedAnalysisId;

  const HistoryScreen({super.key, this.isNavExpanded = true, this.highlightedAnalysisId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic>? _historyList;
  bool _isLoading = true;
  String? _errorMessage;
  late bool _isNavExpanded;
  
  bool _isAdmin = false; // <-- CAMBIO: Variable para saber si el usuario es admin

  int? _highlightedId;
  AnimationController? _highlightController;

  @override
  void initState() {
    super.initState();
    _isNavExpanded = widget.isNavExpanded;
    _highlightedId = widget.highlightedAnalysisId;
    
    _loadInitialData(); // <-- CAMBIO: Llamamos a la nueva función que carga todo

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
  
  // <-- CAMBIO: Nueva función para cargar los datos en orden
  Future<void> _loadInitialData() async {
    await _checkAdminStatus(); // Primero verificamos si es admin
    await _fetchHistory();     // Luego cargamos el historial
  }

  // <-- CAMBIO: Nueva función para verificar el rol del usuario
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
    // Tu función _fetchHistory original no necesita cambios
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
    // Tu función original no necesita cambios
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName = originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) {
      return 'Desconocido'; 
    }
    return formattedName[0].toUpperCase() + formattedName.substring(1);
  }

  // <-- CAMBIO: Actualizamos la lógica de navegación
  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)),);
        break;
      case 1:
        // Ya estamos aquí, no hacemos nada
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: TrashScreen(isNavExpanded: _isNavExpanded)),);
        break;
      case 3:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DoseCalculationScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 4:
        // Si es admin, navega al panel. Si no, es el botón de logout.
        if (_isAdmin) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
        } else {
            _logout(context);
        }
        break;
      case 5:
        // Este caso solo ocurre si es admin (es el botón de logout)
        _logout(context);
        break;
    }
  }

  void _logout(BuildContext context) async {
    // Tu función original no necesita cambios
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _deleteItem(int analysisId, int index) async {
    // Tu función original no necesita cambios
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text('¿Enviar este análisis a la papelera?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar'),),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Enviar', style: TextStyle(color: Colors.red)),),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _detectionService.deleteHistoryItem(analysisId);
      if (success) {
        setState(() {
          _historyList!.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Análisis enviado a la papelera'), backgroundColor: Colors.green),);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DetectionScreen(isNavExpanded: _isNavExpanded),
          ));
          if (result == true && mounted) {
            _fetchHistory();
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Nuevo Análisis',
      ),
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
                isAdmin: _isAdmin, // <-- CAMBIO: Pasamos el valor de admin al widget
                selectedIndex: 1,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Historial de Análisis",
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.3))]),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white70),
                            label: const Text("Volver al Dashboard", style: TextStyle(color: Colors.white70)),
                            onPressed: () => Navigator.of(context).pushReplacement(
                              NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : _errorMessage != null
                                ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.white)))
                                : _historyList!.isEmpty
                                    ? const Center(child: Text('No hay análisis en tu historial.', style: TextStyle(color: Colors.white)))
                                    : RefreshIndicator(
                                        onRefresh: _fetchHistory,
                                        child: GridView.builder(
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

  Widget _buildHistoryCard(Map<String, dynamic> analysis, int index) {
    // Tu widget _buildHistoryCard original no necesita cambios
    final fecha = DateTime.parse(analysis['fecha_analisis']);
    final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";
    final bool isHighlighted = analysis['id_analisis'] == _highlightedId;

    Widget cardContent = ClipRRect(
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
                                  color: Colors.blue,
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
                                  color: Colors.red,
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
              border: Border.all(
                color: Colors.blueAccent.withOpacity(_highlightController!.value),
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
    // Tu widget _buildActionButton original no necesita cambios
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