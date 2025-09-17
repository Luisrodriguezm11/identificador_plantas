// frontend/lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // <-- 1. Importa el paquete

class AuthService {
  final String _baseUrl = "http://192.168.13.2:5001";
  // 2. Crea una instancia del almacenamiento seguro
  final _storage = const FlutterSecureStorage();

  // --- Métodos de almacenamiento de Token ---

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> readToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  // --- Métodos de API (ya los tenías) ---
  Future<Map<String, dynamic>> register(String nombreCompleto, String email, String password, String? ong) async {
    // ... tu código de registro no cambia
    try {
        final response = await http.post(
          Uri.parse('$_baseUrl/register'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String?>{
            'nombre_completo': nombreCompleto,
            'email': email,
            'password': password,
            'ong': ong,
          }),
        ).timeout(const Duration(seconds: 10));
        return _handleResponse(response);
      } catch (e) {
        return {'success': false, 'error': 'No se pudo conectar al servidor.'};
      }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
        final response = await http.post(
          Uri.parse('$_baseUrl/login'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'email': email,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 10));

        final handledResponse = _handleResponse(response);
        if(handledResponse['success']){
            // 3. Si el login es exitoso, guarda el token
            await saveToken(handledResponse['data']['token']);
        }
        return handledResponse;
    } catch (e) {
        return {'success': false, 'error': 'No se pudo conectar al servidor.'};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    // ... tu código para manejar la respuesta no cambia
     final Map<String, dynamic> body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': body};
    } else {
      return {'success': false, 'error': body['error'] ?? 'Ocurrió un error desconocido'};
    }
  }
}