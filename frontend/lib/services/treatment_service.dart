// frontend/lib/services/treatment_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart'; // <-- 1. Importamos AuthService

// El modelo de Enfermedad (sin cambios)
class Enfermedad {
  final int id;
  final String nombreComun;

  Enfermedad({required this.id, required this.nombreComun});

  factory Enfermedad.fromJson(Map<String, dynamic> json) {
    return Enfermedad(
      id: json['id'],
      nombreComun: json['nombre_comun'],
    );
  }
}

// El modelo de Tratamiento (sin cambios)
class Tratamiento {
  final int id;
  final String nombreComercial;
  final String ingredienteActivo;
  final String tipoTratamiento;
  final dynamic dosis;
  final String unidadMedida;
  final String? periodoCarencia;

  Tratamiento({
    required this.id,
    required this.nombreComercial,
    required this.ingredienteActivo,
    required this.tipoTratamiento,
    required this.dosis,
    required this.unidadMedida,
    this.periodoCarencia,
  });

  factory Tratamiento.fromJson(Map<String, dynamic> json) {
    return Tratamiento(
      id: json['id'],
      nombreComercial: json['nombre_comercial'],
      tipoTratamiento: json['tipo_tratamiento'],
      ingredienteActivo: json['ingrediente_activo'],
      dosis: json['dosis'],
      unidadMedida: json['unidad_medida'],
      periodoCarencia: json['periodo_carencia'],
    );
  }
}


// --- 👇 CLASE DE SERVICIO COMPLETAMENTE CORREGIDA 👇 ---

class TreatmentService {
  // Usamos la misma URL base que en tus otros servicios para consistencia
  final String _baseUrl = "http://localhost:5001"; 
  
  // 2. Creamos una instancia de AuthService para manejar el token
  final AuthService _authService = AuthService();

  // Función para obtener la lista de enfermedades del backend.
  Future<List<Enfermedad>> getEnfermedades() async {
    try {
      // 3. Leemos el token usando el método correcto de AuthService
      final String? token = await _authService.readToken();
      
      final response = await http.get(
        // La ruta ahora incluye /api aquí
        Uri.parse('$_baseUrl/api/enfermedades'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          // 4. Enviamos el token con la cabecera correcta: 'x-access-token'
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        List<Enfermedad> enfermedades = body.map((dynamic item) => Enfermedad.fromJson(item)).toList();
        return enfermedades;
      } else {
        throw Exception('Error del servidor al cargar enfermedades: ${response.reasonPhrase}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión para obtener enfermedades tardó demasiado.');
    } on http.ClientException catch (e) {
      throw Exception('Error de red al obtener enfermedades: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en getEnfermedades: $e');
      throw Exception('Ocurrió un error inesperado al obtener las enfermedades.');
    }
  }

  // Función para obtener los tratamientos de una enfermedad específica.
  Future<List<Tratamiento>> getTratamientos(int enfermedadId) async {
    try {
      final String? token = await _authService.readToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tratamientos/$enfermedadId'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '', // <-- Cabecera corregida aquí también
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        List<Tratamiento> tratamientos = body.map((dynamic item) => Tratamiento.fromJson(item)).toList();
        return tratamientos;
      } else {
        throw Exception('Error del servidor al cargar tratamientos: ${response.reasonPhrase}');
      }
    } on TimeoutException catch (_) {
      throw Exception('La conexión para obtener tratamientos tardó demasiado.');
    } on http.ClientException catch (e) {
      throw Exception('Error de red al obtener tratamientos: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en getTratamientos: $e');
      throw Exception('Ocurrió un error inesperado al obtener los tratamientos.');
    }
  }
}