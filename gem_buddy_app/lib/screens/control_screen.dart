import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_slide_transition.dart';
import '../providers/device_provider.dart';

class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

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
                    Text('Control Panel', style: GlassStyles.titleStyle.copyWith(fontSize: 28, color: GemColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Lamp presets and hardware alarms', style: GlassStyles.subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. LED LAMP CONTROL CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 150),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, color: GemColors.accentBlue, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'LED Glow Lamp',
                                style: TextStyle(color: GemColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Switch(
                            value: deviceState.lampState,
                            activeColor: GemColors.accentBlue,
                            activeTrackColor: GemColors.accentBlue.withValues(alpha: 0.3),
                            inactiveThumbColor: GemColors.textSecondary,
                            inactiveTrackColor: Colors.black.withValues(alpha: 0.05),
                            onChanged: (val) {
                              deviceNotifier.saveSettings(lampState: val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Brightness slider
                      const Text('Brightness', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                      Row(
                        children: [
                          const Icon(Icons.brightness_low_rounded, color: GemColors.textSecondary, size: 18),
                          Expanded(
                            child: Slider(
                              value: deviceState.lampBrightness.toDouble(),
                              min: 0,
                              max: 255,
                              activeColor: GemColors.accentBlue,
                              inactiveColor: Colors.black.withValues(alpha: 0.05),
                              onChanged: deviceState.lampState 
                                  ? (val) => deviceNotifier.saveSettings(lampBrightness: val.toInt())
                                  : null,
                            ),
                          ),
                          const Icon(Icons.brightness_high_rounded, color: GemColors.textSecondary, size: 18),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Effect presets
                      const Text('Glow Effect Preset', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      _buildEffectPresets(deviceState, deviceNotifier),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 20),
              // 3. REMINDER MANAGER CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 450),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Device Reminders', style: TextStyle(color: GemColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              '${deviceState.alarms.length}/6 configured',
                              style: const TextStyle(color: GemColors.textSecondary, fontSize: 12),
                            ),
                            if (deviceState.alarms.length < 6) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, color: GemColors.accentBlue, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showAddReminderDialog(context, ref),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Map reminders list
                    if (deviceState.alarms.isEmpty)
                      const GlassCard(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No reminders synced. Tap + to add one.', style: TextStyle(color: GemColors.textSecondary)),
                          ),
                        ),
                      )
                    else
                      ...List.generate(deviceState.alarms.length, (index) {
                        final alarm = deviceState.alarms[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.alarm_rounded, 
                                  color: alarm.enabled ? GemColors.accentBlue : GemColors.textSecondary,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alarm.name,
                                        style: TextStyle(
                                          color: alarm.enabled ? GemColors.textPrimary : GemColors.textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(alarm.hour, alarm.minute),
                                        style: const TextStyle(color: GemColors.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit Reminder button
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: GemColors.textSecondary, size: 20),
                                  onPressed: () => _showEditReminderDialog(context, ref, index, alarm),
                                ),
                                // Delete Reminder button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: GemColors.statusAlert, size: 20),
                                  onPressed: () {
                                    final updatedList = List<GemAlarm>.from(deviceState.alarms);
                                    updatedList.removeAt(index);
                                    deviceNotifier.saveSettings(alarms: updatedList);
                                  },
                                ),
                                Switch(
                                  value: alarm.enabled,
                                  activeColor: GemColors.accentBlue,
                                  activeTrackColor: GemColors.accentBlue.withValues(alpha: 0.3),
                                  inactiveThumbColor: GemColors.textSecondary,
                                  inactiveTrackColor: Colors.black.withValues(alpha: 0.05),
                                  onChanged: (val) {
                                    final updatedList = List<GemAlarm>.from(deviceState.alarms);
                                    updatedList[index] = alarm.copyWith(enabled: val);
                                    deviceNotifier.saveSettings(alarms: updatedList);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEffectPresets(DeviceState state, DeviceNotifier notifier) {
    final modes = [
      _PresetMode(id: 0, label: 'Static', icon: Icons.filter_hdr_rounded),
      _PresetMode(id: 1, label: 'Breathe', icon: Icons.air_rounded),
      _PresetMode(id: 3, label: 'Pulse', icon: Icons.bolt_rounded),
      _PresetMode(id: 2, label: 'Blink', icon: Icons.flare_rounded),
    ];

    return Row(
      children: modes.map((m) {
        final isSelected = state.lampMode == m.id;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: state.lampState 
                  ? () => notifier.saveSettings(lampMode: m.id)
                  : null,
              child: Opacity(
                opacity: state.lampState ? 1.0 : 0.4,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? GemColors.accentBlue.withValues(alpha: 0.12) 
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected 
                          ? GemColors.accentBlue.withValues(alpha: 0.5) 
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(m.icon, color: isSelected ? GemColors.accentBlue : GemColors.textSecondary, size: 20),
                      const SizedBox(height: 6),
                      Text(
                        m.label,
                        style: TextStyle(
                          color: isSelected ? GemColors.textPrimary : GemColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final formattedMinute = minute < 10 ? '0$minute' : '$minute';
    return '$formattedHour:$formattedMinute $suffix';
  }

  void _showAddReminderDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: GemColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: GemColors.glassBorder)),
              title: const Text('Add Reminder', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: GemColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Reminder Label',
                      labelStyle: const TextStyle(color: GemColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: GemColors.accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time:', style: TextStyle(color: GemColors.textPrimary)),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time_rounded, color: GemColors.accentBlue),
                        label: Text(
                          selectedTime.format(context),
                          style: const TextStyle(color: GemColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: GemColors.textSecondary)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GemColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final deviceState = ref.read(deviceProvider);
                    final deviceNotifier = ref.read(deviceProvider.notifier);

                    final updatedList = List<GemAlarm>.from(deviceState.alarms);
                    updatedList.add(GemAlarm(
                      name: nameController.text.trim().isEmpty ? 'Reminder' : nameController.text,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      enabled: true,
                    ));

                    deviceNotifier.saveSettings(alarms: updatedList);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditReminderDialog(BuildContext context, WidgetRef ref, int index, GemAlarm alarm) {
    final nameController = TextEditingController(text: alarm.name);
    TimeOfDay selectedTime = TimeOfDay(hour: alarm.hour, minute: alarm.minute);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: GemColors.bgPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: GemColors.glassBorder)),
              title: const Text('Edit Reminder', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: GemColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Reminder Label',
                      labelStyle: const TextStyle(color: GemColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: GemColors.accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time:', style: TextStyle(color: GemColors.textPrimary)),
                      TextButton.icon(
                        icon: const Icon(Icons.access_time_rounded, color: GemColors.accentBlue),
                        label: Text(
                          selectedTime.format(context),
                          style: const TextStyle(color: GemColors.accentBlue, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setDialogState(() {
                              selectedTime = time;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: GemColors.textSecondary)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GemColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final deviceState = ref.read(deviceProvider);
                    final deviceNotifier = ref.read(deviceProvider.notifier);

                    final updatedList = List<GemAlarm>.from(deviceState.alarms);
                    updatedList[index] = GemAlarm(
                      name: nameController.text.trim().isEmpty ? 'Reminder' : nameController.text,
                      hour: selectedTime.hour,
                      minute: selectedTime.minute,
                      enabled: true, // Auto enable on update
                    );

                    deviceNotifier.saveSettings(alarms: updatedList);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PresetMode {
  final int id;
  final String label;
  final IconData icon;

  _PresetMode({required this.id, required this.label, required this.icon});
}
