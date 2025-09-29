// frontend/lib/screens/user_specific_analyses_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'analysis_detail_screen.dart';

class UserSpecificAnalysesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserSpecificAnalysesScreen({super.key, required this.user});

  @override
  State<UserSpecificAnalysesScreen> createState() => _UserSpecificAnalysesScreenState();
}

class _UserSpecificAnalysesScreenState extends State<UserSpecificAnalysesScreen> {
  final DetectionService _detectionService = DetectionService();
  late Future<List<dynamic>> _analysesFuture;

  @override
  void initState() {
    super.initState();
    _analysesFuture = _detectionService.getAnalysesForUser(widget.user['id_usuario']);
  }

  String _formatPredictionName(String originalName) {
    if (originalName.toLowerCase() == 'no se detectó ninguna plaga') {
      return 'Hoja Sana';
    }
    String formattedName = originalName.replaceAll('hojas-', '').replaceAll('_', ' ');
    if (formattedName.isEmpty) return 'Desconocido';
    return formattedName[0].toUpperCase() + formattedName.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Análisis de ${widget.user['nombre_completo']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
           Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/background.jpg"), fit: BoxFit.cover),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),
          FutureBuilder<List<dynamic>>(
            future: _analysesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Este usuario no tiene análisis.', style: TextStyle(color: Colors.white)));
              }

              final analyses = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.only(top: 100, left: 24, right: 24, bottom: 24),
                itemCount: analyses.length,
                itemBuilder: (context, index) {
                   final analysis = analyses[index];
                  final fecha = DateTime.parse(analysis['fecha_analisis']);
                  final fechaFormateada = "${fecha.day}/${fecha.month}/${fecha.year}";

                  return Card(
                    color: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(analysis['url_imagen']),
                      ),
                      title: Text(
                        _formatPredictionName(analysis['resultado_prediccion']),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Fecha: $fechaFormateada',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(Icons.visibility_outlined, color: Colors.white70),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: AnalysisDetailScreen(analysis: analysis),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}