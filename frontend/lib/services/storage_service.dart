// frontend/lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- NUEVA LÓGICA DE SUBIDA DIRECTA ---
  Future<String?> uploadOriginalImage(XFile imageFile) async {
    try {
      // 1. Obtenemos el nombre y la extensión del archivo original.
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last;
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';

      // 2. Subimos la imagen a la carpeta 'uploads' que configuramos en la extensión.
      // No hay procesamiento local, solo se sube el archivo tal cual.
      final Reference storageRef = _storage.ref().child('uploads/$uniqueFileName');

      if (kIsWeb) {
        final Uint8List bytes = await imageFile.readAsBytes();
        await storageRef.putData(bytes);
      } else {
        await storageRef.putFile(File(imageFile.path));
      }

      // --- 3. CONSTRUIMOS LA URL DE LA IMAGEN REDIMENSIONADA ---
      // La extensión añade un sufijo al nombre del archivo.
      // Ejemplo: 'mi_imagen.jpg' se convierte en 'mi_imagen_800x800.jpg'
      final String resizedFileName = uniqueFileName.replaceFirst(
        '.$fileExtension',
        '_800x800.$fileExtension',
      );
      
      // La imagen redimensionada estará en la misma carpeta 'uploads'.
      final resizedRef = _storage.ref().child('uploads/$resizedFileName');

      // 4. Esperamos y obtenemos la URL de la nueva imagen.
      // La extensión puede tardar unos segundos en crear el archivo.
      // Haremos varios intentos hasta que esté disponible.
      String downloadUrl;
      int attempts = 0;
      while (true) {
        try {
          downloadUrl = await resizedRef.getDownloadURL();
          break; // Si tenemos éxito, salimos del bucle.
        } catch (e) {
          attempts++;
          // Si después de 15 segundos no aparece, lanzamos un error.
          if (attempts > 15) { 
            throw Exception('La imagen redimensionada no se encontró después de 15 segundos.');
          }
          // Esperamos 1 segundo antes de reintentar.
          await Future.delayed(const Duration(seconds: 1)); 
        }
      }

      return downloadUrl;

    } catch (e) {
      debugPrint("Error al subir imagen y obtener URL redimensionada: $e");
      // Devolvemos null para que la UI pueda manejar el error.
      return null;
    }
  }
}