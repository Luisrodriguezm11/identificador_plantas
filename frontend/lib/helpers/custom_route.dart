// frontend/lib/helpers/custom_route.dart
import 'package:flutter/material.dart';

// --- AÑADE ESTA NUEVA CLASE ---
class NoTransitionRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  NoTransitionRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          // Duración cero para una transición instantánea
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}
// --- FIN DE LA NUEVA CLASE ---

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;

  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0), // Empieza desde la derecha
                  end: Offset.zero, // Termina en el centro
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut, // Efecto de suavizado
                )),
                child: child,
              ),
          transitionDuration: const Duration(milliseconds: 300), // Duración
        );
}