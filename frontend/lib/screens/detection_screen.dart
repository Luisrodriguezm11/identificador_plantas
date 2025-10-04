// frontend/lib/screens/detection_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
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
import 'package:frontend/config/app_theme.dart'; // <-- 1. IMPORTAMOS NUESTRO TEMA

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

  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  int _currentPage = 0;

  final List<Map<String, dynamic>> recommendations = [
    {
      'icon': 'assets/animations/sun_animation.json',
      'text': 'Usa buena iluminación, preferiblemente luz natural.'
    },
    {
      'icon': 'assets/animations/focus_animation.json',
      'text': 'Asegúrate que la hoja esté bien enfocada y nítida.'
    },
    {
      'icon': 'assets/animations/blurried_animation.json',
      'text': 'Evita el desenfoque por movimiento, sujeta firme el dispositivo.'
    },
    {
      'icon': 'assets/animations/background_animation.json',
      'text': 'Utiliza fondos sencillos y planos para no confundir a la IA.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _cancellationNotifier = ValueNotifier<bool>(false);
    if (widget.initialImageFile != null) {
      _imageFileFront = widget.initialImageFile;
    }
    _checkAdminStatus();
    _startCarouselTimer();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < recommendations.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _cancellationNotifier.dispose();
    super.dispose();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: TopNavigationBar(
        selectedIndex: -1,
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // FONDO UNIFICADO
          Container(
            decoration: AppTheme.backgroundDecoration,
          ),

          // CONTENIDO PRINCIPAL
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1200, maxHeight: 800),
                child: Column(
                  children: [
                    SizedBox(height: kToolbarHeight),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildRecommendationsCarousel(),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 3,
                            child: _buildUploadArea(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- 👇 ¡AQUÍ ESTÁ EL BOTÓN AÑADIDO! 👇 ---
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

          // CAPA DE CARGA (se mantiene al final para que cubra todo)
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
                          onPressed: () {
                            _cancellationNotifier.value = true;
                          },
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
  Widget _buildRecommendationsCarousel() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          // 3. TARJETAS Y TEXTOS ADAPTATIVOS
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.3) : AppColorsLight.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Consejos para Fotos Óptimas",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: recommendations.length,
                      onPageChanged: (int page) {
                        setState(() => _currentPage = page);
                      },
                      itemBuilder: (context, index) {
                        final item = recommendations[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(item['icon'], width: 120, height: 120),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(
                                item['text'],
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
                        onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(Icons.arrow_forward_ios, color: theme.iconTheme.color),
                        onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  recommendations.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    "Subir Fotos de la Hoja",
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSlot(isFront: true),
                      const SizedBox(width: 24),
                      _buildImageSlot(isFront: false),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              if (_imageFileFront != null)
                // 4. BOTÓN DE ANÁLISIS ADAPTATIVO
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_outlined, size: 20),
                  label: const Text("Analizar Imagen(es)"),
                  onPressed: _isLoading ? null : _analyzeImages,
                  style: AppTheme.accentButtonStyle(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSlot({required bool isFront}) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final XFile? imageFile = isFront ? _imageFileFront : _imageFileBack;
    final String title = isFront ? "Frente (Haz)" : "Reverso (Envés)";
    bool isDragging = false;
    const double imageSize = 240;

    return StatefulBuilder(
      builder: (context, slotSetState) {
        return DropTarget(
          onDragDone: (detail) {
            if (detail.files.isNotEmpty) {
              slotSetState(() {
                if (isFront) _imageFileFront = detail.files.first;
                else _imageFileBack = detail.files.first;
              });
            }
            slotSetState(() => isDragging = false);
          },
          onDragEntered: (detail) => slotSetState(() => isDragging = true),
          onDragExited: (detail) => slotSetState(() => isDragging = false),
          child: Column(
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              imageFile != null
                  ? Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: kIsWeb
                              ? Image.network(imageFile.path, width: imageSize, height: imageSize, fit: BoxFit.cover)
                              : Image.file(File(imageFile.path), width: imageSize, height: imageSize, fit: BoxFit.cover),
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
                  : GestureDetector(
                      onTap: _isLoading ? null : () => _pickImage(isFront),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: imageSize,
                        height: imageSize,
                        decoration: BoxDecoration(
                            color: isDragging ? theme.colorScheme.primary.withOpacity(0.3) : Colors.transparent,
                            border: Border.all(color: isDragging ? theme.colorScheme.primary : (isDark ? Colors.white54 : Colors.black54)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 50, color: theme.iconTheme.color?.withOpacity(0.7)),
                            const SizedBox(height: 8),
                            Text("Arrastra o haz clic", style: TextStyle(color: theme.textTheme.bodyMedium?.color))
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}