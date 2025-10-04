// frontend/lib/widgets/top_navigation_bar.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_provider.dart';
import '../screens/detection_screen.dart';

class TopNavigationBar extends StatefulWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool isAdmin;
  final Function(int) onItemSelected;
  final VoidCallback onLogout;

  const TopNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.isAdmin,
    required this.onItemSelected,
    required this.onLogout,
  });

  @override
  State<TopNavigationBar> createState() => _TopNavigationBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _TopNavigationBarState extends State<TopNavigationBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    // --- CAMBIO 1: "Nuevo Análisis" ahora es parte de la lista principal ---
    // Le asignamos un índice único (5) para identificarlo.
    final navItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'index': 0},
      {'icon': Icons.history_outlined, 'label': 'Historial', 'index': 1},
      {'icon': Icons.add_circle_outline, 'label': 'Nuevo Análisis', 'index': 5},
      {'icon': Icons.delete_sweep_outlined, 'label': 'Papelera', 'index': 2},
      {'icon': Icons.calculate_outlined, 'label': 'Tratamientos', 'index': 3},
    ];

    if (widget.isAdmin) {
      navItems.add({'icon': Icons.admin_panel_settings_outlined, 'label': 'Panel Admin', 'index': 4});
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.15),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
      // El Row ahora construye todos los botones de la misma manera, sin inserciones manuales.
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: navItems.map((item) => _buildNavItem(
          icon: item['icon'] as IconData,
          label: item['label'] as String,
          index: item['index'] as int,
        )).toList(),
      ),
      actions: [
        IconButton(
          tooltip: 'Cambiar Tema',
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
        ),
        IconButton(
          tooltip: 'Cerrar Sesión',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
        const SizedBox(width: 20),
      ],
      automaticallyImplyLeading: false,
    );
  }

  // --- La función `_buildNewAnalysisButton` ha sido eliminada por completo ---

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    final Color selectedColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    
    final Color defaultColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // --- CAMBIO 2: La lógica de clic ahora es inteligente ---
        onTap: () {
          // Si el índice es 5 ("Nuevo Análisis"), navega a la pantalla de detección.
          if (index == 5) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DetectionScreen()));
          } 
          // Para todos los demás, ejecuta la acción normal de cambio de pestaña.
          else {
            widget.onItemSelected(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? selectedColor : defaultColor),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: isHovered || isSelected
                    ? Row(
                        key: ValueKey('text_$label'),
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? selectedColor : defaultColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : SizedBox.shrink(key: ValueKey('icon_$label')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}