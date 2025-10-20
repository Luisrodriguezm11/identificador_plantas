// frontend/lib/widgets/disclaimer_widget.dart

import 'package:flutter/material.dart';
import 'dart:ui';

class DisclaimerWidget extends StatelessWidget {
  const DisclaimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: (isDark ? Colors.orange.shade900 : Colors.amber.shade200).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: (isDark ? Colors.orange.shade800 : Colors.amber.shade400).withOpacity(0.6),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descargo de Responsabilidad',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los diagnósticos y recomendaciones proporcionados por esta aplicación son generados por un modelo de inteligencia artificial y deben ser considerados únicamente como una guía preliminar. La precisión no está garantizada. Para decisiones críticas, consulte siempre a un ingeniero agrónomo o un profesional certificado.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}