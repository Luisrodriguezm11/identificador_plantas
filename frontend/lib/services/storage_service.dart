// frontend/lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadOriginalImage(XFile imageFile) async {
    try {
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last.toLowerCase();
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';
      
      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      // --- 👇 CAMBIO #1 AQUÍ 👇 ---
      // Cambiamos 'uploads' por 'analisis'
      final Reference storageRef = _storage.ref().child('analisis/$uniqueFileName');

      if (kIsWeb) {
        final Uint8List bytes = await imageFile.readAsBytes();
        await storageRef.putData(bytes, metadata);
      } else {
        await storageRef.putFile(File(imageFile.path), metadata);
      }

      final String resizedFileName = uniqueFileName.replaceFirst(
        '.$fileExtension',
        '_800x800.$fileExtension',
      );
      
      // --- 👇 CAMBIO #2 AQUÍ 👇 ---
      // Y también lo cambiamos aquí para que busque la imagen redimensionada
      // en la carpeta correcta.
      final resizedRef = _storage.ref().child('analisis/$resizedFileName');

      String downloadUrl;
      int attempts = 0;
      while (true) {
        try {
          downloadUrl = await resizedRef.getDownloadURL();
          break; 
        } catch (e) {
          attempts++;
          if (attempts > 15) { 
            throw Exception('La imagen redimensionada no se encontró después de 15 segundos.');
          }
          await Future.delayed(const Duration(seconds: 1)); 
        }
      }

      return downloadUrl;

    } catch (e) {
      debugPrint("Error al subir imagen y obtener URL redimensionada: $e");
      return null;
    }
  }
}