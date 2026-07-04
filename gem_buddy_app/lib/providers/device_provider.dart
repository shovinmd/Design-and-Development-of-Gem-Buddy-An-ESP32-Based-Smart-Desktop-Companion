import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'timeline_provider.dart';

// State model representing the ESP32 GEM configuration & real-time telemetry
class DeviceState {
  final String deviceName;
  final String userName;
  final String timezoneLabel;
  final int timezoneOffsetMinutes;
  final bool wifiEnabled;
  final bool wifiConnected;
  final bool setupComplete;
  final bool hotspotEnabled;
  final bool hotspotActive;
  final int batteryPercent;
  final double batteryVoltage;
  final int ldrRaw;
  final bool lampState;
  final int lampMode;
  final int lampBrightness;
  final int ledAutoOffMinutes;
  final bool monitoringEnabled;
  final int faceMode;
  final bool timeValid;
  final String ipAddress;
  final List<GemAlarm> alarms;

  // App-specific connection and simulator statuses
  final bool isConnected;
  final bool isConnecting;
  final bool isSimulated;
  final bool isHeartScanning;
  final int bpm;
  final int activeAlarmIndex; // 255 if none
  final String? lastNotificationMessage;

  // Broker details
  final String brokerIpAddress;
  final bool isBrokerConnected;
  final List<dynamic> securityLogs;

  DeviceState({
    this.deviceName = 'GEM',
    this.userName = 'Friend',
    this.timezoneLabel = 'Asia/Calcutta',
    this.timezoneOffsetMinutes = 330,
    this.wifiEnabled = false,
    this.wifiConnected = false,
    this.setupComplete = false,
    this.hotspotEnabled = false,
    this.hotspotActive = false,
    this.batteryPercent = 88,
    this.batteryVoltage = 3.95,
    this.ldrRaw = 2048,
    this.lampState = false,
    this.lampMode = 0,
    this.lampBrightness = 140,
    this.ledAutoOffMinutes = 10,
    this.monitoringEnabled = false,
    this.faceMode = 0, // FACE_DAY
    this.timeValid = false,
    this.ipAddress = '192.168.4.1',
    this.alarms = const [],
    this.isConnected = false,
    this.isConnecting = false,
    this.isSimulated = false, // Default to false so we connect to hardware
    this.isHeartScanning = false,
    this.bpm = 0,
    this.activeAlarmIndex = 255,
    this.lastNotificationMessage,
    this.brokerIpAddress = 'design-and-development-of-gem-buddy-an.onrender.com',
    this.isBrokerConnected = false,
    this.securityLogs = const [],
  });

  DeviceState copyWith({
    String? deviceName,
    String? userName,
    String? timezoneLabel,
    int? timezoneOffsetMinutes,
    bool? wifiEnabled,
    bool? wifiConnected,
    bool? setupComplete,
    bool? hotspotEnabled,
    bool? hotspotActive,
    int? batteryPercent,
    double? batteryVoltage,
    int? ldrRaw,
    bool? lampState,
    int? lampMode,
    int? lampBrightness,
    int? ledAutoOffMinutes,
    bool? monitoringEnabled,
    int? faceMode,
    bool? timeValid,
    String? ipAddress,
    List<GemAlarm>? alarms,
    bool? isConnected,
    bool? isConnecting,
    bool? isSimulated,
    bool? isHeartScanning,
    int? bpm,
    int? activeAlarmIndex,
    String? lastNotificationMessage,
    String? brokerIpAddress,
    bool? isBrokerConnected,
    List<dynamic>? securityLogs,
  }) {
    return DeviceState(
      deviceName: deviceName ?? this.deviceName,
      userName: userName ?? this.userName,
      timezoneLabel: timezoneLabel ?? this.timezoneLabel,
      timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      wifiEnabled: wifiEnabled ?? this.wifiEnabled,
      wifiConnected: wifiConnected ?? this.wifiConnected,
      setupComplete: setupComplete ?? this.setupComplete,
      hotspotEnabled: hotspotEnabled ?? this.hotspotEnabled,
      hotspotActive: hotspotActive ?? this.hotspotActive,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      ldrRaw: ldrRaw ?? this.ldrRaw,
      lampState: lampState ?? this.lampState,
      lampMode: lampMode ?? this.lampMode,
      lampBrightness: lampBrightness ?? this.lampBrightness,
      ledAutoOffMinutes: ledAutoOffMinutes ?? this.ledAutoOffMinutes,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      faceMode: faceMode ?? this.faceMode,
      timeValid: timeValid ?? this.timeValid,
      ipAddress: ipAddress ?? this.ipAddress,
      alarms: alarms ?? this.alarms,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isSimulated: isSimulated ?? this.isSimulated,
      isHeartScanning: isHeartScanning ?? this.isHeartScanning,
      bpm: bpm ?? this.bpm,
      activeAlarmIndex: activeAlarmIndex ?? this.activeAlarmIndex,
      lastNotificationMessage: lastNotificationMessage,
      brokerIpAddress: brokerIpAddress ?? this.brokerIpAddress,
      isBrokerConnected: isBrokerConnected ?? this.isBrokerConnected,
      securityLogs: securityLogs ?? this.securityLogs,
    );
  }
}

