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
import 'package:frontend/widgets/side_navigation_rail.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';
import 'analysis_detail_screen.dart';
import 'package:lottie/lottie.dart';

class DetectionScreen extends StatefulWidget {
  final bool isNavExpanded;
  final XFile? initialImageFile;

  const DetectionScreen({
    super.key,
    this.isNavExpanded = true,
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
  late bool _isNavExpanded;

  bool _isLoading = false;
  String _loadingMessage = '';
  String? _errorMessage;

  // Para el carrusel de recomendaciones
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
    _isNavExpanded = widget.isNavExpanded;
    if (widget.initialImageFile != null) {
      _imageFileFront = widget.initialImageFile;
    }
    _startCarouselTimer();
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
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 1:
        Navigator.pushReplacement(context, NoTransitionRoute(page: HistoryScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 2:
        Navigator.pushReplacement(context, NoTransitionRoute(page: TrashScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 3:
        Navigator.pushReplacement(context, NoTransitionRoute(page: DoseCalculationScreen(isNavExpanded: _isNavExpanded)));
        break;
      case 4:
        _logout(context);
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
      _errorMessage = null;
      _loadingMessage = 'Iniciando proceso...';
    });

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      setState(() => _loadingMessage = 'Subiendo imágenes...');
      
      final List<Future<String?>> uploadTasks = [];
      uploadTasks.add(_storageService.uploadOriginalImage(_imageFileFront!));
      if (_imageFileBack != null) {
        uploadTasks.add(_storageService.uploadOriginalImage(_imageFileBack!));
      }

      final List<String?> imageUrls = await Future.wait(uploadTasks);
      final String? imageUrlFront = imageUrls[0];
      final String? imageUrlBack = imageUrls.length > 1 ? imageUrls[1] : null;

      if (imageUrlFront == null) throw Exception("No se pudo subir la imagen del frente.");
      if (_imageFileBack != null && imageUrlBack == null) throw Exception("No se pudo subir la imagen del reverso.");
      
      setState(() => _loadingMessage = 'Analizando con la IA...\nEsto puede tardar un momento.');
      
      final http.Response response = await _detectionService.analyzeImages(
        imageUrlFront: imageUrlFront,
        imageUrlBack: imageUrlBack,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        
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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => DashboardScreen(isNavExpanded: _isNavExpanded)),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        final body = json.decode(response.body);
        throw Exception("Error del servidor: ${body['error'] ?? response.reasonPhrase}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Row(
            children: [
              SideNavigationRail(
                isExpanded: _isNavExpanded,
                selectedIndex: 0,
                onToggle: () => setState(() => _isNavExpanded = !_isNavExpanded),
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
child: ConstrainedBox( // <<< AÑADE ESTO
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800), // <<< Y ESTO
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Mantén esto
          children: [
            // Columna Izquierda: Recomendaciones
            Expanded(
              flex: 2,
              child: _buildRecommendationsCarousel(),
            ),
            const SizedBox(width: 32),
            // Columna Derecha: Carga de imágenes
            Expanded(
              flex: 3,
              child: _buildUploadArea(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ],
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
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
  return ClipRRect(
    borderRadius: BorderRadius.circular(24.0),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24.0), // Padding vertical
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
                  // El Carrusel
                  PageView.builder(
                    controller: _pageController,
                    itemCount: recommendations.length,
                    onPageChanged: (int page) {
                       // Actualizamos la página actual para el timer
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = recommendations[index];
                      // --- LÓGICA PARA DECIDIR QUÉ WIDGET MOSTRAR ---
  Widget iconWidget;
  if (item['icon'] is String) {
    // Si es un String, es una ruta a un Lottie
    iconWidget = Lottie.asset(
      item['icon'],
      width: 120, // Ajusta el tamaño como prefieras
      height: 120,
    );
  } else {
    // Si no, es un IconData
    iconWidget = Icon(
      item['icon'],
      color: Colors.white,
      size: 60,
    );
  }
  // ---------------------------------------------
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                                iconWidget, // <-- Usa el widget que acabamos de crear
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
                  // Flecha Izquierda
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
                  // Flecha Derecha
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
                  crossAxisAlignment: CrossAxisAlignment.start, // Alinea al top
                  children: [
                    _buildImageSlot(isFront: true),
                    const SizedBox(width: 24), // Espacio entre slots
                    _buildImageSlot(isFront: false),
                  ],
                ),
                const SizedBox(height: 24),
                 if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center,),
              ],
            ),
            
            // --- BOTÓN CON EFECTO GLASSMORPHISM ---
            if (_imageFileFront != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(30.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.4), // Mismo color pero con opacidad
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
  const double imageSize = 240; // <-- AUMENTAMOS EL TAMAÑO AQUÍ

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