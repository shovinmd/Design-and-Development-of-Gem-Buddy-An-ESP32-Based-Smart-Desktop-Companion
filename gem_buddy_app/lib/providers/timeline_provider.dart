import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimelineLog {
  final DateTime timestamp;
  final String type; // 'heart', 'alarm', 'touch', 'security', 'system'
  final String title;
  final String message;

  TimelineLog({
    required this.timestamp,
    required this.type,
    required this.title,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'title': title,
        'message': message,
      };

  factory TimelineLog.fromJson(Map<String, dynamic> json) {
    return TimelineLog(
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'] ?? 'system',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

class TimelineNotifier extends Notifier<List<TimelineLog>> {
  SharedPreferences? _prefs;
  static const String _storageKey = 'gem_timeline_logs';

  @override
  List<TimelineLog> build() {
    _initStorage();
    return [];
  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();
    final List<String>? stored = _prefs?.getStringList(_storageKey);
    if (stored != null) {
      try {
        state = stored
            .map((item) => TimelineLog.fromJson(json.decode(item)))
            .toList();
      } catch (_) {
        // Fallback if structure changes
      }
    } else {
      // Default initial mock logs to look beautiful
      state = [
        TimelineLog(
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          type: 'system',
          title: 'GEM Setup Initialized',
          message: 'Personalization settings loaded successfully.',
        ),
        TimelineLog(
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          type: 'heart',
          title: 'Pulse Rate Recorded',
          message: 'Pulse scan completed successfully.',
        ),
        TimelineLog(
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          type: 'alarm',
          title: 'Morning Alarm Rang',
          message: 'Alarm "Morning Alarm" triggered at 06:30 AM.',
        ),
      ];
      _saveToStorage();
    }
  }

  void addLog({
    required String type,
    required String title,
    required String message,
  }) {
    final newLog = TimelineLog(
      timestamp: DateTime.now(),
      type: type,
      title: title,
      message: message,
    );
    state = [newLog, ...state];
    _saveToStorage();
  }

  void clearLogs() {
    state = [];
    _prefs?.remove(_storageKey);
  }

  Future<void> _saveToStorage() async {
    final List<String> encoded =
        state.map((log) => json.encode(log.toJson())).toList();
    await _prefs?.setStringList(_storageKey, encoded);
  }
}

final timelineProvider = NotifierProvider<TimelineNotifier, List<TimelineLog>>(() {
  return TimelineNotifier();
});
