// frontend/lib/screens/trash_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/main_layout.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import '../services/detection_service.dart';
import 'dart:ui';
import 'package:frontend/config/app_theme.dart';

/// Pantalla que muestra los análisis eliminados (en la papelera).
/// Permite a los usuarios restaurar análisis o eliminarlos permanentemente.
/// Los administradores tienen vistas y permisos adicionales.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();
  List<dynamic>? _trashedList;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Carga los datos iniciales necesarios para la pantalla.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _checkAdminStatus();
    await _fetchTrashedItems();
  }

  /// Verifica si el usuario actual tiene permisos de administrador.
  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  /// Obtiene la lista de análisis en la papelera desde el servicio.
  /// Llama a un endpoint diferente si el usuario es administrador.
  Future<void> _fetchTrashedItems() async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    try {
      List<dynamic> items;
      if (_isAdmin) {
        items = await _detectionService.getAdminTrashedItems();
      } else {
        items = await _detectionService.getTrashedItems();
      }

      if (mounted) {
        setState(() {
          _trashedList = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger));
      }
    }
  }

  /// Formatea el nombre de la predicción para una mejor lectura.
  String _formatPredictionName(String originalName) {
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName =
        originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) return 'Desconocido';
    return formattedName[0].toUpperCase() + formattedName.substring(1);
  }

  /// Gestiona la navegación al pulsar un ítem de la barra de navegación superior.
  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
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

  /// Cierra la sesión del usuario y lo redirige a la pantalla de login.
  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  /// Restaura un análisis de la papelera a la pantalla de historial.
  Future<void> _restoreItem(int analysisId, int index) async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final restoredItem = _trashedList![index];
    bool success = false;

    try {
      if (_isAdmin) {
        success = await _detectionService.adminRestoreHistoryItem(analysisId);
      } else {
        success = await _detectionService.restoreHistoryItem(analysisId);
      }

      if (success && mounted) {
        setState(() {
          _trashedList!.removeAt(index);
        });

        if (_isAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Análisis restaurado en el historial del usuario.'),
            backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
          ));
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Análisis Restaurado'),
              content: const Text('El análisis ha sido movido de vuelta a tu historial.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
ElevatedButton(
  onPressed: () {
    // 1. Cierra el diálogo.
    Navigator.of(context).pop();

    // 2. Navega a la ruta '/history' DENTRO del navegador de MainLayout,
    //    pasando el ID del análisis como argumento.
    mainNavigatorKey.currentState?.pushReplacementNamed(
      '/history',
      arguments: {'highlightedAnalysisId': restoredItem['id_analisis']},
    );
  },
  child: const Text('Ver en Historial'),
),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo restaurar: ${e.toString()}'),
            backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger));
      }
    }
  }

  /// Elimina permanentemente un análisis de la base de datos.
  Future<void> _permanentlyDeleteItem(int analysisId, int index) async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrado Permanente'),
        content: const Text('Esta acción no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Borrar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _detectionService.permanentlyDeleteItem(analysisId);
        if (success) {
          setState(() => _trashedList!.removeAt(index));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Borrado permanentemente'),
                backgroundColor: Colors.orange));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger));
        }
      }
    }
  }

  /// Elimina permanentemente todos los análisis que están en la papelera del usuario.
  Future<void> _emptyTrash() async {
    if (_trashedList == null || _trashedList!.isEmpty) return;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Papelera'),
        content: const Text('Todos los análisis en la papelera se eliminarán permanentemente. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Vaciar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger)),
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
            SnackBar(
                content: const Text('La papelera ha sido vaciada'),
                backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger),
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 2,
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
                      _buildTrashGrid(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
        ],
      ),
      floatingActionButton: (!_isLoading && _trashedList != null && _trashedList!.isNotEmpty)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _emptyTrash,
                  borderRadius: BorderRadius.circular(28.0),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColorsDark.danger : AppColorsLight.danger).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(color: (isDark ? AppColorsDark.danger : AppColorsLight.danger).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Vaciar Papelera",
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
          )
        : null,
    );
  }

  /// Construye el encabezado principal de la pantalla de la papelera.
  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    // RESPONSIVE: Utiliza LayoutBuilder para adaptar el tamaño del texto.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Define tamaños de fuente dinámicos basados en el ancho disponible.
        final double titleSize;
        final double subtitleSize;
        if (constraints.maxWidth > 800) {
          titleSize = 45; // displayMedium es ~45px
          subtitleSize = 16; // bodyLarge es ~16px
        } else if (constraints.maxWidth > 500) {
          titleSize = 38;
          subtitleSize = 15;
        } else {
          titleSize = 30;
          subtitleSize = 14;
        }

        return Column(
          children: [
            Text(
              'Papelera',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(fontSize: titleSize),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Aquí encontrarás los análisis que has eliminado. Puedes restaurarlos o eliminarlos permanentemente.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: subtitleSize),
              ),
            ),
          ],
        );
      }
    );
  }

  /// Construye la cuadrícula que muestra los análisis eliminados.
  Widget _buildTrashGrid() {
    final theme = Theme.of(context);
    // RESPONSIVE: Esta cuadrícula ya es adaptable gracias a SliverGridDelegateWithMaxCrossAxisExtent.
    // No requiere cambios ya que ajusta el número de columnas automáticamente.
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : _trashedList == null || _trashedList!.isEmpty
            ? Center(
                child: Text('La papelera está vacía.',
                    style: theme.textTheme.bodyMedium))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
              );
  }

  /// Construye la tarjeta individual para cada análisis en la papelera.
  Widget _buildTrashCard(Map<String, dynamic> item, int index) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

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
                    item['url_imagen'],
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
                        if (_isAdmin && item['email'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              item['email'],
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround, // Ligeramente más espaciado
                          children: [
                            _buildActionButton(
                                icon: Icons.restore_from_trash_outlined,
                                color: isDark ? AppColorsDark.info : AppColorsLight.info,
                                onPressed: () => _restoreItem(item['id_analisis'], index),
                                tooltip: 'Restaurar'),
                            _buildActionButton(
                                icon: Icons.delete_forever_outlined,
                                color: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                                onPressed: () => _permanentlyDeleteItem(item['id_analisis'], index),
                                tooltip: 'Eliminar permanentemente'),
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

  /// Construye un botón de acción circular con efecto de vidrio.
  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, required String tooltip}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.3 : 0.2),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.3)),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 20), // Aumentado ligeramente el tamaño
            tooltip: tooltip,
          ),
        ),
      ),
    );
  }
}