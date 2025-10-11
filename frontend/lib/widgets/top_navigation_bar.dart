// frontend/lib/widgets/top_navigation_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_provider.dart';
import '../screens/detection_screen.dart';
import '../screens/edit_profile_screen.dart';

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
    final theme = Theme.of(context);

    // --- 1. SE MANTIENE LA LISTA DE ITEMS DE NAVEGACIÓN ---
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
      automaticallyImplyLeading: false,
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
      // --- 2. SE USA LAYOUTBUILDER PARA LA RESPONSIVIDAD ---
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Definimos un punto de quiebre. Si es más angosto de 700px, se considera "pequeña".
          if (constraints.maxWidth < 700) {
            // --- DISEÑO PARA PANTALLAS PEQUEÑAS ---
            return _buildNarrowLayout(navItems);
          } else {
            // --- DISEÑO PARA PANTALLAS ANCHAS ---
            return _buildWideLayout(navItems);
          }
        },
      ),
    );
  }

  /// Construye el diseño para pantallas anchas (el original).
  Widget _buildWideLayout(List<Map<String, Object>> navItems) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: navItems.map((item) => _buildNavItem(
              icon: item['icon'] as IconData,
              label: item['label'] as String,
              index: item['index'] as int,
            )).toList(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _buildActionIcons(),
        ),
      ],
    );
  }

  /// Construye el diseño para pantallas pequeñas (con menú de hamburguesa).
  Widget _buildNarrowLayout(List<Map<String, Object>> navItems) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Menú de hamburguesa a la izquierda
        PopupMenuButton<int>(
          icon: const Icon(Icons.menu),
          tooltip: 'Menú de Navegación',
          onSelected: (int index) {
            if (index == 5) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DetectionScreen()));
            } else {
              widget.onItemSelected(index);
            }
          },
          itemBuilder: (context) {
            return navItems.map((item) {
              return PopupMenuItem<int>(
                value: item['index'] as int,
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 16),
                    Text(item['label'] as String),
                  ],
                ),
              );
            }).toList();
          },
        ),
        // Iconos de acción a la derecha
        _buildActionIcons(isNarrow: true),
      ],
    );
  }

  /// Widget para los botones de acción de la derecha (Tema, Perfil, Logout).
  Widget _buildActionIcons({bool isNarrow = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Cambiar Tema',
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          tooltip: 'Editar Perfil',
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            );
          },
        ),
        IconButton(
          tooltip: 'Cerrar Sesión',
          icon: const Icon(Icons.logout),
          onPressed: widget.onLogout,
        ),
        if (!isNarrow) const SizedBox(width: 20),
      ],
    );
  }

  /// Widget para cada item de navegación (sin cambios).
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

    final bool showText = isHovered || isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (index == 5) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DetectionScreen()));
          } else {
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
                child: showText
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