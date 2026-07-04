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
    final webhookController = TextEditingController(text: 'http://my-cloud-api.com/alert');

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
                            onChanged: (val) {
                              deviceNotifier.toggleBrokerGuardMode(val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: GemColors.glassBorder),
                      const SizedBox(height: 8),
                      const Text(
                        'When active, any touch triggers, movement, or light shifts will notify you immediately. If Wi-Fi is enabled, GEM sends HTTP webhook events.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 13, height: 1.4),
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

              // 3. CLOUD ALERTS & WEBHOOK CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 300),
                child: GlassCard(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_queue_rounded, color: GemColors.accentBlue, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Cloud API Dispatcher',
                            style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'SSID endpoint where the device will push HTTP POST notifications when alarm triggers are fired. Useful for smart home integrations.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: webhookController,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Webhook URL',
                          labelStyle: const TextStyle(color: GemColors.textSecondary, fontSize: 12),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: GemColors.accentBlue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.link_rounded, color: GemColors.textSecondary, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.04),
                            foregroundColor: GemColors.textPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: const Text('Save Dispatcher Webhook', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            deviceNotifier.saveSettings();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Webhook configuration updated locally.'),
                                backgroundColor: GemColors.bgSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
                            final battery = log['battery'] ?? 100;
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

                            if (event == 'shadow-detected') {
                              iconData = Icons.nights_stay_rounded;
                              iconColor = GemColors.statusAlert;
                              displayTitle = 'Intruder Shadow Detected';
                            } else if (event == 'flash-detected') {
                              iconData = Icons.flash_on_rounded;
                              iconColor = GemColors.statusWarning;
                              displayTitle = 'Sudden Flash Detected';
                            } else if (event == 'touch-down' || event == 'long-touch') {
                              iconData = Icons.touch_app_rounded;
                              iconColor = GemColors.accentPurple;
                              displayTitle = 'Physical Touch Intercept';
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
                                        'LDR: $ldr | Battery: $battery%',
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
