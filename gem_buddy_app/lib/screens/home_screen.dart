import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_slide_transition.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _carouselTimer;
  int _currentImageIndex = 0;

  final List<String> _gemImages = const [
    'assets/images/gem_happy.jpg',
    'assets/images/gem_angry.jpg',
    'assets/images/gem_sad.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _gemImages.length;
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);
    final userSettings = ref.watch(settingsProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    // Dynamic greeting based on time of day
    final hour = DateTime.now().hour;
    String timeGreeting = "Day Mode ☀️";
    if (hour >= 18 && hour < 22) {
      timeGreeting = "Evening Relax 🌅";
    } else if (hour >= 22 || hour < 6) {
      timeGreeting = "Night Sleep 🌙";
    }

    String stateMessage = "I am feeling calm 😴";
    if (deviceState.faceMode == 5) {
      stateMessage = "I love your company! ❤️";
    } else if (deviceState.faceMode == 7) {
      stateMessage = "Reading pulse... 💓";
    } else if (deviceState.faceMode == 8) {
      stateMessage = "ALERT! Wake up! ⏰";
    } else if (deviceState.faceMode == 1) {
      stateMessage = "Ready to relax ☕";
    } else if (deviceState.faceMode == 0) {
      stateMessage = "I feel bright and active! ✨";
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              FadeSlideTransition(
                delay: Duration.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${userSettings.userName}',
                          style: GlassStyles.titleStyle.copyWith(
                            fontSize: 28, 
                            color: GemColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeGreeting,
                          style: GlassStyles.subtitleStyle.copyWith(
                            color: GemColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    // Connection Indicator Badge
                    _buildConnectionStatus(deviceState),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // BENTO GRID CARDS

              // 1. Gem Buddy Card (Large 3D Model Carousel)
              FadeSlideTransition(
                delay: const Duration(milliseconds: 150),
                child: GlassCard(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Carousel Display with Status Overlays
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 240,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: GemColors.accentBlue.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Image.asset(
                                _gemImages[_currentImageIndex],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: GemColors.bgSecondary,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      size: 48,
                                      color: GemColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Soft overlay telemetry bar at the bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        deviceState.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                        color: deviceState.isConnected ? GemColors.statusActive : GemColors.statusAlert,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        deviceState.isConnected ? 'Hardware Sync Active' : 'Offline Buddy Mode',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'LDR: ${(deviceState.ldrRaw / 40.95).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceState.deviceName,
                                style: const TextStyle(
                                  color: GemColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stateMessage,
                                style: TextStyle(
                                  color: GemColors.accentBlue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Action to simulate touch
                          if (deviceState.isSimulated)
                            IconButton(
                              icon: const Icon(Icons.touch_app_rounded, color: GemColors.accentPurple),
                              tooltip: 'Simulate Touch',
                              onPressed: () => deviceNotifier.triggerMockTouchAlert(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bento Row 1: Environment
              FadeSlideTransition(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    // 2. Environment Card
                    Expanded(
                      child: GlassCard(
                        height: 155,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.thermostat_rounded, color: GemColors.accentBlue, size: 22),
                                Icon(
                                  deviceState.ldrRaw > 1600 
                                      ? Icons.wb_sunny_rounded 
                                      : Icons.nightlight_round_rounded,
                                  color: GemColors.statusWarning,
                                  size: 18,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Light Level', style: TextStyle(color: GemColors.textSecondary, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  '${(deviceState.ldrRaw / 40.95).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: GemColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                // Progress indicator mapping LDR
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: deviceState.ldrRaw / 4095,
                                    backgroundColor: Colors.black.withValues(alpha: 0.05),
                                    valueColor: const AlwaysStoppedAnimation<Color>(GemColors.accentBlue),
                                    minHeight: 4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bento Row 2: Quick Actions & Device Status
              FadeSlideTransition(
                delay: const Duration(milliseconds: 450),
                child: Row(
                  children: [
                    // 4. Quick Action Card
                    Expanded(
                      child: GlassCard(
                        height: 160,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick Action', style: TextStyle(color: GemColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionItem(
                                    icon: Icons.wifi_find_rounded, 
                                    label: 'Find GEM',
                                    color: GemColors.accentPurple,
                                    onTap: () => deviceNotifier.findMyGem(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildActionItem(
                                    icon: Icons.sync_rounded, 
                                    label: 'Sync State',
                                    color: GemColors.accentBlue,
                                    onTap: () async {
                                      if (deviceState.isSimulated) {
                                        deviceNotifier.findMyGem(); // beep feedback
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🔄 Syncing settings with GEM...'),
                                            duration: Duration(milliseconds: 1000),
                                          ),
                                        );
                                        final err = await deviceNotifier.saveSettings(
                                          userName: userSettings.userName,
                                          deviceName: userSettings.deviceNickname,
                                          timezoneLabel: deviceState.timezoneLabel,
                                          timezoneOffsetMinutes: deviceState.timezoneOffsetMinutes,
                                        );
                                        await deviceNotifier.fetchDeviceState();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(err == null 
                                                  ? '✨ GEM successfully synced!' 
                                                  : '⚠️ Could not sync settings with GEM.'),
                                              backgroundColor: err == null 
                                                  ? GemColors.statusActive 
                                                  : GemColors.statusAlert,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // 5. Device Status Card
                    Expanded(
                      child: GlassCard(
                        height: 160,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.memory_rounded, color: GemColors.textSecondary, size: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'v1.0',
                                    style: TextStyle(color: GemColors.accentBlue, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Firmware Update', style: TextStyle(color: GemColors.textSecondary, fontSize: 11)),
                                const SizedBox(height: 4),
                                const Text(
                                    'Up to date',
                                    style: TextStyle(color: GemColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  deviceState.isSimulated 
                                      ? 'Simulated Mode' 
                                      : 'IP: ${deviceState.ipAddress}',
                                  style: const TextStyle(color: GemColors.textSecondary, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildConnectionStatus(DeviceState state) {
    final bool hotspotMode = state.hotspotActive || (state.hotspotEnabled && !state.wifiConnected);
    final String label = state.isSimulated
        ? 'SIMULATED'
        : hotspotMode
            ? 'HOTSPOT'
            : (state.isConnected ? 'ONLINE' : 'OFFLINE');
    final Color color = state.isSimulated
        ? GemColors.accentPurple
        : hotspotMode
            ? GemColors.accentBlue
            : (state.isConnected ? GemColors.statusActive : GemColors.statusAlert);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: GemColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
