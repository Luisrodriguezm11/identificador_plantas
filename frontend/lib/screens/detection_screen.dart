// frontend/lib/screens/detection_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/detection_service.dart'; // <-- Importa el nuevo servicio

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final DetectionService _detectionService = DetectionService();

  // Variables para manejar el estado del análisis
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  Future<void> _pickImageFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _analysisResult = null; // Limpia el resultado anterior al elegir una nueva imagen
        _errorMessage = null;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _detectionService.analyzeImage(_imageFile!);
      if (response.statusCode == 200) {
        setState(() {
          _analysisResult = json.decode(response.body);
        });
      } else {
        setState(() {
          _errorMessage = "Error del servidor: ${response.body}";
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
                // Widget para mostrar la imagen seleccionada
                _imageFile != null
                    ? kIsWeb
                        ? Image.network(_imageFile!.path, width: 300, height: 300, fit: BoxFit.cover)
                        : Image.file(File(_imageFile!.path), width: 300, height: 300, fit: BoxFit.cover)
                    : Container(
                        width: 300, height: 300,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.image, size: 100, color: Colors.grey),
                      ),
                const SizedBox(height: 20),

                // Botones de acción
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Seleccionar de la Galería"),
                  onPressed: _pickImageFromGallery,
                ),
                const SizedBox(height: 10),
                if (_imageFile != null) // Solo muestra el botón si hay una imagen
                  ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text("Analizar Imagen"),
                    onPressed: _isLoading ? null : _analyzeImage, // Deshabilita si está cargando
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                const SizedBox(height: 30),

                // Muestra el resultado o el estado de carga
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
                          Text("Diagnóstico: ${_analysisResult!['prediction']}", style: const TextStyle(fontSize: 16)),
                          Text("Confianza: ${(_analysisResult!['confidence'] * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          const Text("Recomendación:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(_analysisResult!['recommendation']),
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