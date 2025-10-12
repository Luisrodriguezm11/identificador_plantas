// frontend/lib/services/storage_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

// Importamos el AuthService para poder usar el token de autenticación
import 'auth_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // --- V MODIFICACIONES AÑADIDAS ---
  final AuthService _authService = AuthService();
  // Asegúrate que esta IP sea la correcta y accesible desde tu dispositivo.
  final String _baseUrl = "https://identificador-plantas-backend.onrender.com"; 
  //final String _baseUrl = "http://192.168.0.33:5001";
  //final String _baseUrl = "http://172.20.10.7:5001";
  // --- ^ FIN DE MODIFICACIONES ---

  // --- NUEVA FUNCIÓN PARA BORRAR IMAGEN VÍA BACKEND ---
  Future<bool> deleteImageFromUrl(String imageUrl) async {
    // Si la URL está vacía, no hay nada que hacer
    if (imageUrl.isEmpty) return true;

    try {
      final String? token = await _authService.readToken();
      if (token == null) {
        debugPrint("No se pudo borrar la imagen: Usuario no autenticado.");
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/admin/storage/delete'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token,
        },
        body: jsonEncode({'image_url': imageUrl}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint("Solicitud de borrado para $imageUrl enviada con éxito.");
        return true;
      } else {
        debugPrint("Error del servidor al borrar imagen del storage: ${response.body}");
        return false; // No bloqueamos al usuario si falla, pero registramos el error
      }
    } catch (e) {
      debugPrint("Excepción al intentar borrar imagen del storage: $e");
      return false; // No bloqueamos al usuario
    }
  }

  // --- FUNCIÓN PARA SUBIR FOTO DE PERFIL (sin cambios) ---
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

  // --- FUNCIÓN PARA SUBIR IMAGEN DE ENFERMEDAD (sin cambios) ---
  Future<String?> uploadDiseaseImage(XFile imageFile) async {
    try {
      final String originalFileName = imageFile.name;
      final String fileExtension = originalFileName.split('.').last.toLowerCase();
      final String uniqueFileName = '${const Uuid().v4()}.$fileExtension';

      final metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
      );

      // La guardamos en una carpeta diferente para mantener el orden
      final Reference storageRef = _storage.ref().child('disease_pictures/$uniqueFileName');

      if (kIsWeb) {
        final Uint8List bytes = await imageFile.readAsBytes();
        await storageRef.putData(bytes, metadata);
      } else {
        await storageRef.putFile(File(imageFile.path), metadata);
      }

      final String downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      debugPrint("Error en el servicio de storage al subir imagen de enfermedad: $e");
      return null;
    }
  }


  // --- FUNCIÓN ORIGINAL PARA SUBIR IMÁGENES DE ANÁLISIS (sin cambios) ---
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