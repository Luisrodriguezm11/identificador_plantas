// frontend/lib/services/detection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DetectionService {
  // Asegúrate que esta IP sea la correcta y accesible desde tu dispositivo.
  // Si usas un emulador de Android, puedes usar 10.0.2.2 para referirte al localhost de tu máquina.
  //final String _baseUrl = "https://identificador-plantas-backend.onrender.com"; 
  final String _baseUrl = "http://192.168.0.33:5001";
  //final String _baseUrl = "http://172.20.10.7:5001";
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

  // --- 👇 NUEVO MÉTODO PARA GUARDAR EL RESULTADO DEL ANÁLISIS 👇 ---
  Future<http.Response> saveAnalysisResult(Map<String, dynamic> analysisResult) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/history/save'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
        body: jsonEncode(analysisResult),
      ).timeout(const Duration(seconds: 20));

      return response;
    } on TimeoutException catch (_) {
      throw Exception('El servidor tardó demasiado en guardar el resultado.');
    } on http.ClientException catch (e) {
      throw Exception('Error de red al guardar el resultado: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en saveAnalysisResult: $e');
      throw Exception('Ocurrió un error inesperado al guardar el análisis.');
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

  Future<bool> adminDeleteHistoryItem(int analysisId) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/admin/analysis/$analysisId'), // <-- Usa la nueva ruta
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al borrar como admin: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación de borrado de admin: $e');
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

  Future<List<dynamic>> getAdminTrashedItems() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/trash'), // <-- Llama a la nueva ruta
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al cargar la papelera de admin: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación: $e');
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

 // --- NUEVO MÉTODO PARA RESTAURAR COMO ADMIN ---
  Future<bool> adminRestoreHistoryItem(int analysisId) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/analysis/restore/$analysisId'), // <-- Usa la nueva ruta
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al restaurar como admin: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación: $e');
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

Future<List<dynamic>> getAdminAllDiseases() async {
    final token = await _authService.readToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/diseases'),
      headers: {'x-access-token': token ?? ''},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar las enfermedades: ${response.reasonPhrase}');
    }
  }

  Future<Map<String, dynamic>> addTreatment(Map<String, dynamic> treatmentData) async {
    final token = await _authService.readToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/treatments'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'x-access-token': token ?? '',
      },
      body: jsonEncode(treatmentData),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final body = json.decode(response.body);
      throw Exception('Error al añadir tratamiento: ${body['error']}');
    }
  }

  Future<Map<String, dynamic>> updateTreatment(int treatmentId, Map<String, dynamic> treatmentData) async {
    final token = await _authService.readToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/treatments/$treatmentId'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'x-access-token': token ?? '',
      },
      body: jsonEncode(treatmentData),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final body = json.decode(response.body);
      throw Exception('Error al actualizar tratamiento: ${body['error']}');
    }
  }

  Future<bool> deleteTreatment(int treatmentId) async {
    final token = await _authService.readToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/treatments/$treatmentId'),
      headers: {'x-access-token': token ?? ''},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return true;
    } else {
      final body = json.decode(response.body);
      throw Exception('Error al eliminar tratamiento: ${body['error']}');
    }
  }

// --- NUEVO MÉTODO PARA ACTUALIZAR DETALLES DE ENFERMEDAD ---
  Future<bool> updateDiseaseDetails(int diseaseId, Map<String, dynamic> diseaseData) async {
    final token = await _authService.readToken();
    if (token == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/disease/$diseaseId'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token,
        },
        body: jsonEncode(diseaseData),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return true; // Éxito
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al actualizar la enfermedad: ${body['error']}');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado en responder.');
    } catch (e) {
      // Re-lanzamos la excepción para que la UI pueda manejarla
      throw Exception('No se pudo completar la operación de actualización: $e');
    }
  }  

Future<List<dynamic>> getUsersWithAnalyses() async {
    final token = await _authService.readToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users_with_analyses'),
      headers: {'x-access-token': token ?? ''},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar la lista de usuarios');
    }
  }

  Future<List<dynamic>> getAnalysesForUser(int userId) async {
    final token = await _authService.readToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analyses/user/$userId'),
      headers: {'x-access-token': token ?? ''},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar los análisis del usuario');
    }
  }

  Future<List<dynamic>> getAdminAllAnalyses() async {
    final token = await _authService.readToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/admin/analyses'),
      headers: {'x-access-token': token ?? ''},
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar todos los análisis: ${response.reasonPhrase}');
    }
  }

}


