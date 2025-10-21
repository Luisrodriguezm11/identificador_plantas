// frontend/lib/screens/detection_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import 'analysis_detail_screen.dart';
import 'package:lottie/lottie.dart';
import 'admin_dashboard_screen.dart';
import 'package:frontend/config/app_theme.dart';

/// Pantalla principal para iniciar un nuevo análisis de imágenes.
/// Permite al usuario subir una imagen del frente y reverso de una hoja para su diagnóstico.
class DetectionScreen extends StatefulWidget {
  final XFile? initialImageFile;

  const DetectionScreen({
    super.key,
    this.initialImageFile,
  });

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  // Lógica de estado y servicios (sin cambios)
  XFile? _imageFileFront;
  XFile? _imageFileBack;
  final ImagePicker _picker = ImagePicker();
  final DetectionService _detectionService = DetectionService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  bool _isAdmin = false;
  bool _isLoading = false;
  String _loadingMessage = '';
  String? _errorMessage;
  late ValueNotifier<bool> _cancellationNotifier;

  @override
  void initState() {
    super.initState();
    _cancellationNotifier = ValueNotifier<bool>(false);
    if (widget.initialImageFile != null) {
      _imageFileFront = widget.initialImageFile;
    }
    _checkAdminStatus();
  }

   @override
  void dispose() {
    _cancellationNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
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

  /// Permite al usuario seleccionar una imagen de la galería.
  Future<void> _pickImage(bool isFront) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isFront) {
          _imageFileFront = pickedFile;
        } else {
          _imageFileBack = pickedFile;
        }
        _errorMessage = null;
      });
    }
  }

  /// Limpia la imagen seleccionada del slot correspondiente.
  void _clearImage(bool isFront) {
    setState(() {
      if (isFront) {
        _imageFileFront = null;
      } else {
        _imageFileBack = null;
      }
      _errorMessage = null;
    });
  }

  /// Orquesta el proceso completo de análisis: subida, diagnóstico y guardado.
  Future<void> _analyzeImages() async {
    if (_imageFileFront == null) return;
    setState(() {
      _isLoading = true;
      _cancellationNotifier.value = false;
      _errorMessage = null;
      _loadingMessage = 'Iniciando proceso...';
    });

    try {
      // Notificador para permitir la cancelación del proceso en cualquier punto.
      await Future.delayed(const Duration(milliseconds: 50));
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

      setState(() => _loadingMessage = 'Subiendo imágenes...');

      final String? imageUrlFront = await _storageService.uploadOriginalImage(_imageFileFront!, cancellationNotifier: _cancellationNotifier);
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
      if (imageUrlFront == null) throw Exception("No se pudo subir la imagen del frente.");

      String? imageUrlBack;
      if (_imageFileBack != null) {
        imageUrlBack = await _storageService.uploadOriginalImage(_imageFileBack!, cancellationNotifier: _cancellationNotifier);
        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
        if (imageUrlBack == null) throw Exception("No se pudo subir la imagen del reverso.");
      }

      setState(() => _loadingMessage = 'Analizando con la IA...\nEsto puede tardar un momento.');
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

      final http.Response analysisResponse = await _detectionService.analyzeImages(
        imageUrlFront: imageUrlFront,
        imageUrlBack: imageUrlBack,
      );

      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
      if (!mounted) return;

      if (analysisResponse.statusCode == 200) {
        final result = json.decode(analysisResponse.body);

// frontend/lib/screens/detection_screen.dart

        setState(() => _loadingMessage = 'Guardando resultado...');
        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

        final http.Response saveResponse = await _detectionService.saveAnalysisResult(result);

        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
        if (!mounted) return;

        setState(() => _isLoading = false);

        if (saveResponse.statusCode != 201) {
          final saveBody = json.decode(saveResponse.body);
          throw Exception("Error al guardar el análisis: ${saveBody['error'] ?? 'Error desconocido'}");
        }

        // --- 👇 ¡AQUÍ ESTÁ LA CORRECCIÓN! 👇 ---
        // 1. Decodificamos la respuesta para obtener el análisis con su ID de la base de datos.
        final savedAnalysis = json.decode(utf8.decode(saveResponse.bodyBytes));

        // 2. Mostramos el diálogo usando el nuevo objeto 'savedAnalysis'.
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: AnalysisDetailScreen(analysis: savedAnalysis), // Usamos el objeto con el ID
            );
          },
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
        // --- 👆 FIN DE LA CORRECCIÓN 👆 ---
        
      } else {
        final body = json.decode(analysisResponse.body);
        throw Exception("Error del servidor: ${body['error'] ?? analysisResponse.reasonPhrase}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString() != "Exception: Cancelado por el usuario") {
            _errorMessage = e.toString();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TopNavigationBar(
        selectedIndex: 5,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          //const AnimatedBubbleBackground(),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      _buildHeaderSection(),
                      const SizedBox(height: 40),
                      _buildUploadArea(),
                      const SizedBox(height: 50),
                      _buildTipsSection(),
                      // CAMBIO: Se elimina el disclaimer de aquí porque ahora está dentro de _buildUploadArea
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
                    tooltip: 'Volver',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.iconTheme.color),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(color: AppColorsDark.textPrimary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _cancellationNotifier.value = true,
                          style: AppTheme.dangerButtonStyle(context),
                          child: const Text('Cancelar Análisis'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Construye el encabezado principal de la pantalla.
  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    // RESPONSIVE: Utiliza LayoutBuilder para adaptar el tamaño del texto.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double titleSize = constraints.maxWidth > 600 ? 52 : 40;
        final double subtitleSize = constraints.maxWidth > 600 ? 18 : 16;
        return Column(
          children: [
            Text(
              'Nuevo Análisis',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge?.copyWith(fontSize: titleSize),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Sube una foto del frente y, opcionalmente, del reverso de una hoja de café para obtener un diagnóstico preciso.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: subtitleSize),
              ),
            ),
          ],
        );
      }
    );
  }

  /// Construye el área principal para la carga de imágenes.
