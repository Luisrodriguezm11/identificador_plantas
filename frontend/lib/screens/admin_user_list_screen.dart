// frontend/lib/screens/admin_user_list_screen.dart

import 'package:flutter/material.dart';
import 'package:frontend/services/detection_service.dart';
import 'dart:ui';
import 'admin_analyses_screen.dart'; // Para ver todos juntos
import 'user_specific_analyses_screen.dart'; // Para ver por usuario

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final DetectionService _detectionService = DetectionService();
  late Future<List<dynamic>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _detectionService.getUsersWithAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Monitor de Productores", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Ningún usuario ha realizado análisis aún.', style: TextStyle(color: Colors.white)));
              }

              final users = snapshot.data!;

              return Column(
                children: [
                  SizedBox(height: AppBar().preferredSize.height + 40), // Espacio para el AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('Ver todos los análisis juntos'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AdminAnalysesScreen()));
}
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final analysisCount = user['analysis_count'];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: const Icon(Icons.person_outline, color: Colors.white, size: 40),
                            title: Text(
                              user['nombre_completo'] ?? 'Usuario sin nombre',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              user['email'],
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Chip(
                              label: Text('$analysisCount análisis', style: const TextStyle(color: Colors.white)),
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => UserSpecificAnalysesScreen(user: user)));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}