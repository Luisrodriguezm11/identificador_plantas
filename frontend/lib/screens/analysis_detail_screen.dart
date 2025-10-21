// frontend/lib/screens/analysis_detail_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart'; // <-- IMPORTANTE: Para cargar fuentes en el PDF
import 'package:frontend/services/detection_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:frontend/config/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:frontend/widgets/disclaimer_widget.dart';

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
  Color? _dominantColor;
  bool _isColorLoading = true;
  bool _isDetailsLoading = true;
  
  Map<String, dynamic> _diseaseInfo = {}; 
  List<dynamic> _recommendationsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupImages();
    _checkAdminStatus();
    _fetchDiseaseDetails();

    _pageController.addListener(() {
      final newPage = _pageController.page?.round();
      if (newPage != null && newPage != _currentPage) {
        setState(() => _currentPage = newPage);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dominantColor == null) {
      _updateDominantColor();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final imageUrl = _imageUrls.first;

    final imageResponse = await http.get(Uri.parse(imageUrl));
    final imageBytes = imageResponse.bodyBytes;
    final image = pw.MemoryImage(imageBytes);

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Bold.ttf"));
    
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    final fecha = DateTime.parse(widget.analysis['fecha_analisis']);
    final formattedDate = DateFormat('dd/MM/yyyy, hh:mm a').format(fecha);
    
    final confidenceValue = widget.analysis['confidence'] ?? widget.analysis['confianza'] ?? 0.0;
    final confidence = (confidenceValue as num).toDouble();
    final formattedConfidence = "${(confidence * 100).toStringAsFixed(1)}%";

    final prediction = widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'] ?? "Análisis no disponible";
    final formattedPrediction = _formatPredictionName(prediction);

    final symptoms = _diseaseInfo['sintomas_clave'] as String? ?? '';
    final affectedParts = _diseaseInfo['partes_afectadas'] as String? ?? '';
    final impact = _diseaseInfo['impacto'] as String? ?? '';
    final conditions = _diseaseInfo['condiciones_favorables'] as String? ?? '';
    final description = _diseaseInfo['descripcion'] as String? ?? 'No disponible.';
    final symptomsList = symptoms.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildPdfHeader(formattedDate),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.Header(
            level: 1,
            text: formattedPrediction,
            textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 28, color: PdfColors.black),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Diagnóstico de Cultivo', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 14)),
              if (!_isPredictionHealthy(prediction))
                pw.Text('Confianza de la IA: $formattedConfidence', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700, fontSize: 14)),
            ]
          ),
          pw.Divider(height: 25),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (symptomsList.isNotEmpty) ...[
                      _buildPdfSectionTitle('Síntomas Clave'),
                      pw.Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: symptomsList.map((symptom) => _buildPdfSymptomChip(symptom)).toList(),
                      ),
                      pw.SizedBox(height: 20),
                    ],
                    _buildPdfInfoCard('Partes Afectadas', affectedParts),
                    pw.SizedBox(height: 10),
                    _buildPdfInfoCard('Impacto en Cultivo', impact),
                    pw.SizedBox(height: 10),
                    _buildPdfInfoCard('Condiciones Favorables', conditions),
                  ]
                )
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                     _buildPdfSectionTitle('Imagen Analizada'),
                     pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(8)
                        ),
                        padding: const pw.EdgeInsets.all(5),
                        height: 250,
                        child: pw.Image(image, fit: pw.BoxFit.contain)
                     ),
                     pw.SizedBox(height: 20),
                     _buildPdfSectionTitle('Descripción General'),
                     pw.Paragraph(
                       text: _isPredictionHealthy(prediction) 
                           ? 'El análisis de la imagen no ha revelado la presencia de plagas o enfermedades comunes del café. La hoja presenta una apariencia saludable, lo cual es un indicador positivo del estado general del cultivo. Se recomienda continuar con las buenas prácticas agrícolas y el monitoreo regular.'
                           : description,
                       style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)
                     )
                  ]
                )
              ),
            ]
          ),
          pw.SizedBox(height: 20),

          if (_recommendationsList.isNotEmpty) ...[
            pw.Header(level: 2, text: 'Tratamientos Recomendados'),
            ..._recommendationsList.map((treatment) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(treatment['nombre_comercial'] ?? 'Sin nombre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Divider(height: 10, color: PdfColors.grey400),
                    pw.Text('Ingrediente Activo: ${treatment['ingrediente_activo'] ?? 'N/A'}'),
                    pw.Text('Tipo: ${treatment['tipo_tratamiento'] ?? 'N/A'}'),
                    pw.Text('Dosis: ${treatment['dosis'] ?? 'N/A'}'),
                    pw.Text('Frecuencia: ${treatment['frecuencia_aplicacion'] ?? 'N/A'}'),
                    if(treatment['notas_adicionales'] != null && treatment['notas_adicionales'].isNotEmpty)
                      pw.Text('Notas: ${treatment['notas_adicionales']}'),
                      _buildPdfDisclaimer(boldFont),
                  ]
                )
              );
            }).toList(),
          ]
        ],
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'reporte-analisis-$formattedPrediction.pdf');
  }

  pw.Widget _buildPdfHeader(String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Reporte de Análisis', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
        pw.Text(date, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
      ]
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text('Generado por Identificador de Plagas - Página ${context.pageNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ]
    );
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blueGrey800)),
    );
  }

  pw.Widget _buildPdfSymptomChip(String label) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey800)),
    );
  }

  pw.Widget _buildPdfInfoCard(String title, String content) {
    if (content.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text(content, style: const pw.TextStyle(fontSize: 10)),
      ]
    );
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  void _setupImages() {
    final frontImageUrl = widget.analysis['url_imagen'];
    final backImageUrl = widget.analysis['url_imagen_reverso'];
    if (frontImageUrl != null) _imageUrls.add(frontImageUrl);
    if (backImageUrl != null) _imageUrls.add(backImageUrl);
  }

  Future<void> _updateDominantColor() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColorsDark.surface.withOpacity(0.6) : AppColorsLight.surface.withOpacity(0.8);
    if (_imageUrls.isEmpty) {
      if(mounted) setState(() { _dominantColor = defaultColor; _isColorLoading = false; });
      return;
    }
    try {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(NetworkImage(_imageUrls.first), size: const Size(200, 200));
      if (mounted) {
        setState(() {
          _dominantColor = (paletteGenerator.dominantColor?.color ?? defaultColor).withOpacity(isDark ? 0.6 : 0.8);
          _isColorLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _dominantColor = defaultColor; _isColorLoading = false; });
    }
  }

  // --- 👇 CORRECCIÓN 1: Lógica mejorada para detectar cualquier resultado "sano". ---
