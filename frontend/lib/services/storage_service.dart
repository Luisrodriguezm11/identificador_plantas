// frontend/lib/services/storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- ✨ MODIFICACIÓN PRINCIPAL AQUÍ ---
  // Ahora el método acepta un ValueNotifier para saber si se canceló.
  Future<String?> uploadOriginalImage(XFile imageFile, {ValueNotifier<bool>? cancellationNotifier}) async {
    try {
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last.toLowerCase();
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';
      
      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      final Reference storageRef = _storage.ref().child('analisis/$uniqueFileName');

      // --- Verificación de cancelación ANTES de subir ---
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
      
      // --- Verificación de cancelación DESPUÉS de subir (antes de buscar la redimensionada) ---
      if (cancellationNotifier?.value == true) {
        // Si se canceló, borramos el archivo que acabamos de subir
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
        // Verificamos en cada intento si se ha cancelado
        if (cancellationNotifier?.value == true) {
          debugPrint("Búsqueda de imagen redimensionada cancelada. Eliminando archivo original...");
          await storageRef.delete(); // Borramos el original si ya se había subido
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