// frontend/lib/screens/detection_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final DetectionService _detectionService = DetectionService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  late bool _isNavExpanded;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isNavExpanded = widget.isNavExpanded;
    if (widget.initialImageFile != null) {
      _imageFile = widget.initialImageFile;
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _errorMessage = null;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? imageUrl = await _storageService.uploadImage(_imageFile!);
      if (imageUrl != null) {
        final http.Response response = await _detectionService.analyzeImageWithUrl(imageUrl);

        setState(() { _isLoading = false; });

        if (response.statusCode == 200) {
          final result = json.decode(response.body);

          await showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return Dialog(
                backgroundColor: Colors.transparent,
                child: AnalysisDetailScreen(analysis: {
                  ...result,
                  'url_imagen': imageUrl,
                  'resultado_prediccion': result['prediction'],
                  'confianza': result['confidence'],
                }),
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
          setState(() {
            _errorMessage = "Error del servidor: ${response.body}";
          });
        }
      } else {
        setState(() {
          _errorMessage = "No se pudo subir la imagen. Inténtalo de nuevo.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error de conexión: $e";
      });
    } finally {
      if (mounted) {
         setState(() { _isLoading = false; });
      }
    }
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
                onToggle: () {
                  setState(() {
                    _isNavExpanded = !_isNavExpanded;
                  });
                },
                onItemSelected: _onNavItemTapped,
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: ClipRRect(
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
                          child: SingleChildScrollView(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // --- ESTRUCTURA MODIFICADA ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white),
                                        label: const Text("Volver", style: TextStyle(color: Colors.white)),
                                        onPressed: () => Navigator.of(context).pushReplacement(
                                          NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                        ),
                                      ),
                                      // Espacio para mantener el título centrado si es necesario
                                      const SizedBox(width: 80), 
                                    ],
                                  ),
                                  Text(
                                    "Analizar Nueva Imagen",
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  _imageFile != null
                                      ? Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12.0),
                                              child: kIsWeb
                                                  ? Image.network(_imageFile!.path, width: 300, height: 300, fit: BoxFit.cover)
                                                  : Image.file(File(_imageFile!.path), width: 300, height: 300, fit: BoxFit.cover),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: CircleAvatar(
                                                backgroundColor: Colors.black54,
                                                child: IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.white),
                                                  onPressed: _isLoading ? null : _clearImage,
                                                  tooltip: 'Quitar imagen',
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(
                                          width: 300, height: 300,
                                          decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.image, size: 100, color: Colors.white70),
                                        ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.photo_library_outlined),
                                    label: const Text("Seleccionar de la Galería"),
                                    onPressed: _isLoading ? null : _pickImageFromGallery,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      textStyle: const TextStyle(fontSize: 16)
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_imageFile != null)
                                    ElevatedButton.icon(
                                      icon: _isLoading ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3,)) : const Icon(Icons.analytics_outlined),
                                      label: const Text("Analizar Imagen"),
                                      onPressed: _isLoading ? null : _analyzeImage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        textStyle: const TextStyle(fontSize: 16)
                                      ),
                                    ),
                                  const SizedBox(height: 30),
                                  if (_errorMessage != null)
                                    Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                                ],
                              ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}