Widget _buildUploadArea() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Se ajusta el punto de quiebre para 3 tarjetas
        bool useMobileLayout = constraints.maxWidth < 950;
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.15) : AppColorsLight.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  useMobileLayout
                    ? Column(
                        children: [
                          _buildImageSlot(isFront: true),
                          const SizedBox(height: 24),
                          _buildImageSlot(isFront: false),
                          const SizedBox(height: 24),
                          _buildDisclaimerCard(), // En móvil, se apila debajo
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildImageSlot(isFront: true)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildImageSlot(isFront: false)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDisclaimerCard()), // En escritorio, es la tercera columna
                        ],
                      ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_imageFileFront != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.analytics_outlined, size: 20),
                        label: const Text("Analizar Imagen(es)"),
                        onPressed: _isLoading ? null : _analyzeImages,
                        style: AppTheme.accentButtonStyle(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

// frontend/lib/screens/detection_screen.dart

// CAMBIO: Se añade este nuevo método para crear la tarjeta de descargo de responsabilidad.
  Widget _buildDisclaimerCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Text("Importante", style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                  color: (isDark ? Colors.orange.shade900 : Colors.amber.shade200).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                      color: (isDark ? Colors.orange.shade800 : Colors.amber.shade400).withOpacity(0.4),
                  ),
              ),
              child: Center(
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(
                                Icons.warning_amber_rounded,
                                color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                                size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                                'Los resultados son una guía y no garantizan precisión. Consulte siempre a un agrónomo profesional.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                            ),
                        ],
                    ),
                ),
              ),
          ),
        ),
      ],
    );
  }

