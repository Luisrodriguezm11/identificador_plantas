// frontend/lib/screens/detection_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart'; // <-- 1. IMPORTAMOS EL NUEVO PAQUETE
import 'package:frontend/helpers/custom_route.dart';
import 'package:frontend/screens/dashboard_screen.dart';
import 'package:frontend/screens/dose_calculation_screen.dart';
import 'package:frontend/screens/history_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/trash_screen.dart';
import 'package:frontend/services/auth_service.dart';
//import 'package:frontend/widgets/animated_bubble_background.dart';
import 'package:frontend/widgets/top_navigation_bar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import 'analysis_detail_screen.dart';
import 'package:lottie/lottie.dart';
import 'admin_dashboard_screen.dart';
import 'package:frontend/config/app_theme.dart';

// --- (El State y la lógica interna no cambian, solo los widgets de la UI) ---
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
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const DashboardScreen()));
        break;
      case 1:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const HistoryScreen()));
        break;
      case 2:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const TrashScreen()));
        break;
      case 3:
        Navigator.pushReplacement(
            context, NoTransitionRoute(page: const DoseCalculationScreen()));
        break;
      case 4:
        if (_isAdmin) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
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

  Future<void> _pickImage(bool isFront) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
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

  Future<void> _analyzeImages() async {
    if (_imageFileFront == null) return;
    setState(() {
      _isLoading = true;
      _cancellationNotifier.value = false;
      _errorMessage = null;
      _loadingMessage = 'Iniciando proceso...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

      setState(() => _loadingMessage = 'Subiendo imágenes...');

      final String? imageUrlFront = await _storageService.uploadOriginalImage(
          _imageFileFront!,
          cancellationNotifier: _cancellationNotifier);
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
      if (imageUrlFront == null) {
        throw Exception("No se pudo subir la imagen del frente.");
      }

      String? imageUrlBack;
      if (_imageFileBack != null) {
        imageUrlBack = await _storageService.uploadOriginalImage(
            _imageFileBack!,
            cancellationNotifier: _cancellationNotifier);
        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
        if (imageUrlBack == null) {
          throw Exception("No se pudo subir la imagen del reverso.");
        }
      }

      setState(
          () => _loadingMessage = 'Analizando con la IA...\nEsto puede tardar un momento.');
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

      final http.Response analysisResponse =
          await _detectionService.analyzeImages(
        imageUrlFront: imageUrlFront,
        imageUrlBack: imageUrlBack,
      );

      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
      if (!mounted) return;

      if (analysisResponse.statusCode == 200) {
        final result = json.decode(analysisResponse.body);

        setState(() => _loadingMessage = 'Guardando resultado...');
        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");

        final http.Response saveResponse =
            await _detectionService.saveAnalysisResult(result);

        if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
        if (!mounted) return;

        setState(() => _isLoading = false);

        if (saveResponse.statusCode != 201) {
          final saveBody = json.decode(saveResponse.body);
          throw Exception(
              "Error al guardar el análisis: ${saveBody['error'] ?? 'Error desconocido'}");
        }

        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: AnalysisDetailScreen(analysis: result),
            );
          },
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final body = json.decode(analysisResponse.body);
        throw Exception(
            "Error del servidor: ${body['error'] ?? analysisResponse.reasonPhrase}");
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


  // --- 👇 TODA LA UI HA SIDO RECONSTRUIDA DESDE AQUÍ 👇 ---

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

          //Container(
            //decoration: AppTheme.backgroundDecoration,
          //),
          //const AnimatedBubbleBackground(),
  
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight + 60),
                      _buildHeaderSection(),
                      const SizedBox(height: 40),
                      _buildUploadArea(),
                      const SizedBox(height: 50),
                      _buildTipsSection(),
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

  // NUEVO WIDGET: Encabezado principal de la pantalla
  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Nuevo Análisis',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Sube una foto del frente y, opcionalmente, del reverso de una hoja de café para obtener un diagnóstico preciso.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  // REDISEÑADO: La zona de carga de archivos ahora es una tarjeta principal
  Widget _buildUploadArea() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildImageSlot(isFront: true)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildImageSlot(isFront: false)),
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

  // REDISEÑADO: El slot para cada imagen ahora usa bordes punteados
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
            imageFile != null
                ? Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: kIsWeb
                            ? Image.network(imageFile.path, height: 250, fit: BoxFit.cover)
                            : Image.file(File(imageFile.path), height: 250, fit: BoxFit.cover),
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
                          height: 250,
                          decoration: BoxDecoration(
                            color: isDragging ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 50, color: theme.iconTheme.color?.withOpacity(0.7)),
                                const SizedBox(height: 16),
                                Text("Arrastra o haz clic", style: theme.textTheme.bodyMedium)
                              ],
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

  // NUEVO WIDGET: Sección de consejos en la parte inferior
  Widget _buildTipsSection() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text("Consejos para un buen análisis", style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildTipCard('assets/animations/sun_animation.json', 'Usa buena iluminación, preferiblemente luz natural.')),
            const SizedBox(width: 20),
            Expanded(child: _buildTipCard('assets/animations/focus_animation.json', 'Asegúrate que la hoja esté bien enfocada y nítida.')),
            const SizedBox(width: 20),
            Expanded(child: _buildTipCard('assets/animations/blurried_animation.json', 'Evita el desenfoque, sujeta firme el dispositivo.')),
            const SizedBox(width: 20),
            Expanded(child: _buildTipCard('assets/animations/background_animation.json', 'Utiliza un fondo sencillo y de color plano.')),
          ],
        )
      ],
    );
  }

  // NUEVO WIDGET: Tarjeta individual para cada consejo
  Widget _buildTipCard(String lottieAsset, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
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
    );
  }
}