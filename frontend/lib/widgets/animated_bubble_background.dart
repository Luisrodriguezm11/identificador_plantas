import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

// --- CLASE PARA CADA BURBUJA ---
class Bubble {
  final Color color;
  final double size;
  late Offset position;
  final double speed;
  final int direction;

  Bubble({
    required this.color,
    required this.size,
    required this.position,
    required this.speed,
    required this.direction,
  });
}

// --- WIDGET PRINCIPAL DEL FONDO ANIMADO ---
class AnimatedBubbleBackground extends StatefulWidget {
  const AnimatedBubbleBackground({Key? key}) : super(key: key);
  @override
  _AnimatedBubbleBackgroundState createState() => _AnimatedBubbleBackgroundState();
}

class _AnimatedBubbleBackgroundState extends State<AnimatedBubbleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Bubble> _bubbles;
  final int numberOfBubbles = 15;
  final Random _random = Random();
  
  // Usamos un bool para evitar reinicializar las burbujas en cada build
  bool _bubblesInitialized = false;

  @override
  void initState() {
    super.initState();
    _bubbles = [];
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- INICIALIZACIÓN DE LAS BURBUJAS (AHORA DEPENDE DEL TEMA) ---
  void _initializeBubbles(Size size, bool isDarkMode) {
    if (_bubblesInitialized) return; // Solo se inicializa una vez
    
    // 👇 PALETAS DE COLORES CONDICIONALES
    List<Color> lightThemeColors = [
      Colors.lightBlue.withOpacity(0.1),
      Colors.cyanAccent.withOpacity(0.1),
      Colors.purple.withOpacity(0.08),
      Colors.indigo.withOpacity(0.07),
      Colors.tealAccent.withOpacity(0.09),
    ];
    
    List<Color> darkThemeColors = [
      Colors.lightBlueAccent.withOpacity(0.1),
      Colors.pinkAccent.withOpacity(0.1),
      Colors.tealAccent.withOpacity(0.08),
      Colors.amberAccent.withOpacity(0.07),
      Colors.purpleAccent.withOpacity(0.09),
    ];

    final colors = isDarkMode ? darkThemeColors : lightThemeColors;

    for (int i = 0; i < numberOfBubbles; i++) {
      _bubbles.add(
        Bubble(
          color: colors[_random.nextInt(colors.length)],
          size: _random.nextDouble() * 200 + 50,
          position: Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height),
          speed: _random.nextDouble() * 0.2 + 0.05,
          direction: _random.nextBool() ? 1 : -1,
        ),
      );
    }
    _bubblesInitialized = true;
  }

  // --- ACTUALIZACIÓN DE POSICIONES ---
  void _updateBubblePositions(Size size) {
    // (Esta función no necesita cambios)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (var bubble in _bubbles) {
          bubble.position = Offset(bubble.position.dx + (bubble.speed * bubble.direction), bubble.position.dy);
          if (bubble.direction == 1 && bubble.position.dx > size.width + bubble.size) {
            bubble.position = Offset(-bubble.size, _random.nextDouble() * size.height);
          } else if (bubble.direction == -1 && bubble.position.dx < -bubble.size) {
            bubble.position = Offset(size.width + bubble.size, _random.nextDouble() * size.height);
          }
        }
      });
    });
  }

  // --- CONSTRUCCIÓN DEL WIDGET (AHORA DEPENDE DEL TEMA) ---
  @override
  Widget build(BuildContext context) {
    // 👇 1. DETECTAMOS EL TEMA ACTUAL
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 👇 2. DEFINIMOS LOS GRADIENTES PARA CADA TEMA
    final gradientColors = isDarkMode
        ? [const Color(0xFF232a49), const Color(0xFF0f1227)] // Gradiente oscuro
        : [const Color(0xFFFFFFFF), const Color(0xFFdfe9f3)]; // Gradiente claro

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _initializeBubbles(size, isDarkMode); // Pasamos el tema a la inicialización

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            _updateBubblePositions(size);

            return Stack(
              children: [
                // Fondo con gradiente dinámico
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                    ),
                  ),
                ),
                
                // Burbujas (su color ya fue definido en la inicialización)
                ..._bubbles.map((bubble) {
                  return Positioned(
                    left: bubble.position.dx - bubble.size / 2,
                    top: bubble.position.dy - bubble.size / 2,
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          width: bubble.size,
                          height: bubble.size,
                          decoration: BoxDecoration(
                            color: bubble.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }
}