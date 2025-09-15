import 'package:flutter/material.dart';

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