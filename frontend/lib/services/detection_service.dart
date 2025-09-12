// frontend/lib/services/detection_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart'; // Necesario para obtener el token de autenticación

class DetectionService {
  // La URL de tu backend no cambia
  final String _baseUrl = "http://127.0.0.1:5001";
  final AuthService _authService = AuthService();

  /// Envía la URL de una imagen (ya subida a Firebase) al backend para su análisis.
  Future<http.Response> analyzeImageWithUrl(String imageUrl) async {
    // 1. Obtiene el token del usuario para autenticar la petición
    final String? token = await _authService.readToken();

    // 2. Realiza la petición POST, enviando la URL en formato JSON
    final response = await http.post(
      Uri.parse('$_baseUrl/analyze'),
      headers: <String, String>{
        // El backend ahora espera JSON, no un archivo
        'Content-Type': 'application/json; charset=UTF-8',
        // Adjunta el token para las rutas protegidas
        'x-access-token': token ?? '',
      },
      body: jsonEncode(<String, String>{
        'image_url': imageUrl,
      }),
    );

    return response;
  }
}