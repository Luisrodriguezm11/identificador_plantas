// frontend/lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- 👇 FUNCIÓN AÑADIDA 👇 ---
  Future<String?> uploadProfileImage(XFile imageFile) async {
    try {
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last.toLowerCase();
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';

      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      final Reference storageRef = _storage.ref().child('profile_pictures/$uniqueFileName');

      if (kIsWeb) {
        final Uint8List bytes = await imageFile.readAsBytes();
        await storageRef.putData(bytes, metadata);
      } else {
        await storageRef.putFile(File(imageFile.path), metadata);
      }

      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      debugPrint("Error en el servicio de storage al subir foto de perfil: $e");
      return null;
    }
  }

  // --- El resto de tu clase StorageService ---
  Future<String?> uploadOriginalImage(XFile imageFile, {ValueNotifier<bool>? cancellationNotifier}) async {
    try {
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last.toLowerCase();
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';
      
      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      final Reference storageRef = _storage.ref().child('analisis/$uniqueFileName');

      if (cancellationNotifier?.value == true) {
        debugPrint("Subida cancelada antes de iniciar.");
        return null;
      }

      if (kIsWeb) {
        final Uint8List bytes = await imageFile.readAsBytes();
        await storageRef.putData(bytes, metadata);
      } else {
        await storageRef.putFile(File(imageFile.path), metadata);
      }
      
      if (cancellationNotifier?.value == true) {
        debugPrint("Subida cancelada. Eliminando archivo original de Firebase...");
        await storageRef.delete();
        return null;
      }

      final String resizedFileName = uniqueFileName.replaceFirst(
        '.$fileExtension',
        '_800x800.$fileExtension',
      );
      
      final resizedRef = _storage.ref().child('analisis/$resizedFileName');

      String downloadUrl;
      int attempts = 0;
      while (true) {
        if (cancellationNotifier?.value == true) {
          debugPrint("Búsqueda de imagen redimensionada cancelada. Eliminando archivo original...");
          await storageRef.delete();
          return null;
        }

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
      debugPrint("Error en el servicio de storage: $e");
      return null;
    }
  }
}