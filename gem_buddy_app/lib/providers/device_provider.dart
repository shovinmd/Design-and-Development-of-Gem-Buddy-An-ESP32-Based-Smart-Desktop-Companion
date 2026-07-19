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
  final int hotspotTimeoutMinutes;
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
  final bool deviceOnline;   // device pinged backend within last 90s
  final bool appOnline;      // app is connected to broker WS

  // App-specific connection and simulator statuses
  final bool isConnected;
  final bool isConnecting;
  final bool isSimulated;
  final bool isHeartScanning;
  final int bpm;
  final int pulseRaw;
  final int activeAlarmIndex; // 255 if none
  final String? lastNotificationMessage;

  // Broker details
  final String brokerIpAddress;
  final bool isBrokerConnected;
  final List<dynamic> securityLogs;

  final String firmwareVersion;

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
    this.hotspotTimeoutMinutes = 20,
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
    this.deviceOnline = false,
    this.appOnline = false,
    this.isConnected = false,
    this.isConnecting = false,
    this.isSimulated = false, // Default to false so we connect to hardware
    this.isHeartScanning = false,
    this.bpm = 0,
    this.pulseRaw = 0,
    this.activeAlarmIndex = 255,
    this.lastNotificationMessage,
    this.brokerIpAddress = 'design-and-development-of-gem-buddy-an.onrender.com',
    this.isBrokerConnected = false,
    this.securityLogs = const [],
    this.firmwareVersion = '1.0',
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
    int? hotspotTimeoutMinutes,
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
    bool? deviceOnline,
    bool? appOnline,
    bool? isConnected,
    bool? isConnecting,
    bool? isSimulated,
    bool? isHeartScanning,
    int? bpm,
    int? pulseRaw,
    int? activeAlarmIndex,
    String? lastNotificationMessage,
    String? brokerIpAddress,
    bool? isBrokerConnected,
    List<dynamic>? securityLogs,
    String? firmwareVersion,
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
      hotspotTimeoutMinutes: hotspotTimeoutMinutes ?? this.hotspotTimeoutMinutes,
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
      deviceOnline: deviceOnline ?? this.deviceOnline,
      appOnline: appOnline ?? this.appOnline,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isSimulated: isSimulated ?? this.isSimulated,
      isHeartScanning: isHeartScanning ?? this.isHeartScanning,
      bpm: bpm ?? this.bpm,
      pulseRaw: pulseRaw ?? this.pulseRaw,
      activeAlarmIndex: activeAlarmIndex ?? this.activeAlarmIndex,
      lastNotificationMessage: lastNotificationMessage,
      brokerIpAddress: brokerIpAddress ?? this.brokerIpAddress,
      isBrokerConnected: isBrokerConnected ?? this.isBrokerConnected,
      securityLogs: securityLogs ?? this.securityLogs,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
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
  http.Client? _uploadClient;

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
      alarms: const [],
    );
  }

  Future<void> _loadSavedConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBrokerIp = prefs.getString('saved_broker_ip');
      final savedDeviceIp = prefs.getString('saved_device_ip');
      
      List<GemAlarm> localAlarms = [];
      final savedAlarmsStr = prefs.getString('saved_alarms');
      if (savedAlarmsStr != null) {
        try {
          final List<dynamic> decoded = json.decode(savedAlarmsStr);
          localAlarms = decoded.map((item) => GemAlarm.fromJson(item as Map<String, dynamic>)).toList();
        } catch (_) {}
      }

      state = state.copyWith(
        brokerIpAddress: savedBrokerIp ?? state.brokerIpAddress,
        ipAddress: savedDeviceIp ?? state.ipAddress,
        alarms: localAlarms.isNotEmpty ? localAlarms : state.alarms,
        lampMode: prefs.getInt('saved_lampMode') ?? state.lampMode,
        lampBrightness: prefs.getInt('saved_lampBrightness') ?? state.lampBrightness,
        lampState: prefs.getBool('saved_lampState') ?? state.lampState,
        ledAutoOffMinutes: prefs.getInt('saved_ledAutoOff') ?? state.ledAutoOffMinutes,
        hotspotEnabled: prefs.getBool('saved_hotspotEnabled') ?? state.hotspotEnabled,
        monitoringEnabled: prefs.getBool('saved_monitoringEnabled') ?? state.monitoringEnabled,
      );
      
      final brokerToConnect = savedBrokerIp ?? state.brokerIpAddress;
      if (brokerToConnect.isNotEmpty) {
        connectToBroker(brokerToConnect);
      }
    } catch (e) {
      if (kDebugMode) print("Failed to load saved connections: $e");
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
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

  Future<void> _updateSavedIp(String newIp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_device_ip', newIp);
    } catch (_) {}
  }

  Future<String?> _discoverDeviceUdp() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      String? discoveredIp;
      bool completed = false;
      
      final completer = Completer<String?>();
      
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = socket.receive();
          if (datagram != null) {
            String msg = String.fromCharCodes(datagram.data);
            if (msg.startsWith("GEM_ACK:")) {
              discoveredIp = msg.substring(8);
              if (!completed) {
                completed = true;
                completer.complete(discoveredIp);
              }
            }
          }
        }
      });
      
      socket.send("GEM_DISCOVER".codeUnits, InternetAddress("255.255.255.255"), 8266);
      
      Timer(const Duration(seconds: 1), () {
        if (!completed) {
          completed = true;
          completer.complete(null);
        }
      });
      
      final result = await completer.future;
      socket.close();
      return result;
    } catch (e) {
      if (kDebugMode) print("UDP Discovery failed: $e");
      return null;
    }
  }

  Future<void> fetchDeviceState() async {
    if (state.isSimulated) return;
    
    String activeIp = state.ipAddress;
    http.Response? response;
    
    try {
      response = await http.get(Uri.parse('http://$activeIp/api/state'))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      // If direct IP fails, try Hotspot IP, then UDP, then mDNS
      if (activeIp != 'gem-buddy.local') {
        try {
          // 1. Try Default Hotspot IP
          if (activeIp != '192.168.4.1') {
            if (kDebugMode) print("Connection to $activeIp failed. Trying default hotspot IP 192.168.4.1...");
            try {
              final hotspotResponse = await http.get(Uri.parse('http://192.168.4.1/api/state'))
                  .timeout(const Duration(milliseconds: 1500));
              if (hotspotResponse.statusCode == 200) {
                response = hotspotResponse;
                activeIp = '192.168.4.1';
              }
            } catch (_) {}
          }

          // 2. Try UDP Discovery if hotspot failed
          if (response == null) {
            if (kDebugMode) print("Hotspot check failed. Trying UDP Discovery...");
            final discoveredIp = await _discoverDeviceUdp();
            if (discoveredIp != null) {
              final fallbackResponse = await http.get(Uri.parse('http://$discoveredIp/api/state'))
                  .timeout(const Duration(seconds: 2));
              if (fallbackResponse.statusCode == 200) {
                response = fallbackResponse;
                activeIp = discoveredIp;
              }
            }
          }

          // 3. Fallback to mDNS
          if (response == null) {
            if (kDebugMode) print("UDP Discovery failed. Trying fallback hostname gem-buddy.local...");
            final fallbackResponse = await http.get(Uri.parse('http://gem-buddy.local/api/state'))
                .timeout(const Duration(seconds: 2));
            if (fallbackResponse.statusCode == 200) {
              response = fallbackResponse;
              activeIp = 'gem-buddy.local';
            }
          }
        } catch (err) {
          if (kDebugMode) print("Fallback connections failed: $err");
        }
      }
    }

    if (response == null || response.statusCode != 200) {
      state = state.copyWith(isConnected: false, isConnecting: false);
      return;
    }
          
    try {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // Auto-update saved IP if the device returned a different valid IP on the home Wi-Fi network
      String resolvedIp = state.ipAddress;
      if (data['ip'] != null && data['ip'] != '0.0.0.0' && data['ip'] != '') {
        resolvedIp = data['ip'];
        if (resolvedIp != state.ipAddress) {
          if (kDebugMode) print("Device IP dynamically resolved: $resolvedIp");
          state = state.copyWith(ipAddress: resolvedIp);
          _updateSavedIp(resolvedIp);
        }
      }

      List<GemAlarm> fetchedAlarms = [];
      if (data.containsKey('alarms') && data['alarms'] != null) {
        fetchedAlarms = (data['alarms'] as List)
            .map((item) => GemAlarm.fromJson(item as Map<String, dynamic>))
            .toList();
            
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('saved_alarms', json.encode(fetchedAlarms.map((a) => a.toJson()).toList()));
        });
      }

      final bool isScanningOnHardware = data['faceMode'] == 7;
      final int deviceBpm = data['bpm'] ?? state.bpm;
      
      if (state.isHeartScanning && !isScanningOnHardware) {
        ref.read(timelineProvider.notifier).addLog(
          type: 'heart',
          title: 'Pulse Scan Complete',
          message: 'Completed pulse scan on GEM.'
        );
        state = state.copyWith(
          lastNotificationMessage: '❤️ Heart Rate Scan Completed',
        );
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
        hotspotTimeoutMinutes: data['hotspotTimeoutMinutes'] ?? state.hotspotTimeoutMinutes,
        batteryPercent: data['batteryPercent'] ?? state.batteryPercent,
        batteryVoltage: (data['batteryVoltage'] as num?)?.toDouble() ?? state.batteryVoltage,
        ldrRaw: data['ldrRaw'] ?? state.ldrRaw,
        lampState: data['lampState'] ?? state.lampState,
        lampMode: data['lampMode'] ?? state.lampMode,
        lampBrightness: data['lampBrightness'] ?? state.lampBrightness,
        monitoringEnabled: data['monitoringEnabled'] ?? state.monitoringEnabled,
        faceMode: data['faceMode'] ?? state.faceMode,
        timeValid: data['timeValid'] ?? state.timeValid,
        alarms: data.containsKey('alarms') ? fetchedAlarms : state.alarms,
        isConnected: true,
        isConnecting: false,
        isHeartScanning: isScanningOnHardware,
        bpm: deviceBpm,
        pulseRaw: data['pulseRaw'] ?? 0,
        firmwareVersion: data['firmwareVersion'] ?? state.firmwareVersion,
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

      if (isScanningOnHardware) {
        Timer(const Duration(milliseconds: 150), () => fetchDeviceState());
      }
    } catch (e) {
      if (kDebugMode) {
        print("Parsing state failed: $e.");
      }
      state = state.copyWith(isConnected: false, isConnecting: false);
    }
  }

  Future<bool> checkSetupPortalConnection() async {
    try {
      final response = await http.get(Uri.parse('http://$defaultSetupIp/api/state'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        state = state.copyWith(
          ipAddress: defaultSetupIp,
          isSimulated: false,
          isConnected: true,
        );
        
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['wifiConnected'] == false) {
            final prefs = await SharedPreferences.getInstance();
            final savedSsid = prefs.getString('saved_wifi_ssid');
            final savedPass = prefs.getString('saved_wifi_pass');
            if (savedSsid != null && savedSsid.isNotEmpty) {
              await saveSettings(
                wifiSsid: savedSsid,
                wifiPass: savedPass,
                wifiEnabled: true,
              );
            }
          }
        } catch (_) {}

        return true;
      }
    } catch (_) {
      // Unreachable
    }
    return false;
  }

  Future<String?> saveSettings({
    String? userName,
    String? deviceName,
    String? wifiSsid,
    String? wifiPass,
    bool? wifiEnabled,
    bool? monitoringEnabled,
    bool? hotspotEnabled,
    int? hotspotTimeoutMinutes,
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
    if (hotspotTimeoutMinutes != null) params['hotspotTimeoutMinutes'] = hotspotTimeoutMinutes.toString();
    if (lampMode != null) params['lampMode'] = lampMode.toString();
    if (lampBrightness != null) params['lampBrightness'] = lampBrightness.toString();
    if (lampState != null) params['lampState'] = lampState ? 'true' : 'false';
    if (ledAutoOffMinutes != null) params['ledAutoOffMinutes'] = ledAutoOffMinutes.toString();

    // Auto-sync the cloud webhook URL to the device so it can send security alerts securely
    final String brokerIp = state.brokerIpAddress.isEmpty
        ? 'design-and-development-of-gem-buddy-an.onrender.com'
        : state.brokerIpAddress;
    String webhookUrl;
    if (brokerIp.startsWith('http://') || brokerIp.startsWith('https://')) {
      webhookUrl = brokerIp.endsWith('/') ? '${brokerIp}webhook' : '$brokerIp/webhook';
    } else {
      final isLocal = brokerIp.contains('localhost') || 
                      brokerIp.contains('127.0.0.1') || 
                      brokerIp.contains('10.0.2.2') || 
                      brokerIp.startsWith('192.168.') ||
                      brokerIp.startsWith('10.');
      final protocol = isLocal ? 'http://' : 'https://';
      webhookUrl = '$protocol$brokerIp/webhook';
    }
    params['webhook'] = webhookUrl;

    final prefs = await SharedPreferences.getInstance();
    if (lampMode != null) await prefs.setInt('saved_lampMode', lampMode);
    if (lampBrightness != null) await prefs.setInt('saved_lampBrightness', lampBrightness);
    if (lampState != null) await prefs.setBool('saved_lampState', lampState);
    if (ledAutoOffMinutes != null) await prefs.setInt('saved_ledAutoOff', ledAutoOffMinutes);
    if (hotspotEnabled != null) await prefs.setBool('saved_hotspotEnabled', hotspotEnabled);
    if (hotspotTimeoutMinutes != null) await prefs.setInt('saved_hotspotTimeoutMinutes', hotspotTimeoutMinutes);
    if (monitoringEnabled != null) await prefs.setBool('saved_monitoringEnabled', monitoringEnabled);

    final activeAlarms = alarms ?? state.alarms;
    for (int i = 0; i < activeAlarms.length && i < 6; i++) {
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
        hotspotTimeoutMinutes: hotspotTimeoutMinutes ?? state.hotspotTimeoutMinutes,
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
      return null;
    }

    try {
      final uri = Uri.http(state.ipAddress, '/api/save', params);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        state = state.copyWith(
          userName: userName ?? state.userName,
          deviceName: deviceName ?? state.deviceName,
          wifiEnabled: wifiEnabled ?? state.wifiEnabled,
          monitoringEnabled: monitoringEnabled ?? state.monitoringEnabled,
          hotspotEnabled: hotspotEnabled ?? state.hotspotEnabled,
          hotspotTimeoutMinutes: hotspotTimeoutMinutes ?? state.hotspotTimeoutMinutes,
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
        return null;
      } else {
        return response.body;
      }
    } catch (e) {
      if (kDebugMode) print("Save failed: $e");
      return e.toString();
    }
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

    final err = await saveSettings(
      lampState: true,
      lampMode: 3, 
    );
    return err == null;
  }

  Future<void> startHeartScan() async {
    if (state.isHeartScanning) return;
    
    if (state.isSimulated) {
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
      Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!state.isHeartScanning) {
          timer.cancel();
          return;
        }

        tick++;
        if (tick < 130) {
          final double t = (tick % 6) / 6.0;
          double val = 0.0;
          if (t < 0.3) {
            val = math.sin(t * (math.pi / 0.3));
          } else if (t < 0.6) {
            val = 0.2 * math.sin((t - 0.3) * (math.pi / 0.3));
          }
          final int simulatedAdc = 1900 + (val * 900).toInt() + math.Random().nextInt(50);
          state = state.copyWith(pulseRaw: simulatedAdc);
        } else {
          timer.cancel();
          state = state.copyWith(
            isHeartScanning: false,
            faceMode: 0,
            pulseRaw: 0,
          );
          
          ref.read(timelineProvider.notifier).addLog(
            type: 'heart',
            title: 'Pulse Scan Complete',
            message: 'Completed pulse scan on GEM.'
          );

          state = state.copyWith(
            lastNotificationMessage: '❤️ Heart Rate Scan Completed',
          );
        }
      });
    } else {
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

      try {
        final response = await http.get(Uri.parse('http://${state.ipAddress}/api/heart?action=start'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          fetchDeviceState();
        }
      } catch (e) {
        if (kDebugMode) print("Start heart scan failed: $e");
      }
    }
  }

  Future<void> stopHeartScan() async {
    if (!state.isHeartScanning) return;

    if (state.isSimulated) {
      state = state.copyWith(
        isHeartScanning: false,
        faceMode: 0,
        pulseRaw: 0,
      );
      ref.read(timelineProvider.notifier).addLog(
        type: 'system',
        title: 'Heart Scan Stopped',
        message: 'Scan cancelled by user.'
      );
    } else {
      state = state.copyWith(
        isHeartScanning: false,
        faceMode: 0,
        pulseRaw: 0,
      );

      ref.read(timelineProvider.notifier).addLog(
        type: 'system',
        title: 'Heart Scan Stopped',
        message: 'Scan cancelled by user.'
      );

      try {
        final response = await http.get(Uri.parse('http://${state.ipAddress}/api/heart?action=stop'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          fetchDeviceState();
        }
      } catch (e) {
        if (kDebugMode) print("Stop heart scan failed: $e");
      }
    }
  }

  Future<List<Map<String, dynamic>>> scanWifiNetworks() async {
    if (state.ipAddress.isEmpty) return [];
    try {
      final response = await http.get(Uri.parse('http://${state.ipAddress}/api/wifi/scan'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List<dynamic> decoded = json.decode(response.body);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) print("Failed to scan WiFi: $e");
    }
    return [];
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
  Timer? _appPingTimer;

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

  Future<String?> toggleBrokerGuardMode(bool active) async {
    // Attempt local toggle first
    final physicalError = await saveSettings(monitoringEnabled: active);
    
    // If a broker is configured, toggle the guard state on the broker regardless of local direct REST success
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
          return null;
        } else {
          return response.body;
        }
      } catch (e) {
        if (kDebugMode) print("Failed to toggle broker guard mode: $e");
        return e.toString();
      }
    }
    
    // If no broker is set and local sync failed, return the physical error
    if (physicalError != null) {
      return physicalError;
    }
    
    state = state.copyWith(monitoringEnabled: active);
    return null;
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
      
      state = state.copyWith(isBrokerConnected: true, appOnline: true);
      ref.read(timelineProvider.notifier).addLog(
        type: 'system',
        title: 'Broker Connected',
        message: 'Connected to security broker at $wsUrl',
      );

      fetchSecurityLogs();

      // Start app-side 60s keepalive ping so backend knows app is online
      _appPingTimer?.cancel();
      _appPingTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
        if (!state.isBrokerConnected) return;
        try {
          final pingUrl = _getRestUrl('/api/ping');
          await http.post(
            Uri.parse(pingUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'source=app&device=${state.deviceName}',
          ).timeout(const Duration(seconds: 5));
        } catch (_) {}
      });
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            if (data['event'] == 'alert') {
              final rawReason = data['reason'] ?? 'Security alert';
              final device = data['device'] ?? 'GEM';
              final bool guardActive = data['guardActive'] ?? false;

              // Only process actual security alerts if guard mode is active
              final isSecurityReason = ['shadow-detected', 'flash-detected', 'touch-detected', 'touch-down', 'long-touch'].contains(rawReason);
              if (isSecurityReason && !guardActive) {
                fetchSecurityLogs();
                return;
              }
              
              String reason = rawReason;
              if (rawReason == 'shadow-detected') {
                reason = 'Shadow';
              } else if (rawReason == 'flash-detected') {
                reason = 'Light Spike';
              } else if (rawReason == 'touch-detected' || rawReason == 'touch-down') {
                reason = 'Touch';
              } else if (rawReason == 'long-touch') {
                reason = 'Sustained Touch';
              } else if (rawReason == 'alarm') {
                reason = 'Reminder';
              }

              state = state.copyWith(
                lastNotificationMessage: '🚨 GUARD ALERT: $reason detected on $device!',
                deviceOnline: data['deviceOnline'] ?? state.deviceOnline,
              );

              ref.read(timelineProvider.notifier).addLog(
                type: 'alarm',
                title: 'Guard Alert: $reason',
                message: '$device triggered a security alert. Check incident log.',
              );

              fetchSecurityLogs();
            } else if (data['event'] == 'ping_ack') {
              // Backend confirmed a ping — update live status
              state = state.copyWith(
                deviceOnline: data['deviceOnline'] ?? state.deviceOnline,
                appOnline:    data['appOnline']    ?? state.appOnline,
              );
            } else if (data['event'] == 'status_update') {
              state = state.copyWith(
                deviceOnline: data['deviceOnline'] ?? state.deviceOnline,
                appOnline:    data['appOnline']    ?? state.appOnline,
              );
            } else if (data['event'] == 'guard_toggle') {
              final active = data['active'] ?? false;
              state = state.copyWith(monitoringEnabled: active);
              saveSettings(monitoringEnabled: active);
              fetchSecurityLogs();
            } else if (data['event'] == 'info') {
              final active = data['guardMode'] ?? false;
              state = state.copyWith(
                monitoringEnabled: active,
                deviceOnline: data['deviceOnline'] ?? false,
                appOnline:    true, // we just connected
              );
              fetchSecurityLogs();
            }
          } catch (e) {
            if (kDebugMode) print("WS decode error: $e");
          }
        },
        onError: (err) {
          state = state.copyWith(isBrokerConnected: false, appOnline: false);
          if (kDebugMode) print("WS error: $err");
          _appPingTimer?.cancel();
          _wsChannel = null;
          // Auto-reconnect after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (_wsChannel == null && state.brokerIpAddress.isNotEmpty) {
              connectToBroker(brokerIp);
            }
          });
        },
        onDone: () {
          state = state.copyWith(isBrokerConnected: false, appOnline: false);
          _appPingTimer?.cancel();
          _wsChannel = null;
          if (kDebugMode) print("WS channel closed.");
          // Auto-reconnect after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (_wsChannel == null && state.brokerIpAddress.isNotEmpty) {
              connectToBroker(brokerIp);
            }
          });
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
    state = state.copyWith(isBrokerConnected: false, brokerIpAddress: '');
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('saved_broker_ip');
    });
  }

  Future<bool> uploadFirmware(List<int> bytes, String filename, {String? password, Function(double)? onProgress}) async {
    if (state.isSimulated) {
      _uploadClient = null;
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
      _uploadClient = http.Client();
      final passQuery = password != null ? '?pass=${Uri.encodeComponent(password)}' : '';
      final sizeQuery = password != null ? '&size=${bytes.length}' : '?size=${bytes.length}';
      final uri = Uri.parse('http://${state.ipAddress}/api/update$passQuery$sizeQuery');
      
      final request = ProgressMultipartRequest(
        'POST',
        uri,
        onProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );
      
      final multipartFile = http.MultipartFile.fromBytes(
        'update', 
        bytes,
        filename: filename,
      );
      request.files.add(multipartFile);
      
      final response = await _uploadClient!.send(request).timeout(const Duration(minutes: 2));

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
    } finally {
      _uploadClient?.close();
      _uploadClient = null;
    }
    return false;
  }

  void cancelUpload() {
    _uploadClient?.close();
    _uploadClient = null;
  }
}

class ProgressMultipartRequest extends http.MultipartRequest {
  final Function(int bytesSent, int totalBytes)? onProgress;

  ProgressMultipartRequest(
    super.method,
    super.url, {
    this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        onProgress!(bytesSent, total);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

final deviceProvider = NotifierProvider<DeviceNotifier, DeviceState>(() {
  return DeviceNotifier();
});
