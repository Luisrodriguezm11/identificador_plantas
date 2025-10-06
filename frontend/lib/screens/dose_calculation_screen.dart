// frontend/lib/screens/dose_calculation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/treatment_service.dart';
import 'dart:ui';
import 'package:frontend/config/app_theme.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:frontend/services/detection_service.dart';

class DoseCalculationScreen extends StatefulWidget {
  const DoseCalculationScreen({super.key});

  @override
  State<DoseCalculationScreen> createState() => _DoseCalculationScreenState();
}

class _DoseCalculationScreenState extends State<DoseCalculationScreen> {
  final TreatmentService _treatmentService = TreatmentService();
  final AuthService _authService = AuthService();
  final DetectionService _detectionService = DetectionService();

  bool _isAdmin = false;
  List<Enfermedad> _enfermedades = [];
  Enfermedad? _selectedEnfermedad;
  
  bool _isLoadingEnfermedades = true;
  bool _isLoadingDetails = false;
  String? _errorMessage;

  Map<String, dynamic> _pestDetails = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _checkAdminStatus();
    await _fetchEnfermedades();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _fetchEnfermedades() async {
    setState(() => _isLoadingEnfermedades = true);
    try {
      final enfermedades = await _treatmentService.getEnfermedades();
      if (mounted) {
        setState(() {
          _enfermedades = enfermedades;
          _isLoadingEnfermedades = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar guía. Revisa tu conexión.';
          _isLoadingEnfermedades = false;
        });
      }
    }
  }

  Future<void> _fetchDetailsForPest(Enfermedad enfermedad) async {
    if (_selectedEnfermedad?.id == enfermedad.id) return;

    setState(() {
      _selectedEnfermedad = enfermedad;
      _isLoadingDetails = true;
      _pestDetails = {};
      _errorMessage = null;
    });

    try {
      final details = await _detectionService.getDiseaseDetails(enfermedad.roboflowClass);
      if (mounted) {
        setState(() {
          _pestDetails = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los detalles de la enfermedad.';
          _isLoadingDetails = false;
        });
      }
    }
  }

// frontend/lib/screens/dose_calculation_screen.dart

Future<void> _exportToPdf() async {
  if (_selectedEnfermedad == null || _pestDetails.isEmpty) {
    // Muestra un mensaje si no hay nada seleccionado para exportar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Por favor, selecciona una enfermedad para exportar su ficha.'),
      backgroundColor: Colors.orange,
    ));
    return;
  }

  final pdf = pw.Document();

  // --- Carga de recursos (imagen y fuentes) ---
  final imageUrl = _selectedEnfermedad!.imagenUrl;
  pw.MemoryImage? image;
  if (imageUrl != null && imageUrl.isNotEmpty) {
    try {
      final imageResponse = await http.get(Uri.parse(imageUrl));
      image = pw.MemoryImage(imageResponse.bodyBytes);
    } catch (e) {
      print("Error al descargar la imagen para el PDF: $e");
    }
  }

  final font = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Regular.ttf"));
  final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Bold.ttf"));

  final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

  // --- Formateo de datos ---
  final enfermedad = _selectedEnfermedad!;
  final info = _pestDetails['info'] ?? {};
  final recommendations = _pestDetails['recommendations'] as List? ?? [];

  final tipo = info['tipo'] as String? ?? 'No especificado';
  final prevencion = info['prevencion'] as String? ?? 'No hay datos de prevención.';
  final riesgo = info['riesgo'] as String? ?? 'No hay datos de riesgo.';
  final descripcion = info['descripcion'] as String? ?? 'No hay descripción disponible.';

  // --- Construcción del documento PDF ---
  pdf.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Header(
        level: 0,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Ficha Técnica de Enfermedad', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]
        )
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('Generado por Identificador de Plagas - Página ${context.pageNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]
      ),
      build: (context) => [
        // --- Sección Principal ---
        pw.Header(
          level: 1,
          text: enfermedad.nombreComun,
          textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 28, color: PdfColors.black),
        ),
        pw.Text('Clase Roboflow: ${enfermedad.roboflowClass}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
        pw.Divider(height: 25),

        // --- Sección de detalles e imagen ---
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    pw.Container(
                      height: 200,
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8)
                      ),
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Image(image, fit: pw.BoxFit.contain)
                    ),
                  if (image == null)
                    pw.Container(
                       height: 200,
                       width: double.infinity,
                       alignment: pw.Alignment.center,
                       child: pw.Text("Imagen no disponible", style: const pw.TextStyle(color: PdfColors.grey))
                    ),
                  pw.SizedBox(height: 20),
                  pw.Header(level: 3, text: 'Descripción General'),
                  pw.Paragraph(text: descripcion, style: const pw.TextStyle(fontSize: 11, lineSpacing: 4))
                ]
              )
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(level: 3, text: 'Información Clave'),
                  pw.SizedBox(height: 10),
                  _buildPdfInfoCard(title: 'Tipo de Afección', content: tipo, boldFont: boldFont),
                  _buildPdfInfoCard(title: 'Prevención', content: prevencion, boldFont: boldFont),
                  _buildPdfInfoCard(title: 'Época de Mayor Riesgo', content: riesgo, boldFont: boldFont),
                ]
              )
            ),
          ]
        ),
        pw.SizedBox(height: 20),

        // --- Sección de Tratamientos ---
        if (recommendations.isNotEmpty) ...[
          pw.Header(level: 2, text: 'Tratamientos Recomendados'),
          ...recommendations.map((treatment) {
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
                ]
              )
            );
          }).toList(),
        ]
      ],
    ),
  );

  // --- Compartir el PDF generado ---
  await Printing.sharePdf(bytes: await pdf.save(), filename: 'ficha-${enfermedad.nombreComun.replaceAll(' ', '_')}.pdf');
}


