import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_slide_transition.dart';
import '../providers/device_provider.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideTransition(
                delay: Duration.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desk Security', style: GlassStyles.titleStyle.copyWith(fontSize: 28, color: GemColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Active monitoring, environment guards & cloud alerts', style: GlassStyles.subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. MONITORING STATUS CARD (Large Bento)
              FadeSlideTransition(
                delay: const Duration(milliseconds: 100),
                child: GlassCard(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: deviceState.monitoringEnabled 
                                      ? GemColors.statusActive.withValues(alpha: 0.15) 
                                      : GemColors.statusAlert.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  deviceState.monitoringEnabled 
                                      ? Icons.security_rounded 
                                      : Icons.security_update_warning_rounded,
                                  color: deviceState.monitoringEnabled 
                                      ? GemColors.statusActive 
                                      : GemColors.statusAlert,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Guard Mode',
                                    style: TextStyle(color: GemColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    deviceState.monitoringEnabled ? 'Active Guarding ON' : 'Monitoring Disabled',
                                    style: TextStyle(
                                      color: deviceState.monitoringEnabled ? GemColors.statusActive : GemColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: deviceState.monitoringEnabled,
                            activeColor: GemColors.statusActive,
                            activeTrackColor: GemColors.statusActive.withValues(alpha: 0.3),
                            inactiveThumbColor: GemColors.textSecondary,
                            inactiveTrackColor: Colors.black.withValues(alpha: 0.05),
                            onChanged: (val) async {
                              if (val && !deviceState.deviceOnline && !deviceState.isSimulated) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot enable Guard Mode. Device is offline!'),
                                    backgroundColor: GemColors.statusAlert,
                                  )
                                );
                                return;
                              }
                              final error = await deviceNotifier.toggleBrokerGuardMode(val);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Guard Mode error: $error'),
                                    backgroundColor: GemColors.statusAlert,
                                  )
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: GemColors.glassBorder),
                      const SizedBox(height: 12),
                      // Live ping status row
                      Row(
                        children: [
                          // Device ping status
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: deviceState.deviceOnline
                                    ? GemColors.statusActive.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: deviceState.deviceOnline
                                      ? GemColors.statusActive.withValues(alpha: 0.3)
                                      : GemColors.glassBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.router_rounded,
                                    size: 14,
                                    color: deviceState.deviceOnline ? GemColors.statusActive : GemColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Device', style: TextStyle(color: GemColors.textSecondary, fontSize: 10)),
                                      Text(
                                        deviceState.deviceOnline ? 'Online ●' : 'Offline ○',
                                        style: TextStyle(
                                          color: deviceState.deviceOnline ? GemColors.statusActive : GemColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // App ping status
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: deviceState.appOnline
                                    ? GemColors.accentBlue.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: deviceState.appOnline
                                      ? GemColors.accentBlue.withValues(alpha: 0.3)
                                      : GemColors.glassBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.phone_android_rounded,
                                    size: 14,
                                    color: deviceState.appOnline ? GemColors.accentBlue : GemColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('App', style: TextStyle(color: GemColors.textSecondary, fontSize: 10)),
                                      Text(
                                        deviceState.appOnline ? 'Connected ●' : 'Offline ○',
                                        style: TextStyle(
                                          color: deviceState.appOnline ? GemColors.accentBlue : GemColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 10),
                      const Text(
                        'When active, any touch, movement, or light shift will alert you instantly. GEM pings the broker every 30s so you always know it\'s alive.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 12, height: 1.4),
                      ),

                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. BENTO ROW: GUARD CRITERIA
              FadeSlideTransition(
                delay: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    // Guard Rule A: Touch Alert
                    Expanded(
                      child: GlassCard(
                        height: 150,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.touch_app_rounded, color: GemColors.accentPurple, size: 22),
                                Icon(Icons.check_circle_rounded, color: GemColors.statusActive, size: 16),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Touch Alarm', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'Detect touch on the GEM body casing.',
                                  style: TextStyle(color: GemColors.textSecondary.withValues(alpha: 0.8), fontSize: 11, height: 1.2),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Guard Rule B: Light Change Alert
                    Expanded(
                      child: GlassCard(
                        height: 150,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.light_mode_rounded, color: GemColors.statusWarning, size: 22),
                                Icon(Icons.check_circle_rounded, color: GemColors.statusActive, size: 16),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Light Drop Alert', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'Detect if LDR value drops below 1600.',
                                  style: TextStyle(color: GemColors.textSecondary.withValues(alpha: 0.8), fontSize: 11, height: 1.2),
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
              const SizedBox(height: 20),

              // 4. REAL-TIME INCIDENT LOG CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 400),
                child: GlassCard(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.list_alt_rounded, color: GemColors.statusActive, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Security Incident Log',
                                style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded, color: GemColors.textSecondary, size: 20),
                                onPressed: () => deviceNotifier.fetchSecurityLogs(),
                                tooltip: 'Refresh Logs',
                              ),
                              if (deviceState.securityLogs.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_rounded, color: GemColors.statusAlert, size: 20),
                                  onPressed: () => deviceNotifier.clearSecurityLogs(),
                                  tooltip: 'Clear Logs',
                                ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (deviceState.securityLogs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(Icons.verified_user_rounded, color: GemColors.statusActive.withValues(alpha: 0.3), size: 48),
                                const SizedBox(height: 10),
                                const Text(
                                  'System Secured',
                                  style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'No intrusion events detected on Desk Guard.',
                                  style: TextStyle(color: GemColors.textSecondary, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: deviceState.securityLogs.length,
                          separatorBuilder: (context, index) => const Divider(color: GemColors.glassBorder, height: 16),
                          itemBuilder: (context, index) {
                            final log = deviceState.securityLogs[index];
                            final event = log['event'] ?? 'unknown';
                            final timestampStr = log['timestamp'] ?? '';
                            final ldr = log['ldr'] ?? 2048;

                            // Format timestamp nicely
                            String formattedTime = '';
                            try {
                              final dt = DateTime.parse(timestampStr).toLocal();
                              final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                              final minute = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
                              final second = dt.second < 10 ? '0${dt.second}' : '${dt.second}';
                              final period = dt.hour >= 12 ? 'PM' : 'AM';
                              formattedTime = '$hour:$minute:$second $period';
                            } catch (_) {
                              formattedTime = timestampStr;
                            }

                            IconData iconData = Icons.info_outline;
                            Color iconColor = GemColors.textSecondary;
                            String displayTitle = event;
                            String displaySubtitle = 'Light level: $ldr';

                            if (event == 'shadow-detected') {
                              iconData = Icons.nights_stay_rounded;
                              iconColor = GemColors.statusAlert;
                              displayTitle = 'Intruder Shadow Detected';
                              displaySubtitle = 'Light suddenly dropped — LDR reading: $ldr';
                            } else if (event == 'flash-detected') {
                              iconData = Icons.flash_on_rounded;
                              iconColor = GemColors.statusWarning;
                              displayTitle = 'Sudden Flash / Light Spike';
                              displaySubtitle = 'Unexpected bright light detected — LDR reading: $ldr';
                            } else if (event == 'touch-down' || event == 'long-touch' || event == 'touch-detected') {
                              iconData = Icons.touch_app_rounded;
                              iconColor = GemColors.accentPurple;
                              displayTitle = event == 'long-touch'
                                  ? 'Sustained Touch Detected'
                                  : 'Physical Touch Intercept';
                              displaySubtitle = 'GEM body was physically touched — LDR: $ldr';
                            } else if (event == 'alarm' || event == 'alarm-dismissed') {
                              iconData = event == 'alarm' ? Icons.alarm_rounded : Icons.alarm_on_rounded;
                              iconColor = event == 'alarm' ? GemColors.statusAlert : GemColors.statusActive;
                              displayTitle = event == 'alarm' ? 'Alarm/Reminder Triggered' : 'Alarm Dismissed';
                              displaySubtitle = event == 'alarm'
                                  ? 'A scheduled reminder is ringing on GEM.'
                                  : 'Reminder dismissed by user action.';
                            } else if (event == 'guard-enabled' || event == 'guard-disabled') {
                              iconData = event == 'guard-enabled' ? Icons.shield_rounded : Icons.shield_outlined;
                              iconColor = event == 'guard-enabled' ? GemColors.statusActive : GemColors.textSecondary;
                              displayTitle = event == 'guard-enabled' ? 'Guard Mode Active' : 'Guard Mode Inactive';
                              final toggler = log['device'] ?? 'system';
                              displaySubtitle = 'Toggled by $toggler.';
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle,
                                        style: const TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displaySubtitle,
                                        style: const TextStyle(color: GemColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(color: GemColors.textSecondary, fontSize: 10),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
