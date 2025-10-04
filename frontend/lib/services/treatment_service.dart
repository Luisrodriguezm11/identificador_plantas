// frontend/lib/services/treatment_service.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// Modelo de Enfermedad
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

// Modelo de Tratamiento (con periodo_carencia añadido)
class Tratamiento {
  final int id;
  final String nombreComercial;
  final String ingredienteActivo;
  final String tipoTratamiento;
  final dynamic dosis;
  final String unidadMedida;
  final String? periodoCarencia; // <-- CAMBIO: Añadido

  Tratamiento({
    required this.id,
    required this.nombreComercial,
    required this.ingredienteActivo,
    required this.tipoTratamiento,
    required this.dosis,
    required this.unidadMedida,
    this.periodoCarencia, // <-- CAMBIO: Añadido
  });

  factory Tratamiento.fromJson(Map<String, dynamic> json) {
    return Tratamiento(
      id: json['id'],
      nombreComercial: json['nombre_comercial'],
      tipoTratamiento: json['tipo_tratamiento'],
      ingredienteActivo: json['ingrediente_activo'],
      dosis: json['dosis'],
      unidadMedida: json['unidad_medida'],
      periodoCarencia: json['periodo_carencia'], // <-- CAMBIO: Añadido
    );
  }
}

class TreatmentService {

  //final String _baseUrl = "https://identificador-plantas-backend.onrender.com"; 
  final String _baseUrl = "http://192.168.0.33:5001";
//final String _baseUrl = "http://172.20.10.7:5001";

  final AuthService _authService = AuthService();
  // Asegúrate que esta IP es la de tu PC


  Future<List<Enfermedad>> getEnfermedades() async {
    try {
      final String? token = await _authService.readToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/enfermedades'), // <-- RUTA CORREGIDA
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
        Uri.parse('$_baseUrl/api/tratamientos/$enfermedadId'), // <-- RUTA CORREGIDA
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