// --- Widgets de ayuda para el PDF ---
pw.Widget _buildPdfInfoCard({required String title, required String content, required pw.Font boldFont}) {
  if (content.isEmpty) return pw.SizedBox.shrink();
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(content, style: const pw.TextStyle(fontSize: 10)),
      ]
    )
  );
}

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: const TrashScreen()));
        break;
      case 3: break;
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

// frontend/lib/screens/dose_calculation_screen.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 3,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: kToolbarHeight + 40),
          _buildHeaderSection(),
          // --- 👇 ¡CAMBIO AQUÍ! 👇 ---
          const SizedBox(height: 5), // Espacio reducido, antes era 24
          Center(child: _buildDiseasesCarousel()),
          // El SizedBox que estaba aquí se ha movido dentro de _buildContentSection
          Expanded(
            child: _buildContentSection(),
          ),
        ],
      ),
      floatingActionButton: _selectedEnfermedad != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _exportToPdf,
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
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Exportar Ficha",
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

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Centra los hijos
        children: [
          Text(
            'Guía de Plagas y Enfermedades',
            textAlign: TextAlign.center, // Asegura el centrado del texto
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 52), // Estilo grande y ancho
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Selecciona una afección para ver sus detalles y tratamientos.',
              textAlign: TextAlign.center, // Centra el subtítulo
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
            ),  
            ),
        ],
      ),
    );
  }

// frontend/lib/screens/dose_calculation_screen.dart

Widget _buildDiseasesCarousel() {
    if (_isLoadingEnfermedades) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _enfermedades.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    // --- 👇 ¡LÓGICA ACTUALIZADA PARA MOSTRAR TARJETAS ESTÁTICAS! 👇 ---
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Wrap(
        // Centra las tarjetas en el espacio disponible
        alignment: WrapAlignment.center,
        // Espacio horizontal entre tarjetas
        spacing: 20,
        // Espacio vertical si las tarjetas pasan a la siguiente línea
        runSpacing: 20,
        children: _enfermedades.map((enfermedad) {
          final isSelected = _selectedEnfermedad?.id == enfermedad.id;
          return _buildDiseaseCard(enfermedad, isSelected);
        }).toList(),
      ),
    );
  }