/// Construye un slot individual para subir o mostrar una imagen.
  Widget _buildImageSlot({required bool isFront}) {
    final theme = Theme.of(context);
    final imageFile = isFront ? _imageFileFront : _imageFileBack;
    final title = isFront ? "Frente (Obligatorio)" : "Reverso (Opcional)";
    bool isDragging = false;

    return StatefulBuilder(
      builder: (context, slotSetState) {
        return Column(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // RESPONSIVE: AspectRatio mantiene la proporción del slot.
            AspectRatio(
              // --- CAMBIO AQUÍ ---
              // Cambiamos la proporción de 1 (cuadrado) a 4/3 (más ancho que alto).
              // Esto hace que la tarjeta sea más pequeña verticalmente.
              // Puedes experimentar con otros valores como 3/2 si la quieres aún más baja.
              aspectRatio: 4 / 3,
              child: imageFile != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: kIsWeb
                                ? Image.network(imageFile.path, fit: BoxFit.cover)
                                : Image.file(File(imageFile.path), fit: BoxFit.cover),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.close, color: Colors.white, size: 14),
                              onPressed: _isLoading ? null : () => _clearImage(isFront),
                              tooltip: 'Quitar imagen',
                            ),
                          ),
                        ),
                      ],
                    )
                  : DropTarget(
                      onDragDone: (detail) {
                        if (detail.files.isNotEmpty) {
                          setState(() {
                            if (isFront) _imageFileFront = detail.files.first;
                            else _imageFileBack = detail.files.first;
                          });
                        }
                        slotSetState(() => isDragging = false);
                      },
                      onDragEntered: (detail) => slotSetState(() => isDragging = true),
                      onDragExited: (detail) => slotSetState(() => isDragging = false),
                      child: GestureDetector(
                        onTap: _isLoading ? null : () => _pickImage(isFront),
                        child: DottedBorder(
                          color: isDragging ? theme.colorScheme.primary : (theme.textTheme.bodyMedium?.color?.withOpacity(0.5) ?? Colors.grey),
                          strokeWidth: 2,
                          radius: const Radius.circular(12),
                          dashPattern: const [8, 6],
                          borderType: BorderType.RRect,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDragging ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 40, color: theme.iconTheme.color?.withOpacity(0.7)), // Ícono un poco más pequeño
                                  const SizedBox(height: 12),
                                  Text("Arrastra o haz clic", style: theme.textTheme.bodyMedium)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Construye la sección inferior con consejos para el análisis.
// frontend/lib/screens/detection_screen.dart

  /// Construye la sección inferior con consejos para el análisis.
Widget _buildTipsSection() {
    final theme = Theme.of(context);
    
    // Contenido de la sección de consejos, para no repetir código.
    final tipsContent = Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _buildTipCard('assets/animations/sun_animation.json', 'Usa buena iluminación preferible luz natural.'),
        _buildTipCard('assets/animations/focus_animation.json', 'Asegúrate que la hoja esté bien enfocada y nítida.'),
        _buildTipCard('assets/animations/blurried_animation.json', 'Evita el desenfoque, sujeta firme el dispositivo.'),
        _buildTipCard('assets/animations/background_animation.json', 'Utiliza un fondo sencillo y de color plano.'),
      ],
    );

    return Column(
      children: [
        Text("Consejos para un buen análisis", style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        
        // --- 👇 ¡AQUÍ ESTÁ LA MODIFICACIÓN PRINCIPAL! 👇 ---
        LayoutBuilder(
          builder: (context, constraints) {
            // Si el ancho de la pantalla es mayor a 850px, muestra los 4 consejos en línea.
            if (constraints.maxWidth > 850) {
              return tipsContent; // El Wrap se expandirá horizontalmente.
            } else {
              // Si es menor, limita el ancho para forzar la cuadrícula de 2x2.
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: tipsContent,
              );
            }
          }
        ),
      ],
    );
  }

  /// Construye una tarjeta individual para un consejo.
  Widget _buildTipCard(String lottieAsset, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // RESPONSIVE: Se le da un tamaño y ancho máximo a cada tarjeta para que funcione bien con Wrap.
    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            height: 180,
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.3) : AppColorsLight.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(lottieAsset, width: 60, height: 60),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}