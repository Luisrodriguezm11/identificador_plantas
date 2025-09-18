// frontend/lib/screens/trash_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/side_navigation_rail.dart';
import '../services/detection_service.dart';
import 'dart:ui';

class TrashScreen extends StatefulWidget {
  final bool isNavExpanded;

  const TrashScreen({super.key, this.isNavExpanded = true});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic>? _trashedList;
  bool _isLoading = true;
  late bool _isNavExpanded;

  @override
  void initState() {
    super.initState();
    _isNavExpanded = widget.isNavExpanded;
    _fetchTrashedItems();
  }

  Future<void> _fetchTrashedItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _detectionService.getTrashedItems();
      if (mounted) {
        setState(() {
          _trashedList = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
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

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: HistoryScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 2:
        break;
      case 3:
         Navigator.pushReplacement(context, NoTransitionRoute(page: DoseCalculationScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 4:
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

  Future<void> _restoreItem(int analysisId, int index) async {
      final success = await _detectionService.restoreHistoryItem(analysisId);
      if (success && mounted) {
        final restoredItem = _trashedList!.removeAt(index);
        setState(() {});
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.grey[900]?.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.2))),
              title: const Text('Análisis Restaurado', style: TextStyle(color: Colors.white)),
              content: const Text('El análisis ha sido movido de vuelta a tu historial.', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      NoTransitionRoute(page: HistoryScreen(
                        isNavExpanded: _isNavExpanded,
                        highlightedAnalysisId: restoredItem['id_analisis'],
                      ))
                    );
                  },
                  child: const Text('Ver en Historial'),
                ),
              ],
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo restaurar el análisis'), backgroundColor: Colors.red));
      }
    }

  Future<void> _permanentlyDeleteItem(int analysisId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrado Permanente'),
        content: const Text('Esta acción no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Borrar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _detectionService.permanentlyDeleteItem(analysisId);
      if (success) {
        setState(() => _trashedList!.removeAt(index));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrado permanentemente'), backgroundColor: Colors.orange));
        }
      }
    }
  }

  // --- NUEVA FUNCIÓN PARA VACIAR LA PAPELERA ---
  Future<void> _emptyTrash() async {
    if (_trashedList == null || _trashedList!.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Papelera'),
        content: const Text('Todos los análisis en la papelera se eliminarán permanentemente. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _detectionService.emptyTrash();
        if (success && mounted) {
          setState(() {
            _trashedList!.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La papelera ha sido vaciada'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

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
          ),
          Row(
            children: [
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 2,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                            "Papelera",
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [Shadow(blurRadius: 10, color: Colors.black.withOpacity(0.3))]),
                          ),
                          Row(
                            children: [
                              // --- NUEVO BOTÓN "VACIAR PAPELERA" ---
                              if (_trashedList != null && _trashedList!.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.orangeAccent),
                                  label: const Text("Vaciar Papelera", style: TextStyle(color: Colors.orangeAccent)),
                                  onPressed: _emptyTrash,
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                ),
                              const SizedBox(width: 16),
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Los archivos en la papelera se eliminarán permanentemente después de 30 días.",
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.white))
                            : _trashedList == null || _trashedList!.isEmpty
                                ? const Center(child: Text('La papelera está vacía.', style: TextStyle(color: Colors.white)))
                                : GridView.builder(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 250,
                                      childAspectRatio: 2 / 2.8,
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 20,
                                    ),
                                    itemCount: _trashedList!.length,
                                    itemBuilder: (context, index) {
                                      final item = _trashedList![index];
                                      return _buildTrashCard(item, index);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(Map<String, dynamic> item, int index) {
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
                    item['url_imagen'],
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
                          _formatPredictionName(item['resultado_prediccion']),
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
                          children: [
                            _buildActionButton(
                              icon: Icons.restore_from_trash,
                              color: Colors.blue,
                              onPressed: () => _restoreItem(item['id_analisis'], index),
                              tooltip: 'Restaurar'
                            ),
                            _buildActionButton(
                              icon: Icons.delete_forever,
                              color: Colors.red,
                              onPressed: () => _permanentlyDeleteItem(item['id_analisis'], index),
                              tooltip: 'Eliminar permanentemente'
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 18),
            tooltip: tooltip,
          ),
        ),
      ),
    );
  }
}