// EN: frontend/lib/screens/analysis_detail_screen.dart -> LÍNEA 344

// --- 👇 INICIO DE LA CORRECCIÓN ---
bool _isPredictionHealthy(String originalName) {
  // Lista de todos los posibles resultados que indican una hoja sana.
  // Se añade 'hojas-sana' que es un posible resultado del modelo de Roboflow.
  final healthyStates = [
    'no se detectó ninguna plaga',
    'sana',
    'hoja sana',
    'hojas-sana' // <-- CORRECCIÓN AÑADIDA
  ];

  return healthyStates.contains(originalName.trim().toLowerCase());
}
// --- 👆 FIN DE LA CORRECCIÓN ---

// --- 👇 NUEVO: Lógica para detectar un resultado no reconocido. ---
bool _isPredictionUnrecognized(String originalName, double confidence) {
  final unrecognizedNames = ['imagen no reconocida', 'desconocido', 'unknown', 'análisis no disponible'];
  // Consideramos no reconocido si el nombre está en la lista O si la confianza es extremadamente baja (ej. 0.0)
  return unrecognizedNames.contains(originalName.trim().toLowerCase()) || confidence == 0.0;
}

  String _formatPredictionName(String originalName) {
    if (_isPredictionHealthy(originalName)) return 'Hoja Sana'; // Usamos la nueva función
    String formattedName = originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) return 'Desconocido';
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Enviar', style: TextStyle(color: isDark ? AppColorsDark.danger : AppColorsLight.danger))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      bool success = _isAdmin ? await _detectionService.adminDeleteHistoryItem(analysisId) : await _detectionService.deleteHistoryItem(analysisId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Análisis enviado a la papelera'), backgroundColor: isDark ? AppColorsDark.success : AppColorsLight.success));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger));
      }
    }
  }
  
  Future<void> _fetchDiseaseDetails() async {
    final String diseaseName = widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'];
    
    // Si la hoja está sana, no hacemos la llamada a la API y terminamos de cargar.
    if (_isPredictionHealthy(diseaseName)) {
      if (mounted) setState(() => _isDetailsLoading = false);
      return;
    }
    
    try {
      final details = await _detectionService.getDiseaseDetails(diseaseName);
      if (mounted) {
        setState(() {
          _diseaseInfo = details['info'] ?? {};
          _recommendationsList = details['recommendations'] ?? [];
          _isDetailsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Error al cargar detalles: ${e.toString()}"; _isDetailsLoading = false; });
    }
  }


@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final bool isDark = theme.brightness == Brightness.dark;
  final confidenceValue = widget.analysis['confidence'] ?? widget.analysis['confianza'] ?? 0.0;
  final double confidence = (confidenceValue as num).toDouble();
  final String prediction = widget.analysis['prediction'] ?? widget.analysis['resultado_prediccion'] ?? "Análisis no disponible";

  return LayoutBuilder(
    builder: (context, constraints) {
      final bool isSmallScreen = constraints.maxWidth < 800;

      final containerWidth = isSmallScreen ? constraints.maxWidth : constraints.maxWidth * 0.75;
      final containerHeight = isSmallScreen ? constraints.maxHeight : constraints.maxHeight * 0.85;

      // El contenido principal (imagen y detalles) que irá en la capa de abajo.
      final mainContent = Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSmallScreen ? 0 : 24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              width: containerWidth,
              height: containerHeight,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.1) : AppColorsLight.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(isSmallScreen ? 0 : 24.0),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
              ),
              child: isSmallScreen
                  ? Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 4 / 3,
                          child: _buildImageCarousel(),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _isColorLoading
                                ? Container(key: const ValueKey('loading'), color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5), child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
                                : Container(key: const ValueKey('loaded'), color: _dominantColor, child: _buildDetailsSection(prediction, confidence, isSmallScreen)),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 2, child: _buildImageCarousel()),
                        Expanded(
                          flex: 3,
                          child: AnimatedSwitcher(
                            duration: const Duration(seconds: 1),
                            child: _isColorLoading
                                ? Container(key: const ValueKey('loading'), color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5), child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)))
                                : Container(key: const ValueKey('loaded'), color: _dominantColor, child: _buildDetailsSection(prediction, confidence, isSmallScreen)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
      
      // --- 👇 CAMBIO PRINCIPAL: Retornamos un Stack ---
      return Stack(
        children: [
          // Capa 1: El contenido principal
          mainContent,

          // Capa 2: Los botones, posicionados encima y solo en pantallas pequeñas
          if (isSmallScreen)
            Positioned(
              top: 16,  // Espacio desde arriba
              right: 16, // Espacio desde la derecha
              child: _buildActionButtonsWidget(isSmallScreen),
            ),
        ],
      );
    },
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
            itemBuilder: (context, index) => Container(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(_imageUrls[index]), fit: BoxFit.cover))),
          )
        else
          const Center(child: Text("Imagen no disponible", style: TextStyle(color: Colors.white))),

        if (_imageUrls.length > 1) ...[
          Align(alignment: Alignment.centerLeft, child: _buildCarouselArrow(isLeft: true)),
          Align(alignment: Alignment.centerRight, child: _buildCarouselArrow(isLeft: false)),
          Align(alignment: Alignment.bottomCenter, child: _buildPageIndicator()),
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
          if (isLeft) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          else _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_imageUrls.length, (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: _currentPage == index ? 24.0 : 8.0,
          decoration: BoxDecoration(color: _currentPage == index ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(12)),
        )),
      ),
    );
  }
 
  
