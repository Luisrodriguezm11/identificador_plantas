// frontend/lib/screens/manage_recommendations_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'edit_recommendations_screen.dart'; // Importa la pantalla de edición

class ManageRecommendationsScreen extends StatefulWidget {
  const ManageRecommendationsScreen({super.key});

  @override
  State<ManageRecommendationsScreen> createState() =>
      _ManageRecommendationsScreenState();
}

class _ManageRecommendationsScreenState extends State<ManageRecommendationsScreen> {
  final DetectionService _detectionService = DetectionService();
  late Future<List<dynamic>> _diseasesFuture;

  @override
  void initState() {
    super.initState();
    _diseasesFuture = _detectionService.getAdminAllDiseases();
  }

  // Función para formatear el nombre para mostrarlo de forma más legible
  String _formatDiseaseName(String roboflowClass) {
    if (roboflowClass.isEmpty) return "Desconocido";
    return roboflowClass
        .replaceAll('hojas-', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Gestionar Enfermedades",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              image: DecorationImage(
                image: AssetImage("assets/background.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          FutureBuilder<List<dynamic>>(
            future: _diseasesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('No se encontraron enfermedades.',
                        style: TextStyle(color: Colors.white)));
              }

              final diseases = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.only(
                    top: 100, left: 24, right: 24, bottom: 24),
                itemCount: diseases.length,
                itemBuilder: (context, index) {
                  final disease = diseases[index];
                  return Card(
                    color: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(
                        disease['nombre_comun'] ?? 'Nombre no disponible',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Clase: ${disease['roboflow_class']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing:
                          const Icon(Icons.edit_outlined, color: Colors.white70),
                      onTap: () {
                        // Navega a la pantalla de edición y espera a que se cierre
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditRecommendationsScreen(disease: disease),
                          ),
                        ).then((_) {
                          // Cuando volvemos, recargamos la lista por si hubo cambios
                          setState(() {
                            _diseasesFuture =
                                _detectionService.getAdminAllDiseases();
                          });
                        });
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