// frontend/lib/services/detection_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DetectionService {
  // REEMPLAZA ESTA IP CON LA TUYA
  final String _baseUrl = "http://192.168.0.31:5001"; // <-- CAMBIA ESTO
  final AuthService _authService = AuthService();

  Future<http.Response> analyzeImageWithUrl(String imageUrl) async {
    // Este bloque try-catch mejorado previene el error 'type Null is not a subtype'
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
}