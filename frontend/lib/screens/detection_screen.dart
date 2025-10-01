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
// Importa la nueva barra de navegación
import 'package:frontend/widgets/top_navigation_bar.dart'; 
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import 'analysis_detail_screen.dart';
import 'package:lottie/lottie.dart';
import 'admin_dashboard_screen.dart';


class DetectionScreen extends StatefulWidget {
  // Ya no necesitas 'isNavExpanded'
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
    {'icon': 'assets/animations/sun_animation.json', 'text': 'Usa buena iluminación, preferiblemente luz natural.'},
    {'icon': 'assets/animations/focus_animation.json', 'text': 'Asegúrate que la hoja esté bien enfocada y nítida.'},
    {'icon': 'assets/animations/blurried_animation.json', 'text': 'Evita el desenfoque por movimiento, sujeta firme el dispositivo.'},
    {'icon': 'assets/animations/background_animation.json', 'text': 'Utiliza fondos sencillos y planos para no confundir a la IA.'},
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
    // La navegación ahora es consistente
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
        cancellationNotifier: _cancellationNotifier
      );
      if (_cancellationNotifier.value) throw Exception("Cancelado por el usuario");
      if (imageUrlFront == null) throw Exception("No se pudo subir la imagen del frente.");
      
      String? imageUrlBack;
      if (_imageFileBack != null) {
        imageUrlBack = await _storageService.uploadOriginalImage(
          _imageFileBack!,
          cancellationNotifier: _cancellationNotifier
        );
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
        
        await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: AnalysisDetailScreen(analysis: result),
            );
          },
        );

        if(mounted) {
          // Se devuelve 'true' para que la pantalla anterior sepa que debe refrescar
          Navigator.of(context).pop(true);
        }

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
    return Scaffold(
      // 1. Añadimos el AppBar y lo hacemos transparente
      appBar: TopNavigationBar(
        // El índice aquí puede ser cualquiera que no esté seleccionado, o el de Dashboard
        selectedIndex: -1, 
        isAdmin: _isAdmin,
        onItemSelected: _onNavItemTapped,
        onLogout: () => _logout(context),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fondo de la aplicación
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // 2. Quitamos el Row y el SideNavigationRail
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
                child: Column(
                  children: [
                    // Espacio para que el contenido no quede debajo del AppBar
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
          // El loading overlay no cambia
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
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            _cancellationNotifier.value = true;
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
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
  
  // El resto de tus widgets (_buildRecommendationsCarousel, _buildUploadArea, _buildImageSlot) no necesitan cambios
  // ... (puedes pegarlos aquí tal como estaban)
  Widget _buildRecommendationsCarousel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Consejos para Fotos Óptimas",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = recommendations[index];
                        Widget iconWidget;
                        if (item['icon'] is String) {
                          iconWidget = Lottie.asset(
                            item['icon'],
                            width: 120,
                            height: 120,
                          );
                        } else {
                          iconWidget = Icon(
                            item['icon'],
                            color: Colors.white,
                            size: 60,
                          );
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            iconWidget,
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Text(
                                item['text'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          );
                        },
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
                      (index) => Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  "¡Próximamente con animaciones!",
                  style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    "Subir Fotos de la Hoja",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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
                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center,),
                ],
              ),

              if (_imageFileFront != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(30.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(30.0),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _analyzeImages,
                          borderRadius: BorderRadius.circular(30.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.analytics_outlined, size: 20, color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  "Analizar Imagen(es)",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildImageSlot({required bool isFront}) {
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
                if(isFront) _imageFileFront = detail.files.first;
                else _imageFileBack = detail.files.first;
              });
            }
            slotSetState(() => isDragging = false);
          },
          onDragEntered: (detail) => slotSetState(() => isDragging = true),
          onDragExited: (detail) => slotSetState(() => isDragging = false),
          child: Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      color: isDragging ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                      border: Border.all(color: isDragging ? Colors.blueAccent : Colors.white54),
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.white70),
                      SizedBox(height: 8),
                      Text("Arrastra o haz clic", style: TextStyle(color: Colors.white70))
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