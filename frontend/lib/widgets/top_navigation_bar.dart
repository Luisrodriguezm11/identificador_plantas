// frontend/lib/widgets/top_navigation_bar.dart
import 'package:flutter/material.dart';

// 1. Convertimos el widget a StatefulWidget para manejar el estado del hover.
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
  // 2. Variable de estado para saber qué ítem está sobrevolado.
  // Será 'null' si el ratón no está sobre ningún ítem.
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    // Definimos los ítems de navegación
    final navItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'index': 0},
      {'icon': Icons.history_outlined, 'label': 'Historial', 'index': 1},
      {'icon': Icons.delete_sweep_outlined, 'label': 'Papelera', 'index': 2},
      {'icon': Icons.calculate_outlined, 'label': 'Tratamientos', 'index': 3},
    ];

    final adminItem = {'icon': Icons.admin_panel_settings_outlined, 'label': 'Panel Admin', 'index': 4};
    final logoutItem = {'icon': Icons.logout, 'label': 'Cerrar Sesión', 'index': 5};

    // Construimos la lista de widgets que irán en el centro
    List<Widget> navigationWidgets = [
      ...navItems.map((item) => _buildNavItem(
        icon: item['icon'] as IconData,
        label: item['label'] as String,
        index: item['index'] as int,
      )),
      if (widget.isAdmin)
        _buildNavItem(
          icon: adminItem['icon'] as IconData,
          label: adminItem['label'] as String,
          index: adminItem['index'] as int,
        ),
      const SizedBox(width: 24), // Espaciador antes de logout
      _buildNavItem(
        icon: logoutItem['icon'] as IconData,
        label: logoutItem['label'] as String,
        index: logoutItem['index'] as int,
      ),
    ];

    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.1),
      elevation: 0,
      // 3. Usamos la propiedad `title` para centrar el contenido.
      // El `title` de un AppBar se centra por defecto.
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: navigationWidgets,
      ),
      // Dejamos el título original por si lo necesitas en el futuro, pero lo deshabilitamos.
      // title: const Text("Identificador de Plagas"),
    );
  }

  // 4. Widget para construir cada ítem de navegación con la animación
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final bool isSelected = widget.selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;

    // 5. Usamos MouseRegion para detectar cuándo el ratón entra o sale del área del widget.
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (index == 5) {
            widget.onLogout();
          } else {
            widget.onItemSelected(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white),
              // 6. Usamos AnimatedSwitcher para la animación del texto.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Animación de fade y tamaño
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: isHovered
                    // Si está sobrevolado, muestra el texto con un SizedBox de espacio
                    ? Row(
                        key: ValueKey('text_$label'), // Key para que la animación funcione
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white),
                          ),
                        ],
                      )
                    // Si no, muestra un widget vacío
                    : SizedBox.shrink(key: ValueKey('icon_$label')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}