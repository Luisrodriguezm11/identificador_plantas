// services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart'; // Añadiremos este paquete para nombres únicos

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(XFile imageFile) async {
    try {
      // Crea un nombre de archivo único para evitar sobreescribir imágenes
      final String fileName = '${const Uuid().v4()}_${imageFile.name}';
      final Reference storageRef = _storage.ref().child('analisis/$fileName');

      // Sube el archivo
      if (kIsWeb) {
        // Para web, subimos los bytes
        await storageRef.putData(await imageFile.readAsBytes());
      } else {
        // Para móvil, subimos el archivo directamente
        await storageRef.putFile(File(imageFile.path));
      }

      // Obtiene la URL de descarga
      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      print("Error al subir la imagen: $e");
      return null;
    }
  }
}