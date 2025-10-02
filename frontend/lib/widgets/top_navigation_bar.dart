// frontend/lib/widgets/top_navigation_bar.dart
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
    // 2. OBTENEMOS LA INSTANCIA DEL THEME PROVIDER
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context); // Obtenemos el tema actual

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
      // El color de fondo y del texto ahora se adaptan al tema
      backgroundColor: theme.colorScheme.surface.withOpacity(0.1),
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: navItems.map((item) => _buildNavItem(
          icon: item['icon'] as IconData,
          label: item['label'] as String,
          index: item['index'] as int,
        )).toList(),
      ),
      actions: [
        // 3. AÑADIMOS EL BOTÓN PARA CAMBIAR EL TEMA
        IconButton(
          tooltip: 'Cambiar Tema',
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () {
            // Llamamos al método del provider para cambiar el tema
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
      automaticallyImplyLeading: false, // Para que no aparezca el botón de 'atrás'
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final theme = Theme.of(context);
    final bool isSelected = widget.selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;
    
    // 4. LOS COLORES AHORA DEPENDEN DEL TEMA
    final Color selectedColor = theme.colorScheme.primary;
    final Color defaultColor = theme.textTheme.bodyMedium?.color ?? Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onItemSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            // El color de fondo del item seleccionado también depende del tema
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
                            style: TextStyle(color: isSelected ? selectedColor : defaultColor),
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