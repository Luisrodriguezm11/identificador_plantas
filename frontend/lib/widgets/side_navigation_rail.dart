import 'package:flutter/material.dart';
import 'dart:ui';

class SideNavigationRail extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onLogout;
  final Function(int) onItemSelected;

  const SideNavigationRail({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.onLogout,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut, // Curva de animación suave
          width: isExpanded ? 250 : 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: isExpanded
                      ? const Column(
                          key: ValueKey('expanded'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bienvenido",
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Text(
                              "Usuario",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : const Icon(key: ValueKey('collapsed'), Icons.person, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white30, indent: 16, endIndent: 16),
              const SizedBox(height: 16),
              _buildNavItem(Icons.home_outlined, "Dashboard", 0, isExpanded, onItemSelected),
              _buildNavItem(Icons.history_outlined, "Historial", 1, isExpanded, onItemSelected),
              _buildNavItem(Icons.delete_sweep_outlined, "Papelera", 2, isExpanded, onItemSelected),
              const Spacer(),
              _buildNavItem(Icons.logout, "Cerrar Sesión", 3, isExpanded, onItemSelected),
              const SizedBox(height: 16),
              IconButton(
                icon: Icon(isExpanded ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios, color: Colors.white, size: 18),
                onPressed: onToggle,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET CORREGIDO ---
  Widget _buildNavItem(IconData icon, String title, int index, bool isExpanded, Function(int) onItemSelected) {
    return InkWell(
      onTap: () => onItemSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        // Usamos ClipRect para asegurarnos de que nada se salga de los límites
        child: ClipRect(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              // Solo si está expandido, mostramos el texto
              if (isExpanded) ...[
                const SizedBox(width: 16),
                // Expanded se asegura de que el texto ocupe el espacio restante sin desbordarse
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1, // Evita que el texto se parta en dos líneas
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}