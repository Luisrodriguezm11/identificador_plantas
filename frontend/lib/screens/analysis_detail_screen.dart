// frontend/lib/screens/analysis_detail_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:frontend/services/detection_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS EL TEMA

class AnalysisDetailScreen extends StatefulWidget {
  final Map<String, dynamic> analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  final DetectionService _detectionService = DetectionService();
  final AuthService _authService = AuthService();

  final PageController _pageController = PageController();
  final List<String> _imageUrls = [];
  int _currentPage = 0;

  bool _isAdmin = false;

  // --- ✨ CORRECCIÓN: El color puede ser nulo al inicio ---
  Color? _dominantColor;
  bool _isColorLoading = true;
  bool _isDetailsLoading = true;
  String _diseaseInfo = '';
  List<dynamic> _recommendationsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // No se llama _loadInitialData aquí directamente para asegurar que el `context` esté disponible.
    // `didChangeDependencies` es un lugar más seguro para operaciones que dependen del `context` como el tema.
    _setupImages();
    _checkAdminStatus();
    _fetchDiseaseDetails();

    _pageController.addListener(() {
      final newPage = _pageController.page?.round();
      if (newPage != null && newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    });
  }

  // --- ✨ CORRECCIÓN: Usamos didChangeDependencies para cargar el color ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dominantColor == null) { // Solo se ejecuta la primera vez
      _updateDominantColor();
    }
  }


  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setupImages() {
    final frontImageUrl = widget.analysis['url_imagen'];
    final backImageUrl = widget.analysis['url_imagen_reverso'];

    if (frontImageUrl != null) {
      _imageUrls.add(frontImageUrl);
    }
    if (backImageUrl != null) {
      _imageUrls.add(backImageUrl);
    }
  }

  Future<void> _updateDominantColor() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColorsDark.surface.withOpacity(0.6) : AppColorsLight.surface.withOpacity(0.8);

    if (_imageUrls.isEmpty) {
      if(mounted) setState(() { _dominantColor = defaultColor; _isColorLoading = false; });
      return;
    }
    try {
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        NetworkImage(_imageUrls.first),
        size: const Size(200, 200),
      );
      if (mounted) {
        setState(() {
          _dominantColor = (paletteGenerator.dominantColor?.color ?? defaultColor).withOpacity(isDark ? 0.6 : 0.8);
          _isColorLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dominantColor = defaultColor;
          _isColorLoading = false;
        });
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

  Future<void> _deleteItem() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final analysisId = widget.analysis['id_analisis'];
    if (analysisId == null) return;

    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text('¿Enviar este análisis a la papelera?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Enviar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      bool success;
      if (_isAdmin) {
        success = await _detectionService.adminDeleteHistoryItem(analysisId);
      } else {
        success = await _detectionService.deleteHistoryItem(analysisId);
      }
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Análisis enviado a la papelera'),
            backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success,
          ),
        );
        Navigator.of(context).pop(true);
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
  
  Future<void> _fetchDiseaseDetails() async {
    try {
      final String diseaseName =
          widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'];
      final details = await _detectionService.getDiseaseDetails(diseaseName);

      if (mounted) {
        setState(() {
          _diseaseInfo =
              details['info']['descripcion'] ?? 'No hay descripción disponible.';
          _recommendationsList = details['recommendations'];
          _isDetailsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error al cargar detalles: ${e.toString()}";
          _isDetailsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    
    final confidenceValue =
        widget.analysis['confidence'] ?? widget.analysis['confianza'] ?? 0.0;
    final double confidence = (confidenceValue as num).toDouble();

    final String prediction = widget.analysis['prediction'] ??
        widget.analysis['resultado_prediccion'] ??
        "Análisis no disponible";

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildImageCarousel(),
                ),
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // --- ✨ CORRECCIÓN: Se usa un AnimatedSwitcher para la transición ---
                      AnimatedSwitcher(
                        duration: const Duration(seconds: 1),
                        child: _isColorLoading
                            ? Container( // Estado de carga inicial
                                key: const ValueKey('loading'),
                                color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                                child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
                              )
                            : Container( // Contenido ya cargado
                                key: const ValueKey('loaded'),
                                color: _dominantColor,
                                child: _buildDetailsSection(prediction, confidence),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_imageUrls.isNotEmpty)
          PageView.builder(
            controller: _pageController,
            itemCount: _imageUrls.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_imageUrls[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          )
        else
          const Center(child: Text("Imagen no disponible", style: TextStyle(color: Colors.white))),

        if (_imageUrls.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCarouselArrow(isLeft: true),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildCarouselArrow(isLeft: false),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildPageIndicator(),
          ),
        ],
      ],
    );
  }

  Widget _buildCarouselArrow({required bool isLeft}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(isLeft ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios, color: Colors.white),
        onPressed: () {
          if (isLeft) {
            _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          } else {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_imageUrls.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            height: 8.0,
            width: _currentPage == index ? 24.0 : 8.0,
            decoration: BoxDecoration(
              color: _currentPage == index ? Colors.white : Colors.white54,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildDetailsSection(String prediction, double confidence) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        _formatPredictionName(prediction),
                        style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, shadows: [const Shadow(blurRadius: 4, color: Colors.black54)]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Confianza del ${(confidence * 100).toStringAsFixed(1)}%",
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                     _buildActionButton(
                      icon: Icons.delete_outline,
                      color: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                      tooltip: 'Enviar a la papelera',
                      onPressed: _deleteItem,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.close,
                      color: Colors.grey.shade600,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: [
                Tab(text: 'INFORMACIÓN'),
                Tab(text: 'TRATAMIENTOS'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isDetailsLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)))
                      : TabBarView(
                          children: [
                            SingleChildScrollView(
                              child: Text(_diseaseInfo, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.5)),
                            ),
                            _buildRecommendationsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    final theme = Theme.of(context);
    return _recommendationsList.isEmpty
        ? Center(
            child: Text(
              "No hay tratamientos registrados para esta condición.",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          )
        : ListView.builder(
            itemCount: _recommendationsList.length,
            itemBuilder: (context, index) {
              final treatment = _recommendationsList[index];
              return _buildTreatmentCard(treatment);
            },
          );
  }

  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatment['nombre_comercial'] ?? 'Sin nombre',
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const Divider(color: Colors.white30, height: 24),
                _buildInfoRow('Ingrediente Activo:', treatment['ingrediente_activo']),
                _buildInfoRow('Tipo:', treatment['tipo_tratamiento']),
                _buildInfoRow('Dosis:', treatment['dosis']),
                _buildInfoRow('Frecuencia:', treatment['frecuencia_aplicacion']),
                _buildInfoRow('Notas:', treatment['notas_adicionales']),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final theme = Theme.of(context);
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4),
          children: [
            TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            TextSpan(text: value),
          ],
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