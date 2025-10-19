// frontend/lib/services/treatment_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// --- 👇 CLASE ENFERMEDAD ACTUALIZADA 👇 ---
class Enfermedad {
  final int id;
  final String nombreComun;
  final String roboflowClass;
  final String? imagenUrl; // <-- AÑADE ESTA LÍNEA

  Enfermedad({
    required this.id, 
    required this.nombreComun, 
    required this.roboflowClass, 
    this.imagenUrl // <-- Y AQUÍ
  });

  factory Enfermedad.fromJson(Map<String, dynamic> json) {
    return Enfermedad(
      id: json['id'],
      nombreComun: json['nombre_comun'],
      roboflowClass: json['roboflow_class'],
      imagenUrl: json['imagen_url'], // <-- Y AQUÍ
    );
  }
}

// Modelo de Tratamiento (sin cambios)
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

class TreatmentService {
  final String _baseUrl = "http://192.168.0.10:5001";
  //final String _baseUrl = "https://identificador-plantas-backend.onrender.com"; 
  final AuthService _authService = AuthService();

  // El resto de la clase no necesita cambios
  Future<List<Enfermedad>> getEnfermedades() async {
    try {
      final String? token = await _authService.readToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/enfermedades'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => Enfermedad.fromJson(item)).toList();
      } else {
        throw Exception('Error del servidor: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error al obtener enfermedades: $e');
    }
  }

  Future<List<Tratamiento>> getTratamientos(int enfermedadId) async {
    try {
      final String? token = await _authService.readToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tratamientos/$enfermedadId'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'x-access-token': token ?? '',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((dynamic item) => Tratamiento.fromJson(item)).toList();
      } else {
        throw Exception('Error del servidor: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error al obtener tratamientos: $e');
    }
  }
}