// frontend/lib/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'dart:ui';
// Importaremos esta pantalla en el siguiente paso
import 'manage_recommendations_screen.dart';
import 'admin_user_list_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Para que el fondo se vea detrás del AppBar
      appBar: AppBar(
        title: const Text("Panel de Administrador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, // Hacemos el AppBar transparente
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Fondo con efecto blur
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
          // Contenido
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAdminCard(
                    context,
                    icon: Icons.edit_note,
                    title: 'Gestionar Recomendaciones',
                    subtitle: 'Añade, edita o elimina tratamientos para cada enfermedad.',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageRecommendationsScreen()));
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildAdminCard(
                    context,
                    icon: Icons.bar_chart,
                    title: 'Ver Análisis de Usuarios',
                    subtitle: 'Monitorea todos los análisis enviados por los productores.',
                    onTap: () {
    // Navegamos a la nueva pantalla de lista de usuarios
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUserListScreen()));
  },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 48),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}