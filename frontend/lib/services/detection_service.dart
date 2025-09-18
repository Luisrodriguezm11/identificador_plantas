// frontend/lib/services/detection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DetectionService {
  final String _baseUrl = "http://192.168.0.18:5001"; // Asegúrate que esta IP sea la correcta
  final AuthService _authService = AuthService();

  Future<http.Response> analyzeImageWithUrl(String imageUrl) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
        body: jsonEncode(<String, String>{
          'image_url': imageUrl,
        }),
      ).timeout(const Duration(seconds: 30));
      return response;
    } on TimeoutException catch (_) {
      throw Exception('La conexión tardó demasiado. Asegúrate que el servidor backend esté corriendo en: $_baseUrl');
    } on http.ClientException catch (e) {
      throw Exception('Error de red: No se pudo conectar al servidor. Detalle: ${e.message}');
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al contactar el servicio de detección: $e');
    }
  }

  // --- NUEVA FUNCIÓN ---
  Future<Map<String, dynamic>> getDiseaseDetails(String diseaseName) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/disease/$diseaseName'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // Si la enfermedad no se encuentra, devolvemos un mapa con valores por defecto.
        return {
          'info': {'descripcion': 'No se encontró información detallada para esta condición.'},
          'recommendations': [{'descripcion_tratamiento': 'No hay recomendaciones disponibles.'}]
        };
      } else {
        throw Exception('Error al cargar los detalles: ${response.body}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión para obtener detalles tardó demasiado.');
    } catch (e) {
      throw Exception('Error de conexión al obtener detalles: $e');
    }
  }
  // --- FIN DE LA NUEVA FUNCIÓN ---

  Future<List<dynamic>> getHistory() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/history'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar el historial: ${response.body}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión tardó demasiado.');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<bool> deleteHistoryItem(int analysisId) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/$analysisId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al borrar: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación: $e');
    }
  }

  Future<List<dynamic>> getTrashedItems() async {
    final String? token = await _authService.readToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/history/trash'),
      headers: {'x-access-token': token ?? ''},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar la papelera');
    }
  }

  Future<bool> restoreHistoryItem(int analysisId) async {
    final String? token = await _authService.readToken();
    final response = await http.put(
      Uri.parse('$_baseUrl/history/$analysisId/restore'),
      headers: {'x-access-token': token ?? ''},
    );
    return response.statusCode == 200;
  }

  Future<bool> permanentlyDeleteItem(int analysisId) async {
    final String? token = await _authService.readToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/history/$analysisId/permanent'),
      headers: {'x-access-token': token ?? ''},
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> calculateDose(int treatmentId, int plantCount) async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/calculate_dose'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
        body: jsonEncode(<String, int>{
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
    } on TimeoutException catch (_) {
      throw Exception('La conexión para calcular la dosis tardó demasiado.');
    } catch (e) {
      throw Exception('Error de conexión al calcular la dosis: $e');
    }
}

Future<bool> emptyTrash() async {
    try {
      final String? token = await _authService.readToken();
      final response = await http.delete(
        Uri.parse('$_baseUrl/history/trash/empty'),
        headers: {'x-access-token': token ?? ''},
      ).timeout(const Duration(seconds: 30)); // Aumentado por si son muchos archivos

      if (response.statusCode == 200) {
        return true;
      } else {
        final body = json.decode(response.body);
        throw Exception('Error al vaciar la papelera: ${body['error']}');
      }
    } catch (e) {
      throw Exception('No se pudo completar la operación: $e');
    }
}
}