// frontend/lib/screens/analysis_detail_screen.dart

Widget _buildDetailsSection(String prediction, double confidence, bool isSmallScreen) {
  final theme = Theme.of(context);
  
  final bool isHealthy = _isPredictionHealthy(prediction);
  final bool isUnrecognized = _isPredictionUnrecognized(prediction, confidence);
  final String formattedPrediction = _formatPredictionName(prediction);
  final String headerTitle = isUnrecognized ? "Resultado no Válido" : formattedPrediction;

  final titleSection = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // En móvil, dejamos un espacio arriba para que el título no choque con los botones flotantes
      if (isSmallScreen) const SizedBox(height: 32),
      Text(
        headerTitle, 
        style: theme.textTheme.displaySmall?.copyWith(
          color: Colors.white, 
          fontSize: isSmallScreen ? 36 : 45, 
          shadows: [const Shadow(blurRadius: 4, color: Colors.black54)]
        )
      ),
      const SizedBox(height: 8),
      if (!isHealthy && !isUnrecognized)
        Text(
          "Confianza del ${(confidence * 100).toStringAsFixed(1)}%", 
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white.withOpacity(0.8))
        ),
    ],
  );

  return DefaultTabController(
    length: isHealthy || isUnrecognized ? 1 : 2, 
    // Reducimos el padding superior en móvil porque los botones ya no ocupan ese espacio
    child: Padding(
      padding: EdgeInsets.fromLTRB(32, isSmallScreen ? 0 : 24, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 👇 CAMBIO: La lógica de botones para móvil fue removida de aquí ---
          if (isSmallScreen)
            titleSection // Solo mostramos el título
          else
            // La vista de escritorio sigue igual, pero usando el nuevo método
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleSection),
                _buildActionButtonsWidget(isSmallScreen), // Usa el nuevo método
              ],
            ),
          
          const SizedBox(height: 20),
          
          if (!isHealthy && !isUnrecognized)
            TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                Tab(text: 'DIAGNÓSTICO'),
                Tab(text: 'TRATAMIENTOS'),
              ],
            ),

          if (isHealthy || isUnrecognized)
            const SizedBox(height: 20),

          Expanded(
            child: _isDetailsLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)))
                    : TabBarView(
                        children: [
                          if (isUnrecognized)
                            _buildUnrecognizedDiagnosisTab()
                          else if (isHealthy) 
                            _buildHealthyDiagnosisTab()
                          else
                            _buildDiagnosticTab(),
                          
                          if (!isHealthy && !isUnrecognized) 
                            _buildRecommendationsTab(),
                        ],
                      ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildHealthyDiagnosisTab() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            Text(
              "¡Excelentes Noticias!",
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [const Shadow(blurRadius: 2, color: Colors.black45)]
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "No hemos detectado ninguna plaga o enfermedad en tu planta de café. Tu cultivo se ve sano y fuerte. ¡Sigue con el buen trabajo!",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
Widget _buildUnrecognizedDiagnosisTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline_rounded, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            Text(
              "Imagen no reconocida",
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [const Shadow(blurRadius: 2, color: Colors.black45)]
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Lo sentimos, nuestro sistema no pudo identificar una plaga en esta imagen. Para un mejor resultado, por favor intenta con una fotografía más clara y bien enfocada de la hoja.",
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            // --- 👇 NUEVO: Botón de acción para eliminar ---
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _deleteItem, // Reutilizamos la función de borrado existente
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('Eliminar este análisis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColorsDark.danger : AppColorsLight.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordes redondeados
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// frontend/lib/screens/analysis_detail_screen.dart
// frontend/lib/screens/analysis_detail_screen.dart

Widget _buildDiagnosticTab() {
  final theme = Theme.of(context);
  
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 800;
  
  final symptoms = _diseaseInfo['sintomas_clave'] as String? ?? '';
  final affectedParts = _diseaseInfo['partes_afectadas'] as String? ?? '';
  final impact = _diseaseInfo['impacto'] as String? ?? '';
  final conditions = _diseaseInfo['condiciones_favorables'] as String? ?? '';

  final symptomsList = symptoms.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
  final affectedPartsList = affectedParts.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();

  // NUEVO: Creamos una lista de tarjetas para no repetir código
  final List<Widget> infoCards = [
    if (affectedPartsList.isNotEmpty)
      _buildInfoCard(
        icon: Icons.filter_vintage_outlined,
        title: "Partes Afectadas",
        content: affectedPartsList.join('\n'),
      ),
    if (impact.isNotEmpty)
      _buildInfoCard(
        icon: Icons.trending_down_rounded,
        title: "Impacto en Cultivo",
        content: impact,
      ),
    if (conditions.isNotEmpty)
       _buildInfoCard(
        icon: Icons.cloudy_snowing,
        title: "Condiciones Favorables",
        content: conditions,
      ),
  ];

  return SingleChildScrollView(
    padding: const EdgeInsets.only(top: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (symptomsList.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text("Síntomas Clave", style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: symptomsList.map((symptom) => _buildSymptomChip(symptom)).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // --- 👇 CAMBIO PRINCIPAL AQUÍ: Usamos LayoutBuilder y Wrap ---
        LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 16.0;
            final int columns = isSmallScreen ? 1 : 2;
            // Calculamos el ancho de cada tarjeta para que quepan en las columnas
            final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Wrap(
              spacing: spacing,      // Espacio horizontal entre tarjetas
              runSpacing: spacing,   // Espacio vertical entre filas de tarjetas
              children: infoCards.map((card) {
                // Envolvemos cada tarjeta en un SizedBox para darle el ancho calculado
                return SizedBox(
                  width: cardWidth,
                  child: card,
                );
              }).toList(),
            );
          }
        ),
      ],
    ),
  );
}

  Widget _buildSymptomChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.black.withOpacity(0.25),
      side: BorderSide(color: Colors.white.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
  
// frontend/lib/screens/analysis_detail_screen.dart

// frontend/lib/screens/analysis_detail_screen.dart

Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
  final theme = Theme.of(context);
  return ClipRRect(
    borderRadius: BorderRadius.circular(16.0),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // NUEVO: Permite que la columna se ajuste a la altura de su contenido
          mainAxisSize: MainAxisSize.min, 
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            
            // --- 👇 CAMBIO PRINCIPAL AQUÍ: Se eliminó el widget 'Expanded' ---
            // Ahora el texto simplemente ocupa el espacio vertical que necesita.
            Text(
              content, 
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8))
            ),
          ],
        ),
      ),
    ),
  );
}

 Widget _buildRecommendationsTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          children: [
            // El disclaimer se añade aquí
            const DisclaimerWidget(),
            const SizedBox(height: 24),

            if (_recommendationsList.isEmpty)
              Center(child: Text("No hay tratamientos registrados para esta condición.", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)))
            else
              // Se usa un Column con map en lugar de ListView.builder para que funcione dentro de otro SingleChildScrollView
              ..._recommendationsList.map((treatment) => _buildTreatmentCard(treatment)).toList(),
          ],
        ),
      ),
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
              border: Border.all(color: Colors.white.withOpacity(0.1))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatment['nombre_comercial'] ?? 'Sin nombre',
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
                ),
                const Divider(color: Colors.white30, height: 24),
                _buildTreatmentDetailRow(
                  icon: Icons.science_outlined,
                  label: 'Ingrediente Activo:',
                  value: treatment['ingrediente_activo']
                ),
                _buildTreatmentDetailRow(
                  icon: Icons.category_outlined,
                  label: 'Tipo:',
                  value: treatment['tipo_tratamiento']
                ),
                _buildTreatmentDetailRow(
                  icon: Icons.opacity_outlined,
                  label: 'Dosis:',
                  value: treatment['dosis']
                ),
                _buildTreatmentDetailRow(
                  icon: Icons.update_outlined,
                  label: 'Frecuencia:',
                  value: treatment['frecuencia_aplicacion']
                ),
                if (treatment['notas_adicionales'] != null && treatment['notas_adicionales'].isNotEmpty)
                  _buildTreatmentDetailRow(
                    icon: Icons.edit_note_outlined,
                    label: 'Notas:',
                    value: treatment['notas_adicionales'],
                    isNote: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentDetailRow({required IconData icon, required String label, required String? value, bool isNote = false}) {
    final theme = Theme.of(context);
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: isNote ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4),
                children: [
                  TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// frontend/lib/screens/analysis_detail_screen.dart

  // NUEVO: Método para construir el disclaimer en el PDF
 pw.Widget _buildPdfDisclaimer(pw.Font boldFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 25),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                children: [
                  pw.TextSpan(
                    text: 'Descargo de Responsabilidad: ',
                    style: pw.TextStyle(font: boldFont),
                  ),
                  const pw.TextSpan(
                    text: 'Este reporte es una guía generada por IA y no reemplaza el diagnóstico de un profesional. Verifique siempre los resultados y tratamientos con un ingeniero agrónomo certificado.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildActionButton({
  required IconData icon, 
  required Color color, 
  required VoidCallback onPressed, 
  required String tooltip,
  // --- 👇 CAMBIO 3: Añadimos el parámetro 'size' ---
  required double size, 
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(30.0),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Container(
        // Usamos la variable 'size' para alto y ancho
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          // Hacemos el ícono proporcional al tamaño del botón
          icon: Icon(icon, color: Colors.white, size: size * 0.5),
          tooltip: tooltip,
        ),
      ),
    ),
  );
}

// frontend/lib/screens/analysis_detail_screen.dart

// NUEVO: Método para construir los botones de acción y evitar duplicación.
Widget _buildActionButtonsWidget(bool isSmallScreen) {
  final double buttonSize = isSmallScreen ? 44.0 : 40.0; // Botones más grandes en móvil
  
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _buildActionButton(icon: Icons.picture_as_pdf_outlined, color: Colors.green.shade400, tooltip: 'Exportar a PDF', onPressed: _exportToPdf, size: buttonSize),
      const SizedBox(width: 12),
      _buildActionButton(icon: Icons.delete_outline, color: Theme.of(context).brightness == Brightness.dark ? AppColorsDark.danger : AppColorsLight.danger, tooltip: 'Enviar a la papelera', onPressed: _deleteItem, size: buttonSize),
      const SizedBox(width: 12),
      _buildActionButton(icon: Icons.close, color: Colors.grey.shade600, tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), size: buttonSize),
    ],
  );
}

}