import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../providers/timeline_provider.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(timelineProvider);
    final timelineNotifier = ref.read(timelineProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GEM History', style: GlassStyles.titleStyle.copyWith(fontSize: 28, color: GemColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Logs of sensor updates & alarms', style: GlassStyles.subtitleStyle),
                    ],
                  ),
                  if (logs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: GemColors.statusAlert),
                      tooltip: 'Clear History',
                      onPressed: () {
                        _showClearConfirmation(context, timelineNotifier);
                      },
                    ),
                ],
              ),
            ),

            // Scrollable Timeline Logs
            Expanded(
              child: logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 100.0),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final isLast = index == logs.length - 1;
                        return _buildTimelineItem(log, isLast);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.black.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          const Text(
            'Timeline is Empty',
            style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Updates will appear here as they occur.',
            style: TextStyle(color: GemColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineLog log, bool isLast) {
    IconData icon = Icons.info_outline_rounded;
    Color color = GemColors.accentBlue;

    switch (log.type) {
      case 'heart':
        icon = Icons.favorite_rounded;
        color = GemColors.statusAlert;
        break;
      case 'alarm':
        icon = Icons.alarm_rounded;
        color = GemColors.statusWarning;
        break;
      case 'touch':
        icon = Icons.touch_app_rounded;
        color = GemColors.accentPurple;
        break;
      case 'security':
        icon = Icons.shield_rounded;
        color = GemColors.statusActive;
        break;
      case 'system':
        icon = Icons.settings_rounded;
        color = GemColors.accentBlue;
        break;
    }

    final formattedTime = DateFormat('MMM dd, hh:mm a').format(log.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator line
          Column(
            children: [
              // Glowing dot
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              // Connecting line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                log.title,
                                style: const TextStyle(
                                  color: GemColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  color: GemColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            log.message,
                            style: TextStyle(
                              color: GemColors.textSecondary.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, TimelineNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GemColors.bgPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: GemColors.glassBorder)),
        title: const Text('Clear Logs', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to flush all system logs? This action is irreversible.', style: TextStyle(color: GemColors.textSecondary)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: GemColors.textSecondary)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.statusAlert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Flush Logs', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              notifier.clearLogs();
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
