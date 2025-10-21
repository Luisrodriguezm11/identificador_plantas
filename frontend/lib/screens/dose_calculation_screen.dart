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

/// Pantalla que funciona como una guía de consulta sobre plagas y enfermedades.
/// Permite al usuario seleccionar una afección y ver sus detalles, tratamientos
/// recomendados y exportar la información a una ficha en PDF.
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

  /// Carga los datos iniciales de la pantalla.
  Future<void> _loadInitialData() async {
    await _checkAdminStatus();
    await _fetchEnfermedades();
  }

  /// Verifica si el usuario actual es administrador.
  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  /// Obtiene la lista de todas las enfermedades disponibles.
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

  /// Obtiene los detalles específicos (info y tratamientos) de una enfermedad seleccionada.
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

  /// Genera un documento PDF con la ficha técnica de la enfermedad seleccionada y lo comparte.
  Future<void> _exportToPdf() async {
    if (_selectedEnfermedad == null || _pestDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor, selecciona una enfermedad para exportar su ficha.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final pdf = pw.Document();
    
    // Carga de recursos (imagen y fuentes)
    final imageUrl = _selectedEnfermedad!.imagenUrl;
    pw.MemoryImage? image;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final imageResponse = await http.get(Uri.parse(imageUrl));
        image = pw.MemoryImage(imageResponse.bodyBytes);
      } catch (e) {
        // Ignora el error si la imagen no se puede cargar, el PDF se generará sin ella.
      }
    }

    final font = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Regular.ttf"));
    final boldFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Lato-Bold.ttf"));
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    // Formateo de datos
    final enfermedad = _selectedEnfermedad!;
    final info = _pestDetails['info'] ?? {};
    final recommendations = _pestDetails['recommendations'] as List? ?? [];
    final tipo = info['tipo'] as String? ?? 'No especificado';
    final prevencion = info['prevencion'] as String? ?? 'No hay datos de prevención.';
    final riesgo = info['riesgo'] as String? ?? 'No hay datos de riesgo.';
    final descripcion = info['descripcion'] as String? ?? 'No hay descripción disponible.';

    // Construcción del documento PDF
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Header(
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
          pw.Header(
            level: 1,
            text: enfermedad.nombreComun,
            textStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 28, color: PdfColors.black),
          ),
          pw.Text('Clase Roboflow: ${enfermedad.roboflowClass}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
          pw.Divider(height: 25),
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
                      _buildPdfDisclaimer(boldFont),
                  ]
                )
              );
            }).toList(),
          ]
        ],
      ),
    );

    // Compartir el PDF generado
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'ficha-${enfermedad.nombreComun.replaceAll(' ', '_')}.pdf');
  }

  /// Widget auxiliar para construir una tarjeta de información dentro del PDF.
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

  /// Cierra la sesión del usuario y lo redirige a la pantalla de login.
  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _authService.deleteToken();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

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
      body: Stack( // <-- 1. Se añade el Stack
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: kToolbarHeight + 40),
                _buildHeaderSection(),
                const SizedBox(height: 20),
                Center(child: _buildDiseasesCarousel()),
                _buildContentSection(),
              ],
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

  /// Construye el encabezado principal de la pantalla.
  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    // RESPONSIVE: Utiliza LayoutBuilder para adaptar el tamaño del texto.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double titleSize = constraints.maxWidth > 800 ? 52 : (constraints.maxWidth > 500 ? 42 : 34);
        final double subtitleSize = constraints.maxWidth > 800 ? 18 : 16;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Guía de Plagas y Enfermedades',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: titleSize),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Selecciona una afección para ver sus detalles y tratamientos.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: subtitleSize),
                ),  
              ),
            ],
          ),
        );
      }
    );
  }