class GemAlarm {
  final bool enabled;
  final int hour;
  final int minute;
  final String name;

  GemAlarm({
    this.enabled = false,
    this.hour = 7,
    this.minute = 0,
    this.name = 'Alarm',
  });

  GemAlarm copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    String? name,
  }) {
    return GemAlarm(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'name': name,
      };

  factory GemAlarm.fromJson(Map<String, dynamic> json) {
    return GemAlarm(
      enabled: json['enabled'] ?? false,
      hour: json['hour'] ?? 7,
      minute: json['minute'] ?? 0,
      name: json['name'] ?? 'Alarm',
    );
  }
}

class DeviceNotifier extends Notifier<DeviceState> {
  Timer? _pollingTimer;
  Timer? _simulatedSensorTimer;
  final String defaultSetupIp = '192.168.4.1';

  @override
  DeviceState build() {
    final isTesting = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTesting) {
      _startPolling();
      _startSimulatedSensorDrift();
      _loadSavedConnections();
    }

    ref.onDispose(() {
      _pollingTimer?.cancel();
      _simulatedSensorTimer?.cancel();
      _closeSocketOnly();
    });

    return DeviceState(
      alarms: [
        GemAlarm(enabled: true, hour: 6, minute: 30, name: 'Morning Alarm'),
        GemAlarm(enabled: false, hour: 8, minute: 0, name: 'Meditation'),
        GemAlarm(enabled: false, hour: 22, minute: 0, name: 'Sleep Wind-down'),
      ],
    );
  }

  Future<void> _loadSavedConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBrokerIp = prefs.getString('saved_broker_ip');
      final savedDeviceIp = prefs.getString('saved_device_ip');
      
      if (savedBrokerIp != null || savedDeviceIp != null) {
        state = state.copyWith(
          brokerIpAddress: savedBrokerIp ?? state.brokerIpAddress,
          ipAddress: savedDeviceIp ?? state.ipAddress,
        );
        
        final brokerToConnect = savedBrokerIp ?? state.brokerIpAddress;
        if (brokerToConnect.isNotEmpty) {
          connectToBroker(brokerToConnect);
        }
      }
    } catch (e) {
      if (kDebugMode) print("Failed to load saved connections: $e");
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (state.isSimulated) {
        _simulateTick();
      } else {
        fetchDeviceState();
      }
    });
  }

  void _startSimulatedSensorDrift() {
    _simulatedSensorTimer?.cancel();
    _simulatedSensorTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (state.isSimulated && !state.isHeartScanning) {
        final random = math.Random();
        int newLdr = state.ldrRaw + (random.nextInt(300) - 150);
        newLdr = newLdr.clamp(200, 3900);
        
        int calculatedFace = state.faceMode;
        if (state.faceMode != 7 && state.faceMode != 8 && state.faceMode != 5) {
          calculatedFace = (newLdr < 1600) ? 1 : 0; // 1 = FACE_EVENING, 0 = FACE_DAY
        }

        state = state.copyWith(
          ldrRaw: newLdr,
          batteryPercent: (state.batteryPercent - (random.nextDouble() < 0.05 ? 1 : 0)).clamp(1, 100),
          faceMode: calculatedFace,
        );
      }
    });
  }

  void setSimulationMode(bool isSimulated) {
    state = state.copyWith(isSimulated: isSimulated, isConnected: !isSimulated);
    ref.read(timelineProvider.notifier).addLog(
      type: 'system', 
      title: isSimulated ? 'Simulator Mode Activated' : 'Hardware Sync Activated', 
      message: isSimulated 
          ? 'GEM is running in fallback mock environment.' 
          : 'GEM looking for ESP32 at IP ${state.ipAddress}.'
    );
    if (!isSimulated) {
      fetchDeviceState();
    }
  }

  void updateIpAddress(String ip) {
    state = state.copyWith(ipAddress: ip);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('saved_device_ip', ip);
    });
    if (!state.isSimulated) {
      fetchDeviceState();
    }
  }

  void clearNotification() {
    state = state.copyWith(lastNotificationMessage: null);
  }

  Future<void> fetchDeviceState() async {
    if (state.isSimulated) return;
    
    try {
      final response = await http.get(Uri.parse('http://${state.ipAddress}/api/state'))
          .timeout(const Duration(seconds: 3));
          
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        List<GemAlarm> fetchedAlarms = [];
        if (data['alarms'] != null) {
          fetchedAlarms = (data['alarms'] as List)
              .map((item) => GemAlarm.fromJson(item))
              .toList();
        }

        state = state.copyWith(
          deviceName: data['deviceName'] ?? state.deviceName,
          userName: data['userName'] ?? state.userName,
          timezoneLabel: data['timezoneLabel'] ?? state.timezoneLabel,
          timezoneOffsetMinutes: data['timezoneOffsetMinutes'] ?? state.timezoneOffsetMinutes,
          wifiEnabled: data['wifiEnabled'] ?? state.wifiEnabled,
          wifiConnected: data['wifiConnected'] ?? state.wifiConnected,
          setupComplete: data['setupComplete'] ?? state.setupComplete,
          hotspotEnabled: data['hotspotEnabled'] ?? state.hotspotEnabled,
          hotspotActive: data['hotspotActive'] ?? state.hotspotActive,
          batteryPercent: data['batteryPercent'] ?? state.batteryPercent,
          batteryVoltage: (data['batteryVoltage'] as num?)?.toDouble() ?? state.batteryVoltage,
          ldrRaw: data['ldrRaw'] ?? state.ldrRaw,
          lampState: data['lampState'] ?? state.lampState,
          lampMode: data['lampMode'] ?? state.lampMode,
          lampBrightness: data['lampBrightness'] ?? state.lampBrightness,
          monitoringEnabled: data['monitoringEnabled'] ?? state.monitoringEnabled,
          faceMode: data['faceMode'] ?? state.faceMode,
          timeValid: data['timeValid'] ?? state.timeValid,
          alarms: fetchedAlarms.isNotEmpty ? fetchedAlarms : state.alarms,
          isConnected: true,
          isConnecting: false,
        );

        if (data['faceMode'] == 8 && state.activeAlarmIndex == 255) {
          state = state.copyWith(
            activeAlarmIndex: 0,
            lastNotificationMessage: '🚨 Alarm Triggered: Time to wake up!',
          );
          ref.read(timelineProvider.notifier).addLog(
            type: 'alarm',
            title: 'Alarm Triggered!',
            message: 'Physical device buzzer and OLED alert are active.',
          );
        } else if (data['faceMode'] != 8 && state.activeAlarmIndex != 255) {
          state = state.copyWith(activeAlarmIndex: 255);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Polling failed: $e. Falling back to simulated mode.");
      }
      state = state.copyWith(isConnected: false, isConnecting: false);
    }
  }

  Future<bool> saveSettings({
    String? userName,
    String? deviceName,
    String? wifiSsid,
    String? wifiPass,
    bool? wifiEnabled,
    bool? monitoringEnabled,
    bool? hotspotEnabled,
    int? lampMode,
    int? lampBrightness,
    bool? lampState,
    int? ledAutoOffMinutes,
    List<GemAlarm>? alarms,
    String? timezoneLabel,
    int? timezoneOffsetMinutes,
  }) async {
    final Map<String, String> params = {};
    if (userName != null) params['userName'] = userName;
    if (deviceName != null) params['deviceName'] = deviceName;
    if (wifiSsid != null) params['wifiSsid'] = wifiSsid;
    if (wifiPass != null) params['wifiPass'] = wifiPass;
    if (wifiEnabled != null) params['wifiEnabled'] = wifiEnabled ? 'true' : 'false';
    if (monitoringEnabled != null) params['monitoringEnabled'] = monitoringEnabled ? 'true' : 'false';
    if (hotspotEnabled != null) params['hotspotEnabled'] = hotspotEnabled ? 'true' : 'false';
    if (lampMode != null) params['lampMode'] = lampMode.toString();
    if (lampBrightness != null) params['lampBrightness'] = lampBrightness.toString();
    if (lampState != null) params['lampState'] = lampState ? 'true' : 'false';
    if (ledAutoOffMinutes != null) params['ledAutoOffMinutes'] = ledAutoOffMinutes.toString();

    final activeAlarms = alarms ?? state.alarms;
    for (int i = 0; i < activeAlarms.length && i < 3; i++) {
      final alarm = activeAlarms[i];
      params['alarm${i}_hour'] = alarm.hour.toString();
      params['alarm${i}_minute'] = alarm.minute.toString();
      params['alarm${i}_name'] = alarm.name;
      params['alarm${i}_enabled'] = alarm.enabled ? 'true' : 'false';
    }
    params['alarmCount'] = activeAlarms.length.toString();
    
    params['epoch'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final tzOffset = timezoneOffsetMinutes ?? state.timezoneOffsetMinutes;
    final tzLabel = timezoneLabel ?? state.timezoneLabel;
    params['tzOffset'] = tzOffset.toString();
    params['tzLabel'] = tzLabel;

    if (state.isSimulated) {
      state = state.copyWith(
        userName: userName ?? state.userName,
        deviceName: deviceName ?? state.deviceName,
        wifiEnabled: wifiEnabled ?? state.wifiEnabled,
        monitoringEnabled: monitoringEnabled ?? state.monitoringEnabled,
        hotspotEnabled: hotspotEnabled ?? state.hotspotEnabled,
        lampMode: lampMode ?? state.lampMode,
        lampBrightness: lampBrightness ?? state.lampBrightness,
        lampState: lampState ?? state.lampState,
        ledAutoOffMinutes: ledAutoOffMinutes ?? state.ledAutoOffMinutes,
        alarms: activeAlarms,
        timezoneLabel: tzLabel,
        timezoneOffsetMinutes: tzOffset,
        setupComplete: true,
      );
      
      ref.read(timelineProvider.notifier).addLog(
        type: 'system', 
        title: 'Settings Saved (Simulated)', 
        message: 'Settings updated inside local simulator memory.'
      );
      return true;
    }

    try {
      final uri = Uri.http(state.ipAddress, '/api/save', params);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        state = state.copyWith(
          userName: userName ?? state.userName,
          deviceName: deviceName ?? state.deviceName,
          wifiEnabled: wifiEnabled ?? state.wifiEnabled,
          monitoringEnabled: monitoringEnabled ?? state.monitoringEnabled,
          hotspotEnabled: hotspotEnabled ?? state.hotspotEnabled,
          lampMode: lampMode ?? state.lampMode,
          lampBrightness: lampBrightness ?? state.lampBrightness,
          lampState: lampState ?? state.lampState,
          ledAutoOffMinutes: ledAutoOffMinutes ?? state.ledAutoOffMinutes,
          alarms: activeAlarms,
          timezoneLabel: tzLabel,
          timezoneOffsetMinutes: tzOffset,
          setupComplete: true,
        );
        ref.read(timelineProvider.notifier).addLog(
          type: 'system', 
          title: 'Settings Sync Completed', 
          message: 'Hardware flash updated via REST.'
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) print("Save failed: $e");
    }
    return false;
  }

  Future<bool> findMyGem() async {
    ref.read(timelineProvider.notifier).addLog(
      type: 'system',
      title: 'Find My Gem Triggered',
      message: 'Searching for companion...'
    );

    if (state.isSimulated) {
      state = state.copyWith(
        lastNotificationMessage: '🔊 Beep! GEM is calling you: "I am here! 💎"',
      );
      return true;
    }

    return saveSettings(
      lampState: true,
      lampMode: 3, 
    );
  }

  Future<void> startHeartScan() async {
    if (state.isHeartScanning) return;
    
    state = state.copyWith(
      isHeartScanning: true,
      faceMode: 7, 
      bpm: 0
    );

    ref.read(timelineProvider.notifier).addLog(
      type: 'system',
      title: 'Heart Scan Started',
      message: 'Keep finger on pulse sensor.'
    );

    int tick = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!state.isHeartScanning) {
        timer.cancel();
        return;
      }

      tick++;
      if (tick < 10) {
        final nextBpm = 60 + math.Random().nextInt(30);
        state = state.copyWith(bpm: nextBpm);
      } else {
        timer.cancel();
        final finalBpm = 72 + math.Random().nextInt(18); 
        state = state.copyWith(
          isHeartScanning: false,
          faceMode: 0, 
          bpm: finalBpm
        );
        
        ref.read(timelineProvider.notifier).addLog(
          type: 'heart',
          title: 'Pulse Scan Complete',
          message: 'Measured $finalBpm BPM.'
        );

        state = state.copyWith(
          lastNotificationMessage: '❤️ Heart Rate Scan Completed: $finalBpm BPM',
        );
      }
    });
  }

  void dismissAlarm() {
    if (state.activeAlarmIndex == 255) return;
    
    state = state.copyWith(
      activeAlarmIndex: 255,
      faceMode: 0, 
    );

    ref.read(timelineProvider.notifier).addLog(
      type: 'alarm',
      title: 'Alarm Dismissed',
      message: 'Buzzer deactivated.',
    );
    
    if (!state.isSimulated) {
      saveSettings(lampState: false);
    }
  }

  void triggerMockAlarm(int alarmIndex) {
    if (!state.isSimulated || alarmIndex >= state.alarms.length) return;
    
    state = state.copyWith(
      activeAlarmIndex: alarmIndex,
      faceMode: 8, 
      lastNotificationMessage: '⏰ Alarm Ringing: ${state.alarms[alarmIndex].name}!',
    );

    ref.read(timelineProvider.notifier).addLog(
      type: 'alarm',
      title: 'Alarm Triggered (Mock)',
      message: '${state.alarms[alarmIndex].name} is ringing.'
    );
  }

  void triggerMockTouchAlert() {
    if (!state.isSimulated) return;
    
    state = state.copyWith(
      faceMode: 5, 
      lastNotificationMessage: '🫧 GEM Touch Alert: Someone touched your device!',
    );

    ref.read(timelineProvider.notifier).addLog(
      type: 'system',
      title: 'Touch Detected',
      message: 'GEM physical sensor touched.'
    );
  }

  void _simulateTick() {
    final now = DateTime.now();
    for (int i = 0; i < state.alarms.length; i++) {
      final alarm = state.alarms[i];
      if (alarm.enabled && alarm.hour == now.hour && alarm.minute == now.minute && now.second < 5) {
        if (state.activeAlarmIndex == 255) {
          triggerMockAlarm(i);
        }
      }
    }
  }

  WebSocketChannel? _wsChannel;

  String _getRestUrl(String endpoint) {
    final ip = state.brokerIpAddress;
    if (ip.contains('onrender.com') || ip.contains('herokuapp.com') || ip.startsWith('http://') || ip.startsWith('https://')) {
      String baseUrl = ip;
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'https://$baseUrl'; // Render uses HTTPS
      }
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      return '$baseUrl$endpoint';
    } else {
      return 'http://$ip:3000$endpoint';
    }
  }

  Future<void> fetchSecurityLogs() async {
    if (state.brokerIpAddress.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(_getRestUrl('/api/guard/logs')))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> logs = json.decode(response.body);
        state = state.copyWith(securityLogs: logs);
      }
    } catch (e) {
      if (kDebugMode) print("Failed to fetch security logs: $e");
    }
  }

  Future<bool> toggleBrokerGuardMode(bool active) async {
    final physicalSuccess = await saveSettings(monitoringEnabled: active);
    
    if (state.brokerIpAddress.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(_getRestUrl('/api/guard/toggle')),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'active': active}),
        ).timeout(const Duration(seconds: 4));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final brokerActive = data['active'] ?? active;
          state = state.copyWith(monitoringEnabled: brokerActive);
          await fetchSecurityLogs();
          return true;
        }
      } catch (e) {
        if (kDebugMode) print("Failed to toggle broker guard mode: $e");
      }
    }
    
    state = state.copyWith(monitoringEnabled: active);
    return physicalSuccess;
  }

  Future<bool> clearSecurityLogs() async {
    if (state.brokerIpAddress.isEmpty) {
      state = state.copyWith(securityLogs: const []);
      return true;
    }
    try {
      final response = await http.post(Uri.parse(_getRestUrl('/api/guard/clear')))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        state = state.copyWith(securityLogs: const []);
        return true;
      }
    } catch (e) {
      if (kDebugMode) print("Failed to clear security logs: $e");
    }
    return false;
  }

  void connectToBroker(String brokerIp) {
    disconnectBroker();
    if (brokerIp.isEmpty) return;
    
    state = state.copyWith(brokerIpAddress: brokerIp, isBrokerConnected: false);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('saved_broker_ip', brokerIp);
    });
    
    try {
      String wsUrl;
      if (brokerIp.contains('onrender.com') || brokerIp.contains('herokuapp.com') || brokerIp.startsWith('wss://') || brokerIp.startsWith('ws://')) {
        wsUrl = brokerIp;
        if (!wsUrl.startsWith('ws://') && !wsUrl.startsWith('wss://')) {
          wsUrl = 'wss://$wsUrl'; // Render uses secure WSS
        }
      } else {
        wsUrl = 'ws://$brokerIp:3000';
      }

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      state = state.copyWith(isBrokerConnected: true);
      ref.read(timelineProvider.notifier).addLog(
        type: 'system',
        title: 'Broker Connected',
        message: 'Connected to security broker at $wsUrl',
      );

      fetchSecurityLogs();

      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            if (data['event'] == 'alert') {
              final reason = data['reason'] ?? 'Security alert';
              final device = data['device'] ?? 'GEM';
              final battery = data['battery'] ?? 100;

              state = state.copyWith(
                lastNotificationMessage: '🚨 SECURE ALERT: $reason detected on $device! (Bat: $battery%)',
              );

              ref.read(timelineProvider.notifier).addLog(
                type: 'alarm',
                title: 'Security Alert: $reason',
                message: '$device physical alert received from webhook broker.',
              );

              fetchSecurityLogs();
            } else if (data['event'] == 'guard_toggle') {
              final active = data['active'] ?? false;
              state = state.copyWith(monitoringEnabled: active);
              saveSettings(monitoringEnabled: active);
              fetchSecurityLogs();
            } else if (data['event'] == 'info') {
              final active = data['guardMode'] ?? false;
              state = state.copyWith(monitoringEnabled: active);
              fetchSecurityLogs();
            }
          } catch (e) {
            if (kDebugMode) print("WS decode error: $e");
          }
        },
        onError: (err) {
          state = state.copyWith(isBrokerConnected: false);
          if (kDebugMode) print("WS error: $err");
          // Reconnect after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (_wsChannel == null && state.brokerIpAddress.isNotEmpty) {
              connectToBroker(brokerIp);
            }
          });
        },
        onDone: () {
          state = state.copyWith(isBrokerConnected: false);
          if (kDebugMode) print("WS channel closed.");
        },
      );
    } catch (e) {
      state = state.copyWith(isBrokerConnected: false);
      if (kDebugMode) print("WS connection failed: $e");
    }
  }

  void _closeSocketOnly() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void disconnectBroker() {
    _closeSocketOnly();
    state = state.copyWith(isBrokerConnected: false);
  }

  Future<bool> uploadFirmware(List<int> bytes, String filename, {Function(double)? onProgress}) async {
    if (state.isSimulated) {
      // Simulate progress
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (onProgress != null) onProgress(i / 10.0);
      }
      ref.read(timelineProvider.notifier).addLog(
        type: 'system',
        title: 'OTA Mock Update',
        message: 'Mock firmware updated successfully.',
      );
      return true;
    }

    try {
      final uri = Uri.parse('http://${state.ipAddress}/api/update');
      final request = http.MultipartRequest('POST', uri);
      
      final multipartFile = http.MultipartFile.fromBytes(
        'update', 
        bytes,
        filename: filename,
      );
      request.files.add(multipartFile);
      
      if (onProgress != null) onProgress(0.3);
      final response = await request.send().timeout(const Duration(minutes: 2));
      if (onProgress != null) onProgress(1.0);

      if (response.statusCode == 200) {
        ref.read(timelineProvider.notifier).addLog(
          type: 'system',
          title: 'OTA Update Complete',
          message: 'ESP32 firmware updated successfully. Device rebooting.',
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) print("OTA Upload failed: $e");
    }
    return false;
  }
}

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(() {
  return DeviceNotifier();
});