// frontend/lib/screens/dose_calculation_screen.dart

// frontend/lib/screens/dose_calculation_screen.dart

Widget _buildDiseaseCard(Enfermedad enfermedad, bool isSelected) {
    final theme = Theme.of(context);
    
    // --- 👇 ¡CORRECCIÓN DEFINITIVA AQUÍ! 👇 ---
    // Damos un tamaño fijo (ancho y alto) a la tarjeta para que el layout no falle.
    return SizedBox(
      width: 280,
      height: 180, // <- La altura que faltaba
      child: GestureDetector(
        onTap: () => _fetchDetailsForPest(enfermedad),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.white.withOpacity(0.2),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  enfermedad.imagenUrl ?? 'https://via.placeholder.com/280x180.png?text=Sin+Imagen',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.85)],
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      enfermedad.nombreComun,
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


// frontend/lib/screens/dose_calculation_screen.dart

// frontend/lib/screens/dose_calculation_screen.dart

Widget _buildContentSection() {
    if (_selectedEnfermedad == null) {
      return _buildEmptyState();
    }
    if (_isLoadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _pestDetails.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final info = _pestDetails['info'] ?? {};
    final recommendations = _pestDetails['recommendations'] as List? ?? [];
    
    final tipo = info['tipo'] as String? ?? 'No especificado';
    final prevencion = info['prevencion'] as String? ?? 'No hay datos de prevención.';
    final riesgo = info['riesgo'] as String? ?? 'No hay datos de riesgo.';

    return SingleChildScrollView(
      // Eliminamos el padding superior para controlar el espacio desde afuera
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 48), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Añadimos el SizedBox aquí para un control más preciso
          const SizedBox(height: 0),
          GridView.count(
            crossAxisCount: 3, 
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4.0,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: [
              _buildInfoCard(icon: Icons.bug_report_outlined, title: "Tipo de Afección", content: tipo),
              _buildInfoCard(icon: Icons.shield_outlined, title: "Prevención", content: prevencion),
              _buildInfoCard(icon: Icons.warning_amber_rounded, title: "Época de Mayor Riesgo", content: riesgo),
            ],
          ),
          const SizedBox(height: 24),
Center(
  child: Text(
    'Tratamientos Recomendados',
    style: Theme.of(context).textTheme.headlineMedium
  ),
),
// --- 👇 ¡CAMBIO AQUÍ! 👇 ---
// Se eliminó el SizedBox(height: 0)
if (recommendations.isNotEmpty)
  Transform.translate(            // <--- WIDGET AÑADIDO
    offset: const Offset(0, -20),  // <-- Mueve el GridView 10 píxeles hacia arriba
    child: GridView.builder(       // <-- El GridView ahora es el hijo del Transform
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 500,
        childAspectRatio: 16 / 11,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        return _buildTreatmentCard(recommendations[index]);
      },
            )
  )
          else
            const Text("No hay tratamientos registrados para esta condición."),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 80, color: theme.iconTheme.color?.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text('Explora la Guía', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              'Selecciona una de las tarjetas de la parte superior para ver todos sus detalles y los tratamientos recomendados.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 4. ¡CORRECCIÓN! Usamos el diseño de tarjeta con BackdropFilter
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
         // --- 👇 ¡CAMBIO AQUÍ! 👇 ---
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), // Menos padding vertical
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: theme.textTheme.bodyMedium?.color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView( // Para evitar overflow si el texto es muy largo
                  child: Text(
                    content,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 5. ¡TARJETA COMPLETAMENTE REDISEÑADA!
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                treatment['nombre_comercial'] ?? 'Sin nombre',
                // 6. ¡CORRECCIÓN! Usamos el color de texto del tema
                style: theme.textTheme.headlineSmall
              ),
              Divider(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                height: 24
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
            ],
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
          Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                // 6. ¡CORRECCIÓN! El estilo base viene del tema
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                children: [
                  TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}