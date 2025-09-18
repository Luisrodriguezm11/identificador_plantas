// frontend/lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img; // <-- 1. Importar la librería de imagen

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- FUNCIÓN DE SUBIDA DE IMAGEN TOTALMENTE MODIFICADA ---
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      // 1. Leer los bytes originales de la imagen
      final Uint8List originalBytes = await imageFile.readAsBytes();

      // 2. Decodificar, redimensionar y re-codificar la imagen
      img.Image? originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw Exception("No se pudo decodificar la imagen.");
      }

      // Redimensionar la imagen manteniendo la proporción
      img.Image resizedImage;
      if (originalImage.width > originalImage.height) {
        resizedImage = img.copyResize(originalImage, width: 1024);
      } else {
        resizedImage = img.copyResize(originalImage, height: 1024);
      }
      
      // Convertir la imagen redimensionada a bytes en formato JPG (eficiente)
      final Uint8List resizedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));

      // 3. Subir los bytes redimensionados a Firebase
      final String fileName = '${const Uuid().v4()}_${imageFile.name}';
      final Reference storageRef = _storage.ref().child('analisis/$fileName');

      // Usamos putData para subir los bytes directamente
      await storageRef.putData(resizedBytes);
      
      // 4. Obtener la URL de descarga
      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      print("Error al subir y redimensionar la imagen: $e");
      return null;
    }
  }
}