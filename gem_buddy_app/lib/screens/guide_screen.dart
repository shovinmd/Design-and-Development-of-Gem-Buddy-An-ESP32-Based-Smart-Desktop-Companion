import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_slide_transition.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _guideItems
        .where((item) =>
            _searchQuery.isEmpty ||
            item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.steps.any((s) => s.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: FadeSlideTransition(
                delay: Duration.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Guide',
                      style: GlassStyles.titleStyle
                          .copyWith(fontSize: 28, color: GemColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Everything you need to know about your GEM',
                      style: GlassStyles.subtitleStyle,
                    ),
                    const SizedBox(height: 16),

                    // ── Search Field ───────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: GemColors.bgSecondary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: GemColors.glassBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            color: GemColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search features, tips…',
                          hintStyle: const TextStyle(
                              color: GemColors.textSecondary, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: GemColors.accentBlue, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      color: GemColors.textSecondary, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 4),
                        ),
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${filtered.length} feature${filtered.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                          color: GemColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // ── Guide List ───────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isExpanded = _expandedIndex == index;
                        return FadeSlideTransition(
                          delay: Duration(milliseconds: index * 40),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _GuideCard(
                              item: item,
                              isExpanded: isExpanded,
                              searchQuery: _searchQuery,
                              onTap: () => setState(() {
                                _expandedIndex = isExpanded ? null : index;
                              }),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 52,
              color: GemColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No results found',
              style: TextStyle(
                  color: GemColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Try a different keyword',
              style: TextStyle(
                  color: GemColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Guide Card ──────────────────────────────────────────────────────────────
class _GuideCard extends StatelessWidget {
  final _GuideItem item;
  final bool isExpanded;
  final String searchQuery;
  final VoidCallback onTap;

  const _GuideCard({
    required this.item,
    required this.isExpanded,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: isExpanded
          ? item.color.withValues(alpha: 0.5)
          : GemColors.glassBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Header Row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightText(
                          text: item.title,
                          query: searchQuery,
                          style: const TextStyle(
                            color: GemColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                              color: GemColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: GemColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),

            // ── Expandable Steps ───────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color: item.color.withValues(alpha: 0.2), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...item.steps.asMap().entries.map((e) {
                          final stepNum = e.key + 1;
                          final step = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: item.color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$stepNum',
                                      style: TextStyle(
                                        color: item.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HighlightText(
                                    text: step,
                                    query: searchQuery,
                                    style: const TextStyle(
                                      color: GemColors.textPrimary,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (item.tip != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: GemColors.statusActive
                                  .withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: GemColors.statusActive
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline_rounded,
                                    color: GemColors.statusActive, size: 15),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.tip!,
                                    style: const TextStyle(
                                      color: GemColors.statusActive,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Highlight matching text ──────────────────────────────────────────────────
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(
            backgroundColor: Color(0x55FFD700),
            color: GemColors.textPrimary,
            fontWeight: FontWeight.bold),
      ));
      start = idx + query.length;
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }
}

// ── Data Model ───────────────────────────────────────────────────────────────
class _GuideItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final String? tip;

  const _GuideItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.steps,
    this.tip,
  });
}

// ── Guide Content ─────────────────────────────────────────────────────────────
const List<_GuideItem> _guideItems = [
  _GuideItem(
    title: 'First-Time Setup',
    subtitle: 'Connect your GEM device to the app',
    icon: Icons.wifi_tethering_rounded,
    color: GemColors.accentBlue,
    steps: [
      'Power on your GEM device by connecting it via USB or the battery.',
      'On first boot, GEM will host a Wi-Fi hotspot named "GEM-Setup" (password: 12345678).',
      'Connect your phone to the "GEM-Setup" Wi-Fi network.',
      'Open the GEM companion app and tap "Connect to Device" on the onboarding screen.',
      'Enter your name, a device nickname, and your home Wi-Fi credentials in Settings.',
      'Tap "Save & Sync" — GEM will connect to your home Wi-Fi and restart.',
      'The app will auto-detect GEM on your local network from now on.',
    ],
    tip: 'If GEM cannot find your network, make sure you are using a 2.4 GHz Wi-Fi band, not 5 GHz.',
  ),
  _GuideItem(
    title: 'Lamp / LED Control',
    subtitle: 'Turn on, adjust brightness, and set modes',
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFFFC107),
    steps: [
      'Go to the "Controls" tab in the bottom navigation bar.',
      'Use the "Lamp Control" toggle to turn the LED ring ON or OFF.',
      'Drag the brightness slider to set the light intensity (1–100%).',
      'Choose a lamp mode: Static (solid), Breathing (fade in/out), or Flash (alert strobe).',
      'Tap any preset card (Focus, Relax, Night, etc.) to instantly apply a preset configuration.',
      'You can also toggle the lamp from GEM\'s physical menu — hold the device body and select "Lamp Control".',
    ],
    tip: 'The lamp turns off automatically when it detects ambient light (LDR auto mode).',
  ),
  _GuideItem(
    title: 'Setting Alarms & Reminders',
    subtitle: 'Schedule reminders that trigger on GEM',
    icon: Icons.alarm_rounded,
    color: Color(0xFFFF5722),
    steps: [
      'Go to the "Controls" tab and scroll to the "Reminder Manager" card.',
      'Tap the "+ Add Alarm" button and enter a time and label (e.g. "Take Meds").',
      'Toggle the alarm ON and tap Save — the alarm is synced to GEM.',
      'At the set time, GEM will play a tone, flash the LED, and show the alarm name on screen.',
      'To dismiss the alarm from the physical device, long-press the touch sensor on GEM\'s body.',
      'To dismiss from the app, tap the DISMISS button on the notification banner.',
    ],
    tip: 'Make sure GEM is connected to Wi-Fi and the time is synced (NTP) for alarms to trigger on time.',
  ),
  _GuideItem(
    title: 'Desk Guard (Security Mode)',
    subtitle: 'Protect your desk from touch or light intrusion',
    icon: Icons.security_rounded,
    color: GemColors.statusActive,
    steps: [
      'Go to the "Security" tab in the bottom navigation bar.',
      'Toggle "Guard Mode" ON — GEM must be connected to Wi-Fi and the security broker for this.',
      'When active, any physical touch on GEM\'s body or a sudden drop/rise in light (LDR) will trigger an alert.',
      'The alert is sent to your broker and pushed to the app instantly via WebSocket.',
      'View all incidents in the "Security Incident Log" card below — each entry shows the event type, LDR reading, and timestamp.',
      'To clear logs, tap the trash icon next to the log header.',
      'To disable Guard Mode, toggle the switch OFF or long-press the GEM body and select "Guard Mode" from the menu.',
    ],
    tip: 'Connect a cloud broker URL in Settings → Security Broker to receive alerts even when away from home Wi-Fi.',
  ),
  _GuideItem(
    title: 'Heart Rate / Pulse Scan',
    subtitle: 'View a live pulse waveform on GEM\'s OLED',
    icon: Icons.monitor_heart_rounded,
    color: Color(0xFFE91E63),
    steps: [
      'On GEM\'s physical menu (short-press the touch sensor to open), select "Heart Rate".',
      'Place your fingertip gently on the MAX30102 pulse sensor on GEM\'s top surface.',
      'The OLED screen will display a live scrolling PPG waveform — the graph height reflects your pulse signal strength.',
      'The LED ring pulses in sync with the signal amplitude for visual feedback.',
      'To exit, long-press the touch sensor on GEM\'s body.',
    ],
    tip: 'Hold your finger still and apply gentle pressure for the clearest waveform. Finger movement causes noise.',
  ),
  _GuideItem(
    title: 'GEM\'s Mood & Personality',
    subtitle: 'Eye animations, greetings, and companion moods',
    icon: Icons.emoji_emotions_rounded,
    color: Color(0xFF9C27B0),
    steps: [
      'GEM displays animated eye expressions on its OLED screen reflecting its current mode.',
      'Day Mode: wide open happy eyes with a "Good day!" speech bubble greeting.',
      'Evening Mode: softer eyes with a "Ready to relax" bubble.',
      'Sleep / Night Mode: droopy sleep-arc eyes with "Have a good sleep" message and floating Zzz animations.',
      'Pet / Friend Mode: heart-eyes with floating hearts and a greeting bubble.',
      'Alarm Mode: full-screen reminder card with the alarm name and current time.',
      'GEM greets you periodically — it looks left, right, then centers before showing a speech bubble.',
    ],
    tip: 'GEM\'s mood changes automatically based on the time of day. You can also see the face mirrored in the companion app\'s home screen.',
  ),
  _GuideItem(
    title: 'OTA Firmware Update',
    subtitle: 'Update GEM\'s firmware wirelessly via the app',
    icon: Icons.system_update_rounded,
    color: GemColors.accentBlue,
    steps: [
      'Make sure GEM is connected to your home Wi-Fi (not hotspot mode).',
      'Go to the "Settings" tab and scroll to "Firmware Update".',
      'Tap "Flash Firmware to GEM" — the app will push the bundled firmware.bin to the device via HTTP OTA.',
      'A progress indicator will appear. Do not close the app or power off GEM during this process.',
      'GEM will reboot automatically once the update is complete.',
      'You can verify the firmware version in Settings → About GEM after the reboot.',
    ],
    tip: 'Keep GEM plugged in during OTA updates to avoid power interruption.',
  ),
  _GuideItem(
    title: 'Wi-Fi & Network Settings',
    subtitle: 'Scan, select, and update network credentials',
    icon: Icons.wifi_rounded,
    color: Color(0xFF00BCD4),
    steps: [
      'Go to "Settings" tab and scroll to the "Wi-Fi Configuration" section.',
      'Tap the scan icon next to the SSID field to search for available 2.4 GHz networks.',
      'Select your network from the list — the SSID is filled in automatically.',
      'Enter the Wi-Fi password and tap "Save & Sync".',
      'GEM will connect to the new network on the next restart.',
      'To change the cloud security broker URL, enter it in the "Security Broker URL" field.',
    ],
    tip: 'GEM only supports 2.4 GHz Wi-Fi. 5 GHz networks will not appear in the scan list.',
  ),
  _GuideItem(
    title: 'Timeline & Event Log',
    subtitle: 'Review all past events, alerts, and actions',
    icon: Icons.history_rounded,
    color: Color(0xFF607D8B),
    steps: [
      'Open the "Timeline" tab from the bottom navigation bar.',
      'All events are shown in reverse chronological order — most recent at the top.',
      'Events are color-coded: blue for system events, orange for alarms, red for security alerts, green for syncs.',
      'Tap any entry to see the full event detail.',
      'To clear the timeline, tap the trash icon at the top right.',
    ],
    tip: 'The timeline is stored locally on your phone and resets when you clear it or reinstall the app.',
  ),
  _GuideItem(
    title: 'Physical Touch Controls',
    subtitle: 'How to navigate GEM\'s on-device menu',
    icon: Icons.touch_app_rounded,
    color: Color(0xFF8BC34A),
    steps: [
      'Short press: scroll through the GEM menu options (Alarm, Lamp, Heart Rate, Guard Mode, Info, Wi-Fi, Reset, Update).',
      'Long press: select/activate the currently highlighted menu item.',
      'When inside a sub-mode (Heart Rate, Wi-Fi Setup, Update), long press exits back to the main screen.',
      'When an alarm is ringing, long press dismisses it.',
      'On the main idle screen, long press opens the main menu.',
    ],
    tip: 'If Guard Mode is ON, any touch will trigger a security alert. Disable guard mode before using the menu.',
  ),
];
