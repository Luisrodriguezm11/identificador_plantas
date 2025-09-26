// frontend/lib/services/detection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DetectionService {
  // Asegúrate que esta IP sea la correcta y accesible desde tu dispositivo.
  // Si usas un emulador de Android, puedes usar 10.0.2.2 para referirte al localhost de tu máquina.
  final String _baseUrl = "https://identificador-plantas-backend.onrender.com";
  final AuthService _authService = AuthService();

  // --- ANÁLISIS DE IMÁGENES ---
  Future<http.Response> analyzeImages({required String imageUrlFront, String? imageUrlBack}) async {
    try {
      final String? token = await _authService.readToken();
      
      final Map<String, String> body = {
        'image_url_front': imageUrlFront,
      };

      if (imageUrlBack != null) {
        body['image_url_back'] = imageUrlBack;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/analyze'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90)); // Tiempo aumentado por si son 2 imágenes y la red es lenta
      
      return response;

    } on TimeoutException catch (_) {
      throw Exception('El servidor tardó demasiado en responder. Asegúrate que esté corriendo en: $_baseUrl');
    } on http.ClientException catch (e) {
      throw Exception('Error de red: No se pudo conectar al servidor. Detalle: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en analyzeImages: $e');
      throw Exception('Ocurrió un error inesperado al contactar el servicio de detección.');
    }
  }

  // --- OBTENER DETALLES DE UNA ENFERMEDAD ---
  Future<Map<String, dynamic>> getDiseaseDetails(String diseaseName) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/disease/$diseaseName'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Si la enfermedad no se encuentra, devolvemos valores por defecto.
        return {
          'info': {'descripcion': 'No se encontró información detallada para esta condición.'},
          'recommendations': [{'descripcion_tratamiento': 'No hay recomendaciones disponibles.'}]
        };
      } else {
        // Otros errores del servidor
        throw Exception('Error al cargar los detalles: ${response.reasonPhrase}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión para obtener detalles tardó demasiado.');
    } on http.ClientException catch (e) {
      throw Exception('Error de red al obtener detalles: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en getDiseaseDetails: $e');
      throw Exception('Ocurrió un error inesperado al obtener los detalles de la enfermedad.');
    }
  }

  // --- HISTORIAL DE ANÁLISIS ---
  Future<List<dynamic>> getHistory() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/history'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar el historial: ${response.reasonPhrase}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión para obtener el historial tardó demasiado.');
    } on http.ClientException catch (e) {
      throw Exception('Error de red al obtener el historial: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en getHistory: $e');
      throw Exception('Ocurrió un error inesperado al obtener el historial.');
    }
  }

  // --- MOVER UN ANÁLISIS A LA PAPELERA ---
  Future<bool> deleteHistoryItem(int analysisId) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/$analysisId'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al borrar el análisis: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación de borrado: $e');
    }
  }

  // --- OBTENER ITEMS DE LA PAPELERA ---
  Future<List<dynamic>> getTrashedItems() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/history/trash'),
        headers: {'x-access-token': token ?? ''},
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar la papelera: ${response.reasonPhrase}');
      }
    } catch(e) {
        throw Exception('No se pudo obtener la papelera: $e');
    }
  }

  // --- RESTAURAR UN ITEM DESDE LA PAPELERA ---
  Future<bool> restoreHistoryItem(int analysisId) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/history/$analysisId/restore'),
        headers: {'x-access-token': token ?? ''},
      ).timeout(const Duration(seconds: 15));
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('No se pudo restaurar el análisis: $e');
    }
  }

  // --- BORRADO PERMANENTE DE UN ITEM ---
  Future<bool> permanentlyDeleteItem(int analysisId) async {
     try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/$analysisId/permanent'),
        headers: {'x-access-token': token ?? ''},
      ).timeout(const Duration(seconds: 20)); // Aumentado por si borra en Storage
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('No se pudo eliminar permanentemente: $e');
    }
  }

  // --- VACIAR TODA LA PAPELERA ---
  Future<bool> emptyTrash() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/trash/empty'),
        headers: {'x-access-token': token ?? ''},
      ).timeout(const Duration(seconds: 45)); // Aumentado por si son muchos archivos
      
      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al vaciar la papelera: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación de vaciado: $e');
    }
  }

  // --- CÁLCULO DE DOSIS (NO PARECE USARSE, PERO SE MANTIENE) ---
  Future<Map<String, dynamic>> calculateDose(int treatmentId, int plantCount) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/calculate_dose'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
        body: jsonEncode({
          'treatment_id': treatmentId,
          'plant_count': plantCount,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al calcular la dosis: ${body['error']}');
      }
    } catch (e) {
      throw Exception('Error de conexión al calcular la dosis: $e');
    }
  }
}