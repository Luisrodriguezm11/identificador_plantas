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

  Color _dominantColor = Colors.black.withOpacity(0.6);
  bool _isColorLoading = true;
  bool _isDetailsLoading = true;
  String _diseaseInfo = '';
  String _recommendations = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _updateDominantColor();
    _fetchDiseaseDetails();
  }

  Future<void> _updateDominantColor() async {
    final PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(
      NetworkImage(widget.analysis['url_imagen']),
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
      final String diseaseName = widget.analysis['resultado_prediccion'];
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
    final String imageUrl = widget.analysis['url_imagen'];
    final String prediction = widget.analysis['resultado_prediccion'];
    final double confidence = widget.analysis['confianza'] ?? 0.0;

    return Center(
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
                Expanded(
                  flex: 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24.0),
                            bottomLeft: Radius.circular(24.0),
                          ),
                        ),
                      ),
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
                    ],
                  ),
                ),
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
                      // --- ESTE ES EL CAMBIO FINAL Y DEFINITIVO ---
                      Visibility(
                        visible: _isColorLoading, // Solo es visible si estamos cargando
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