/// Construye el carrusel de tarjetas de enfermedades.
  /// En pantallas pequeñas (< 600px) muestra una lista horizontal deslizable.
  /// En pantallas grandes muestra una cuadrícula adaptable (Wrap).
  Widget _buildDiseasesCarousel() {
    if (_isLoadingEnfermedades) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _enfermedades.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    // Usamos LayoutBuilder para decidir qué diseño mostrar según el ancho.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Definimos un punto de quiebre: 600px.
        // Por debajo de este ancho, usaremos la lista horizontal.
        bool useHorizontalList = constraints.maxWidth < 600;

        if (useHorizontalList) {
          // --- DISEÑO PARA PANTALLAS PEQUEÑAS: LISTA HORIZONTAL ---
          return SizedBox(
            height: 180, // Es crucial darle una altura fija al ListView horizontal
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0), // Un padding lateral más ajustado para móviles
              itemCount: _enfermedades.length,
              itemBuilder: (context, index) {
                final enfermedad = _enfermedades[index];
                final isSelected = _selectedEnfermedad?.id == enfermedad.id;
                // Agregamos un Padding para dar espacio entre las tarjetas
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildDiseaseCard(enfermedad, isSelected),
                );
              },
            ),
          );
        } else {
          // --- DISEÑO PARA PANTALLAS GRANDES: WRAP (el que ya tenías) ---
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: _enfermedades.map((enfermedad) {
                final isSelected = _selectedEnfermedad?.id == enfermedad.id;
                return _buildDiseaseCard(enfermedad, isSelected);
              }).toList(),
            ),
          );
        }
      },
    );
  }

  /// Construye la tarjeta individual para cada enfermedad seleccionable.
  Widget _buildDiseaseCard(Enfermedad enfermedad, bool isSelected) {
    final theme = Theme.of(context);
    // El tamaño fijo funciona bien con Wrap, asegurando consistencia.
    return SizedBox(
      width: 280,
      height: 180,
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
                ? [ BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 12, spreadRadius: 2) ]
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

/// Construye la sección de contenido que muestra los detalles de una enfermedad seleccionada.
  Widget _buildContentSection() {
    if (_selectedEnfermedad == null) return _buildEmptyState();
    if (_isLoadingDetails) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null && _pestDetails.isEmpty) return Center(child: Text(_errorMessage!));

    final info = _pestDetails['info'] ?? {};
    final recommendations = _pestDetails['recommendations'] as List? ?? [];
    
    final tipo = info['tipo'] as String? ?? 'No especificado';
    final prevencion = info['prevencion'] as String? ?? 'No hay datos de prevención.';
    final riesgo = info['riesgo'] as String? ?? 'No hay datos de riesgo.';

    // --- CAMBIO: Se quita SingleChildScrollView y se reemplaza por Padding ---
    // Esto evita anidar dos widgets de scroll y soluciona el problema.
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 20, 48, 80), // Aumentado el padding inferior para el FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 3;
              if (constraints.maxWidth < 1100) crossAxisCount = 2;
              if (constraints.maxWidth < 700) crossAxisCount = 1;

              double aspectRatio = crossAxisCount == 1 ? 2.5 : 4.0;

              return GridView.count(
                crossAxisCount: crossAxisCount, 
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildInfoCard(icon: Icons.bug_report_outlined, title: "Tipo de Afección", content: tipo),
                  _buildInfoCard(icon: Icons.shield_outlined, title: "Prevención", content: prevencion),
                  _buildInfoCard(icon: Icons.warning_amber_rounded, title: "Época de Mayor Riesgo", content: riesgo),
                ],
              );
            }
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Tratamientos Recomendados',
              style: Theme.of(context).textTheme.headlineMedium
            ),
          ),
          if (recommendations.isNotEmpty)
            Transform.translate(
              offset: const Offset(0, -10),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 20),
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
            const Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Center(child: Text("No hay tratamientos registrados para esta condición.")),
            ),
        ],
      ),
    );
  }
  
  /// Construye el estado inicial de la sección de contenido cuando no hay enfermedad seleccionada.
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

  /// Construye una tarjeta para mostrar información clave (Tipo, Prevención, Riesgo).
  Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                child: SingleChildScrollView(
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
  
  /// Construye una tarjeta para mostrar un tratamiento recomendado.
  Widget _buildTreatmentCard(Map<String, dynamic> treatment) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                      _buildTreatmentDetailRow(icon: Icons.science_outlined, label: 'Ingrediente Activo:', value: treatment['ingrediente_activo']),
                      _buildTreatmentDetailRow(icon: Icons.category_outlined, label: 'Tipo:', value: treatment['tipo_tratamiento']),
                      _buildTreatmentDetailRow(icon: Icons.opacity_outlined, label: 'Dosis:', value: treatment['dosis']),
                      _buildTreatmentDetailRow(icon: Icons.update_outlined, label: 'Frecuencia:', value: treatment['frecuencia_aplicacion']),
                      if (treatment['notas_adicionales'] != null && treatment['notas_adicionales'].isNotEmpty)
                        _buildTreatmentDetailRow(icon: Icons.edit_note_outlined, label: 'Notas:', value: treatment['notas_adicionales'], isNote: true),
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

  /// Widget auxiliar para construir una fila de detalle dentro de la tarjeta de tratamiento.
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