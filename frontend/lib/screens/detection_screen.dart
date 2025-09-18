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
  // --- AHORA DOS VARIABLES PARA IMÁGENES ---
  XFile? _imageFileFront;
  XFile? _imageFileBack;

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
      _imageFileFront = widget.initialImageFile;
    }
  }

  // --- FUNCIÓN MODIFICADA PARA SELECCIONAR IMAGEN ---
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

  // --- FUNCIÓN MODIFICADA PARA LIMPIAR ---
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

  // --- FUNCIÓN DE ANÁLISIS MODIFICADA ---
  Future<void> _analyzeImages() async {
    if (_imageFileFront == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Subir imagen frontal
      final String? imageUrlFront = await _storageService.uploadImage(_imageFileFront!);
      if (imageUrlFront == null) {
        throw Exception("No se pudo subir la imagen del frente.");
      }

      // Subir imagen del reverso (si existe)
      String? imageUrlBack;
      if (_imageFileBack != null) {
        imageUrlBack = await _storageService.uploadImage(_imageFileBack!);
        if (imageUrlBack == null) {
          throw Exception("No se pudo subir la imagen del reverso.");
        }
      }
      
      // Llamar al servicio con una o dos URLs
      final http.Response response = await _detectionService.analyzeImages(
        imageUrlFront: imageUrlFront,
        imageUrlBack: imageUrlBack,
      );

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
                'url_imagen': imageUrlFront, // Usar la del frente como principal
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
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
      });
    } finally {
      if (mounted) {
         setState(() { _isLoading = false; });
      }
    }
  }

  void _onNavItemTapped(int index) {
    // ... (sin cambios)
  }

  void _logout(BuildContext context) {
    // ... (sin cambios)
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white),
                                        label: const Text("Volver", style: TextStyle(color: Colors.white)),
                                        onPressed: () => Navigator.of(context).pushReplacement(
                                          NoTransitionRoute(page: DashboardScreen(isNavExpanded: _isNavExpanded)),
                                        ),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Analizar Nueva Imagen",
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // --- NUEVA INTERFAZ DE CARGA DUAL ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildImageSlot(isFront: true),
                                      const SizedBox(width: 20),
                                      _buildImageSlot(isFront: false),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Para un diagnóstico más preciso, sube una foto del reverso de la hoja.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontStyle: FontStyle.italic),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  if (_imageFileFront != null)
                                    ElevatedButton.icon(
                                      icon: _isLoading ? Container(width: 24, height: 24, padding: const EdgeInsets.all(2.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3,)) : const Icon(Icons.analytics_outlined),
                                      label: const Text("Analizar Imagen(es)"),
                                      onPressed: _isLoading ? null : _analyzeImages,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        textStyle: const TextStyle(fontSize: 16)
                                      ),
                                    ),
                                  const SizedBox(height: 20),
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

  // --- NUEVO WIDGET PARA CADA ESPACIO DE IMAGEN ---
  Widget _buildImageSlot({required bool isFront}) {
    final XFile? imageFile = isFront ? _imageFileFront : _imageFileBack;
    final String title = isFront ? "Frente (Haz)" : "Reverso (Envés)";

    return Column(
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
                        ? Image.network(imageFile.path, width: 200, height: 200, fit: BoxFit.cover)
                        : Image.file(File(imageFile.path), width: 200, height: 200, fit: BoxFit.cover),
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
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.white70),
                      const SizedBox(height: 8),
                      const Text("Seleccionar imagen", style: TextStyle(color: Colors.white70))
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}