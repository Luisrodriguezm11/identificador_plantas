// frontend/lib/screens/detection_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart';
import '../services/storage_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final DetectionService _detectionService = DetectionService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _analysisResult = null;
        _errorMessage = null;
      });
    }
  }

  // --- NUEVA FUNCIÓN PARA QUITAR LA IMAGEN SELECCIONADA ---
  void _clearImage() {
    setState(() {
      _imageFile = null;
      _analysisResult = null;
      _errorMessage = null;
    });
  }
  // --- FIN DE LA NUEVA FUNCIÓN ---

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      final String? imageUrl = await _storageService.uploadImage(_imageFile!);
      if (imageUrl != null) {
        final http.Response response = await _detectionService.analyzeImageWithUrl(imageUrl);
        if (response.statusCode == 200) {
          setState(() {
            _analysisResult = json.decode(response.body);
          });
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analizar Nueva Imagen"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- CAMBIO EN EL WIDGET DE IMAGEN ---
                // Ahora usamos un Stack para poner un botón sobre la imagen
                _imageFile != null
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          // La imagen
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: kIsWeb
                                ? Image.network(_imageFile!.path, width: 300, height: 300, fit: BoxFit.cover)
                                : Image.file(File(_imageFile!.path), width: 300, height: 300, fit: BoxFit.cover),
                          ),
                          // El botón para borrar la selección
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: _clearImage,
                                tooltip: 'Quitar imagen',
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container( // El placeholder cuando no hay imagen
                        width: 300, height: 300,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.image, size: 100, color: Colors.grey),
                      ),
                // --- FIN DEL CAMBIO ---
                const SizedBox(height: 20),

                // Botones de acción
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Seleccionar de la Galería"),
                  onPressed: _pickImageFromGallery,
                ),
                const SizedBox(height: 10),
                if (_imageFile != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text("Analizar Imagen"),
                    onPressed: _isLoading ? null : _analyzeImage,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                const SizedBox(height: 30),

                // ... (El resto del código para mostrar resultados no cambia) ...
                if (_isLoading)
                  const CircularProgressIndicator(),

                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),

                if (_analysisResult != null)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Resultados del Análisis:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text("Diagnóstico: ${_analysisResult!['prediction'] ?? 'No disponible'}", style: const TextStyle(fontSize: 16)),
                          Text("Confianza: ${((_analysisResult!['confidence'] ?? 0) * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          const Text("Recomendación:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(_analysisResult!['recommendation'] ?? 'No disponible'),
                        ],
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
}