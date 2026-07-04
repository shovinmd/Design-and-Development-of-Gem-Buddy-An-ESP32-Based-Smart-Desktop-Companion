import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.fillColor,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: GlassStyles.glassDecoration(
        radius: radius,
        color: fillColor ?? GemColors.glassWhite,
        borderColor: borderColor ?? GemColors.glassBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.02),
          child: cardContent,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: GlassStyles.blurFilter,
        child: cardContent,
      ),
    );
  }
}
