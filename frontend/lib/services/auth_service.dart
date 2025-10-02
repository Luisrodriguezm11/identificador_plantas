// frontend/lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  //final String _baseUrl = "https://identificador-plantas-backend.onrender.com";
  final String _baseUrl = "http://192.168.0.30:5001";
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
    await _storage.delete(key: 'user_name'); // <--- CAMBIO: Asegurarse de borrar el nombre también
  }

  // --- Métodos de estado de Admin ---

  Future<void> saveAdminStatus(bool isAdmin) async {
    await _storage.write(key: 'is_admin', value: isAdmin.toString());
  }

  Future<bool> isAdmin() async {
    final isAdminString = await _storage.read(key: 'is_admin');
    return isAdminString == 'true';
  }
  
  // --- MÉTODOS NUEVOS PARA EL NOMBRE DE USUARIO ---

  // <--- CAMBIO: Nuevo método para guardar el nombre del usuario ---
  Future<void> saveUserName(String userName) async {
    await _storage.write(key: 'user_name', value: userName);
  }

  // <--- CAMBIO: Nuevo método para leer el nombre del usuario ---
  Future<String?> getUserName() async {
    return await _storage.read(key: 'user_name');
  }


  // --- MÉTODOS DE API ---

  Future<Map<String, dynamic>> register(String nombreCompleto, String email, String password, String? ong) async {
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
            // Si el login es exitoso, guarda cada dato con su método correspondiente
            await saveToken(handledResponse['data']['token']);
            await saveAdminStatus(handledResponse['data']['es_admin'] ?? false);
            // <--- CAMBIO: Guarda el nombre del usuario al iniciar sesión
            await saveUserName(handledResponse['data']['nombre_completo'] ?? 'Usuario'); 
        }
        return handledResponse;
    } catch (e) {
        return {'success': false, 'error': 'No se pudo conectar al servidor.'};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
     final Map<String, dynamic> body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': body};
    } else {
      return {'success': false, 'error': body['error'] ?? 'Ocurrió un error desconocido'};
    }
  }
}