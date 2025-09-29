// frontend/lib/widgets/side_navigation_rail.dart
import 'package:flutter/material.dart';
import 'dart:ui';

class SideNavigationRail extends StatelessWidget {
  final bool isExpanded;
  final int selectedIndex;
  final bool isAdmin;
  final VoidCallback onToggle;
  final VoidCallback onLogout;
  final Function(int) onItemSelected;

  const SideNavigationRail({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.isAdmin,
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
          curve: Curves.easeInOut,
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
              // --- Pasamos el selectedIndex a cada item ---
              _buildNavItem(Icons.dashboard_outlined, "Dashboard", 0, selectedIndex, isExpanded, onItemSelected),
              _buildNavItem(Icons.history_outlined, "Historial", 1, selectedIndex, isExpanded, onItemSelected),
              _buildNavItem(Icons.delete_sweep_outlined, "Papelera", 2, selectedIndex, isExpanded, onItemSelected),
              _buildNavItem(Icons.calculate_outlined, "Calcular Dosis", 3, selectedIndex, isExpanded, onItemSelected), 

              if (isAdmin)
                _buildNavItem(Icons.admin_panel_settings_outlined, "Panel Admin", 4, selectedIndex, isExpanded, onItemSelected),
  
              const Spacer(),
              _buildNavItem(Icons.logout, "Cerrar Sesión", 5, selectedIndex, isExpanded, onItemSelected),
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

  // --- WIDGET DE ITEM DE NAVEGACIÓN ACTUALIZADO ---
  Widget _buildNavItem(IconData icon, String title, int index, int selectedIndex, bool isExpanded, Function(int) onItemSelected) {
    final bool isSelected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: BackdropFilter(
          // Aplicamos el filtro solo si está seleccionado
          filter: ImageFilter.blur(sigmaX: isSelected ? 5 : 0, sigmaY: isSelected ? 5 : 0),
          child: InkWell(
            onTap: () => onItemSelected(index),
            borderRadius: BorderRadius.circular(12.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                // Cambiamos el color de fondo si está seleccionado
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  if (isExpanded) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}