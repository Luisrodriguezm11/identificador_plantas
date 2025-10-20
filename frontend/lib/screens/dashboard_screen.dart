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
      String displayName = nameParts.first;

      if (nameParts.length > 2) {
        displayName += ' ${nameParts[2]}';
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

 // frontend/lib/screens/dashboard_screen.dart

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
          
          // CAMBIO: Se envuelve el contenido en un LayoutBuilder para obtener la altura de la pantalla.
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  // CAMBIO: Se establece una altura mínima igual a la de la pantalla.
                  // Esto fuerza al contenedor a ocupar todo el espacio vertical disponible.
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          // CAMBIO: Se centra todo el contenido verticalmente.
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: kToolbarHeight + 30),
                            _buildWelcomeSection(),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                            const SizedBox(height: 40),
                            _buildMainAnalysisCard(),
                            const SizedBox(height: 40),
                            _buildRecentHistorySection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final theme = Theme.of(context);

    // RESPONSIVE: Usamos LayoutBuilder para adaptar el texto al ancho disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determinamos el tamaño de la fuente basado en el ancho del contenedor.
        final double titleSize;
        if (constraints.maxWidth > 800) {
          titleSize = 52; // Tamaño grande para escritorio
        } else if (constraints.maxWidth > 500) {
          titleSize = 42; // Tamaño mediano para tabletas o ventanas pequeñas
        } else {
          titleSize = 34; // Tamaño compacto para móviles
        }

        return Column(
          children: [
            Text(
              '¡Bienvenido, $_userName!',
              textAlign: TextAlign.center,
              // Aplicamos el tamaño de fuente dinámico.
              style: theme.textTheme.displayLarge?.copyWith(fontSize: titleSize, letterSpacing: -1.5),
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
    );
  }

  Widget _buildActionButtons() {
    // El widget Wrap ya es inherentemente responsive, por lo que no necesita grandes cambios.
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

    // RESPONSIVE: Usamos LayoutBuilder para cambiar de Fila a Columna en pantallas pequeñas.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Definimos un "breakpoint" o punto de quiebre. Si el ancho es menor, cambiamos el diseño.
        bool useMobileLayout = constraints.maxWidth < 650;

        // Creamos una lista de widgets de texto para no repetir código.
        List<Widget> textContent = [
          Text(
            "Detectar Plagas y Enfermedades",
            // RESPONSIVE: Hacemos el texto centrado en el layout móvil.
            textAlign: useMobileLayout ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            "Sube una imagen de la hoja de tu planta de café para obtener un diagnóstico instantáneo y recomendaciones de tratamiento.",
            // RESPONSIVE: Hacemos el texto centrado en el layout móvil.
            textAlign: useMobileLayout ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodyMedium,
          ),
        ];

        // Creamos el botón para no repetir código.
        Widget actionButton = ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_outlined, size: 24),
          label: const Text("Iniciar Nuevo Análisis"),
          onPressed: () async {
            final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DetectionScreen()));
            if (result == true && mounted) {
              _fetchRecentAnalyses();
            }
          },
          style: AppTheme.accentButtonStyle(context),
        );

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
              // RESPONSIVE: Elegimos qué layout mostrar (Fila o Columna).
              child: useMobileLayout
                  ? Column( // Layout para pantallas estrechas
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...textContent, // El contenido de texto
                        const SizedBox(height: 30),
                        actionButton, // El botón
                      ],
                    )
                  : Row( // Layout para pantallas anchas
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: textContent,
                          ),
                        ),
                        const SizedBox(width: 40),
                        actionButton,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

// frontend/lib/screens/dashboard_screen.dart

  Widget _buildRecentHistorySection() {
    final theme = Theme.of(context);
    final analysesToShow = _recentAnalyses.take(4).toList();
    final bool showViewAllCard = _recentAnalyses.length > 4;
    final int itemCount = showViewAllCard ? analysesToShow.length + 1 : analysesToShow.length;

    // Agrupamos el contenido en una variable para aplicarle el Transform
    Widget gridContent = _isLoading
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : _recentAnalyses.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Text(
                    "Aún no has analizado ningún archivo.",
                  ),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 24), // Padding para que el contenido no se corte
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  childAspectRatio: 2 / 3.2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (showViewAllCard && index == analysesToShow.length) {
                    return _buildViewAllCard();
                  }
                  final analysis = analysesToShow[index];
                  return _buildAnalysisCard(analysis);
                },
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Mis Análisis Recientes",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
          ),
        ),
        // CAMBIO: Usamos Transform.translate para aplicar un espacio negativo
        // y subir visualmente todo el bloque de tarjetas.
        Transform.translate(
          offset: const Offset(0.0, -10.0), // Mueve las tarjetas 20 píxeles hacia arriba
          child: gridContent,
        ),
      ],
    );
  }

  Widget _buildViewAllCard() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
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
                            color: Colors.white,
                            fontSize: 18, // Mantenemos el tamaño reducido
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // --- INICIO DE LA CORRECCIÓN ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                fechaFormateada,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                                    onPressed: () async {
                                      // 1. Convertimos la función a `async`.
                                      // 2. Esperamos el resultado del diálogo.
                                      final result = await showDialog(
                                        context: context,
                                        builder: (BuildContext dialogContext) {
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: AnalysisDetailScreen(analysis: analysis),
                                          );
                                        },
                                      );

                                      // 3. Si el resultado es `true`, significa que algo
                                      //    se borró y debemos refrescar la lista.
                                      if (result == true) {
                                        _fetchRecentAnalyses();
                                      }
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
                        // --- FIN DE LA CORRECCIÓN ---
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