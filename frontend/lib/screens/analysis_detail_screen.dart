// frontend/lib/screens/analysis_detail_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:frontend/services/detection_service.dart';
import 'package:palette_generator/palette_generator.dart';

class AnalysisDetailScreen extends StatefulWidget {
  final Map<String, dynamic> analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  final DetectionService _detectionService = DetectionService();
  
  final PageController _pageController = PageController();
  final List<String> _imageUrls = [];
  int _currentPage = 0;

  Color _dominantColor = Colors.black.withOpacity(0.6);
  bool _isColorLoading = true;
  bool _isDetailsLoading = true;
  String _diseaseInfo = '';
  String _recommendations = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupImages();
    _updateDominantColor();
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
    if (_imageUrls.isEmpty) {
        setState(() => _isColorLoading = false);
        return;
    }
    final PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(
      NetworkImage(_imageUrls.first),
      size: const Size(200, 200),
    );
    if (mounted) {
      setState(() {
        _dominantColor = (paletteGenerator.dominantColor?.color ?? Colors.black)
            .withOpacity(0.6);
        _isColorLoading = false;
      });
    }
  }

  Future<void> _fetchDiseaseDetails() async {
    try {
      final String diseaseName = widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'];
      final details = await _detectionService.getDiseaseDetails(diseaseName);

      final recommendationsList = (details['recommendations'] as List)
          .map((rec) => '• ${rec['tipo_tratamiento']}: ${rec['descripcion_tratamiento']}')
          .join('\n\n');

      if (mounted) {
        setState(() {
          _diseaseInfo = details['info']['descripcion'] ?? 'No hay descripción disponible.';
          _recommendations = recommendationsList.isNotEmpty ? recommendationsList : 'No hay recomendaciones disponibles.';
          _isDetailsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isDetailsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 👇 ESTA ES LA LÍNEA CORREGIDA Y MÁS SEGURA 👇 ---
    // Busca la confianza con ambas claves ('confidence' o 'confianza'),
    // provee un valor por defecto de 0.0, y lo convierte a double de forma segura.
    final confidenceValue = widget.analysis['confidence'] ?? widget.analysis['confianza'] ?? 0.0;
    final double confidence = (confidenceValue as num).toDouble();
    
    final String prediction = widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'] ?? "Análisis no disponible";

    return Center(
      // ... (El resto del código es idéntico al anterior y ya está correcto)
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // --- COLUMNA IZQUIERDA: CARRUSEL DE IMÁGENES ---
                Expanded(
                  flex: 2,
                  child: Stack(
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
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24.0),
                                  bottomLeft: Radius.circular(24.0),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const Center(child: Text("Imagen no disponible", style: TextStyle(color: Colors.white))),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                            begin: Alignment.topLeft,
                            end: Alignment.center,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.4),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      if (_imageUrls.length > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                              onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                            ),
                          ),
                        ),
                      if (_imageUrls.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                              onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                            ),
                          ),
                        ),
                      if (_imageUrls.length > 1)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
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
                          ),
                        ),
                    ],
                  ),
                ),
                
                // --- COLUMNA DERECHA: INFORMACIÓN ---
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        curve: Curves.easeIn,
                        color: _dominantColor,
                        child: DefaultTabController(
                          length: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prediction,
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Confianza del ${(confidence * 100).toStringAsFixed(1)}%",
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 16),
                                const TabBar(
                                  indicatorColor: Colors.white,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white70,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  tabs: [
                                    Tab(text: 'INFORMACIÓN'),
                                    Tab(text: 'RECOMENDACIONES'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _isDetailsLoading
                                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                                      : _errorMessage != null
                                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                                        : TabBarView(
                                            children: [
                                              SingleChildScrollView(
                                                child: Text(_diseaseInfo, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                                              ),
                                              SingleChildScrollView(
                                                child: Text(_recommendations, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                                              ),
                                            ],
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: _isColorLoading,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _isColorLoading ? 1.0 : 0.0,
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
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
}