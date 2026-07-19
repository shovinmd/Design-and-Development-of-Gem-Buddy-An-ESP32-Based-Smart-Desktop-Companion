import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';

class FloatingGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavBarItem(icon: Icons.home_rounded, label: 'Home'),
      _NavBarItem(icon: Icons.sports_esports_rounded, label: 'Control'),
      _NavBarItem(icon: Icons.shield_rounded, label: 'Security'),
      _NavBarItem(icon: Icons.menu_book_rounded, label: 'Guide'),
      _NavBarItem(icon: Icons.analytics_rounded, label: 'Timeline'),
      _NavBarItem(icon: Icons.settings_rounded, label: 'Settings'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.0),
          child: BackdropFilter(
            filter: GlassStyles.blurFilter,
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GemColors.accentBlue.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  
                  return GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 55,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? GemColors.accentBlue.withValues(alpha: 0.15) 
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: GemColors.accentBlue.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                            child: Icon(
                              item.icon,
                              color: isSelected 
                                  ? GemColors.accentBlue 
                                  : GemColors.textSecondary.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedScale(
                            scale: isSelected ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: GemColors.accentBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final String label;

  _NavBarItem({required this.icon, required this.label});
}
