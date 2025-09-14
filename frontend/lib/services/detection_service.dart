// frontend/lib/services/detection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DetectionService {
  final String _baseUrl = "http://192.168.0.32:5001"; // Asegúrate que esta IP sea la correcta
  final AuthService _authService = AuthService();

  // --- MÉTODO PARA ANALIZAR IMAGEN (CORREGIDO Y COMPLETO) ---
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
      ).timeout(const Duration(seconds: 30)); // Aumenta el timeout por si el análisis tarda

      return response;

    } on TimeoutException catch (_) {
        throw Exception('La conexión tardó demasiado. Asegúrate que el servidor backend esté corriendo en: $_baseUrl');
    } on http.ClientException catch (e) {
        throw Exception('Error de red: No se pudo conectar al servidor. Detalle: ${e.message}');
    } catch (e) {
        throw Exception('Ocurrió un error inesperado al contactar el servicio de detección: $e');
    }
  }

  // --- MÉTODO PARA OBTENER EL HISTORIAL ---
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
        // La URL ahora incluye el ID del análisis
        Uri.parse('$_baseUrl/history/$analysisId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Si el servidor responde con 200 OK, el borrado fue exitoso
        return true;
      } else {
        // Si no, lanzamos un error con el mensaje del servidor
        final body = json.decode(response.body);
        throw Exception('Error al borrar: ${body['error']}');
      }
    } catch (e) {
      // Re-lanzamos el error para que la pantalla lo pueda mostrar
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
}

