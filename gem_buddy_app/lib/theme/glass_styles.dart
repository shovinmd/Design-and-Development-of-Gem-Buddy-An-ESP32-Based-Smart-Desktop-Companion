import 'dart:ui';
import 'package:flutter/material.dart';
import 'colors.dart';

class GlassStyles {
  // Reusable backdrop blur filter
  static ImageFilter get blurFilter => ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0);

  // Gradient for the background of the entire app (Deep Space Black to Midnight Blue)
  static const BoxDecoration backgroundGradient = BoxDecoration(
    gradient: LinearGradient(
      colors: [
        GemColors.bgPrimary,
        Color(0xffedf3f9), // Middle soft pastel stop
        GemColors.bgSecondary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  // Glass Container decoration
  static BoxDecoration glassDecoration({
    double radius = 24.0,
    Color color = GemColors.glassWhite,
    Color borderColor = GemColors.glassBorder,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0f1e293b), // Extremely soft shadow for light theme
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: GemColors.accentBlue.withValues(alpha: 0.04),
          blurRadius: 30,
          offset: const Offset(0, 0),
          spreadRadius: 1,
        ),
      ],
    );
  }

  // Accent neon glow shadows
  static List<BoxShadow> neonGlow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.4),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.2),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // Common Text Styles
  static const TextStyle titleStyle = TextStyle(
    color: GemColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: GemColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: GemColors.textPrimary,
    fontSize: 16,
    height: 1.4,
  );

  static const TextStyle labelStyle = TextStyle(
    color: GemColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );
}
