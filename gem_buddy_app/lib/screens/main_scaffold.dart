import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/floating_glass_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import 'home_screen.dart';
import 'control_screen.dart';
import 'security_screen.dart';
import 'timeline_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    ControlScreen(),
    SecurityScreen(),
    TimelineScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);
    final userSettings = ref.watch(settingsProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    // Auto dismiss notification banner after a delay
    if (deviceState.lastNotificationMessage != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && ref.read(deviceProvider).lastNotificationMessage != null) {
          deviceNotifier.clearNotification();
        }
      });
    }

    final bool showOnboarding = !userSettings.setupComplete;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: GlassStyles.backgroundGradient,
          ),
          
          // Pages Content
          Positioned.fill(
            child: showOnboarding 
                ? const OnboardingScreen()
                : IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
          ),

          // Floating Glass Bottom Navigation Bar
          if (!showOnboarding)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingGlassNavBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),

          // Glass Active Notification Banner (Local Alerts)
          if (deviceState.lastNotificationMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: deviceState.lastNotificationMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: SlideInNotification(
                  message: deviceState.lastNotificationMessage!,
                  onDismiss: () => deviceNotifier.clearNotification(),
                  onAction: deviceState.activeAlarmIndex != 255 
                      ? () => deviceNotifier.dismissAlarm() 
                      : null,
                  actionLabel: deviceState.activeAlarmIndex != 255 ? 'DISMISS' : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SlideInNotification extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SlideInNotification({
    super.key,
    required this.message,
    required this.onDismiss,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      radius: 20,
      fillColor: Colors.black.withValues(alpha: 0.6),
      borderColor: GemColors.accentBlue.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(
            message.contains('Alarm') ? Icons.alarm_rounded : Icons.info_outline_rounded,
            color: message.contains('Alarm') ? GemColors.statusAlert : GemColors.accentBlue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: GemColors.statusActive,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
            onPressed: onDismiss,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
