// frontend/lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  //final String _baseUrl = "https://identificador-plantas-backend.onrender.com";
  final String _baseUrl = "http://192.168.0.10:5001";
  //final String _baseUrl = "http://172.20.10.7:5001";
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
    await _storage.delete(key: 'is_admin');
    await _storage.delete(key: 'user_name');
  }

  // --- Métodos de estado de Admin ---

  Future<void> saveAdminStatus(bool isAdmin) async {
    await _storage.write(key: 'is_admin', value: isAdmin.toString());
  }

  Future<bool> isAdmin() async {
    final isAdminString = await _storage.read(key: 'is_admin');
    return isAdminString == 'true';
  }

  // --- MÉTODOS PARA EL NOMBRE DE USUARIO ---

  Future<void> saveUserName(String userName) async {
    await _storage.write(key: 'user_name', value: userName);
  }

  Future<String?> getUserName() async {
    return await _storage.read(key: 'user_name');
  }

  // --- MÉTODOS DE API ---

  Future<Map<String, dynamic>> register(String nombreCompleto, String email,
      String password, String? ong, {String? profileImageUrl}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String?>{
              'nombre_completo': nombreCompleto,
              'email': email,
              'password': password,
              'ong': ong,
              'profile_image_url': profileImageUrl,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'No se pudo conectar al servidor.'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final handledResponse = _handleResponse(response);
      if (handledResponse['success']) {
        await saveToken(handledResponse['data']['token']);
        await saveAdminStatus(handledResponse['data']['es_admin'] ?? false);
        await saveUserName(
            handledResponse['data']['nombre_completo'] ?? 'Usuario');
      }
      return handledResponse;
    } catch (e) {
      return {'success': false, 'error': 'No se pudo conectar al servidor.'};
    }
  }

  // --- 👇 CORRECCIONES CON TIMEOUT AQUÍ 👇 ---

  Future<Map<String, dynamic>> getUserProfile() async {
  final token = await readToken();
  if (token == null) return {'success': false, 'error': 'No autenticado'};

  // --- PUNTO DE CONTROL 2 ---
  print('[DEBUG] 2. AuthService: Intentando llamar a /profile con el token: $token');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
      ).timeout(const Duration(seconds: 15)); // <-- TIMEOUT AÑADIDO
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión'};
    }
  }

  Future<Map<String, dynamic>> updateProfile(
      {String? nombreCompleto, String? profileImageUrl}) async {
    final token = await readToken();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    final body = <String, String?>{
      'nombre_completo': nombreCompleto,
      'profile_image_url': profileImageUrl,
    };
    body.removeWhere((key, value) => value == null);

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15)); // <-- TIMEOUT AÑADIDO
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión'};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await readToken();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/profile/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 15)); // <-- TIMEOUT AÑADIDO
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión'};
    }
  }
  
Future<Map<String, dynamic>> deleteUserByAdmin(int userId) async {
    final token = await readToken();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/admin/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión'};
    }
  }

  Future<Map<String, dynamic>> resetPasswordByAdmin({
    required int userId,
    required String newPassword,
  }) async {
    final token = await readToken();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/user/$userId/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
        body: jsonEncode({
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión'};
    }
  }

// frontend/lib/services/auth_service.dart

  Future<Map<String, dynamic>> deleteCurrentUserAccount(String password) async {
    final token = await readToken();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/profile/delete'),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': token,
        },
        body: jsonEncode({
          'current_password': password,
        }),
      ).timeout(const Duration(seconds: 45)); // Tiempo de espera más largo

      // Si la eliminación fue exitosa, borramos el token localmente
      if (response.statusCode == 200) {
        await deleteToken();
      }

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión durante la eliminación'};
    }
  }

Map<String, dynamic> _handleResponse(http.Response response) {
  // --- PUNTO DE CONTROL 3 ---
  print('[DEBUG] 3. AuthService: Respuesta del servidor (Status Code: ${response.statusCode})');
  print('[DEBUG] 3.1. AuthService: Cuerpo de la respuesta: ${response.body}');

  final Map<String, dynamic> body = json.decode(response.body);
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return {'success': true, 'data': body};
  } else {
      return {
        'success': false,
        'error': body['error'] ?? 'Ocurrió un error desconocido'
      };
    }
  }
}