// frontend/lib/widgets/top_navigation_bar.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_provider.dart'; // <-- 1. IMPORTAMOS EL THEME PROVIDER

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
    final theme = Theme.of(context); // Obtenemos el tema actual
    // final isDark = theme.brightness == Brightness.dark; // Ya no es necesario con el tema dinámico

    final navItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'index': 0},
      {'icon': Icons.history_outlined, 'label': 'Historial', 'index': 1},
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
              // --- 👇 CAMBIO: Usamos el color 'surface' del tema actual 👇 ---
              color: theme.colorScheme.surface.withOpacity(0.15),
              border: Border(
                bottom: BorderSide(
                  // --- 👇 CAMBIO: Usamos el color 'onSurface' del tema para el borde 👇 ---
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
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

Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedIndex == index;
    final isHovered = _hoveredIndex == index;

    // --- 👇 CAMBIO: Usamos colores del tema que garantizan contraste 👇 ---

    // Color para el item seleccionado. Usamos blanco o negro según el tema.
    final Color selectedColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    // Color para los items no seleccionados. 
    // Usamos 'onSurface', que es el color estándar para texto sobre fondos como la barra.
    // Será claro en tema oscuro y oscuro en tema claro, ¡perfecto para la legibilidad!
    final Color defaultColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onItemSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // El fondo del item seleccionado puede seguir usando el color primario con opacidad.
            color: isSelected ? selectedColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Usamos los nuevos colores aquí
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
                            // Y también aquí
                            style: TextStyle(
                              color: isSelected ? selectedColor : defaultColor,
                              fontWeight: FontWeight.bold, // Añadimos negrita para mejorar la lectura
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
} // <-- Fin de la clase _TopNavigationBarState