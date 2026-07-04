import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  final String userName;
  final int avatarIndex;
  final String greetingStyle; // 'Standard', 'Sassy', 'Gentle', 'Cute'
  final String deviceNickname;
  final String eyeStyle; // 'Retro Glow', 'Futuristic Bar', 'Pixel Round'
  final double animationSpeed; // 0.5 to 2.0
  final String sleepTime; // '22:00'
  final bool hourlyChime;
  final bool setupComplete;

  UserSettings({
    this.userName = 'Shovin',
    this.avatarIndex = 0,
    this.greetingStyle = 'Standard',
    this.deviceNickname = 'GEM',
    this.eyeStyle = 'Retro Glow',
    this.animationSpeed = 1.0,
    this.sleepTime = '22:00',
    this.hourlyChime = false,
    this.setupComplete = false,
  });

  UserSettings copyWith({
    String? userName,
    int? avatarIndex,
    String? greetingStyle,
    String? deviceNickname,
    String? eyeStyle,
    double? animationSpeed,
    String? sleepTime,
    bool? hourlyChime,
    bool? setupComplete,
  }) {
    return UserSettings(
      userName: userName ?? this.userName,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      greetingStyle: greetingStyle ?? this.greetingStyle,
      deviceNickname: deviceNickname ?? this.deviceNickname,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      sleepTime: sleepTime ?? this.sleepTime,
      hourlyChime: hourlyChime ?? this.hourlyChime,
      setupComplete: setupComplete ?? this.setupComplete,
    );
  }
}

class SettingsNotifier extends Notifier<UserSettings> {
  SharedPreferences? _prefs;
  static const String _prefix = 'gem_settings_';

  @override
  UserSettings build() {
    _initStorage();
    return UserSettings();
  }

  Future<void> _initStorage() async {
    _prefs = await SharedPreferences.getInstance();
    state = UserSettings(
      userName: _prefs?.getString('${_prefix}userName') ?? 'Shovin',
      avatarIndex: _prefs?.getInt('${_prefix}avatarIndex') ?? 0,
      greetingStyle: _prefs?.getString('${_prefix}greetingStyle') ?? 'Standard',
      deviceNickname: _prefs?.getString('${_prefix}deviceNickname') ?? 'GEM',
      eyeStyle: _prefs?.getString('${_prefix}eyeStyle') ?? 'Retro Glow',
      animationSpeed: _prefs?.getDouble('${_prefix}animationSpeed') ?? 1.0,
      sleepTime: _prefs?.getString('${_prefix}sleepTime') ?? '22:00',
      hourlyChime: _prefs?.getBool('${_prefix}hourlyChime') ?? false,
      setupComplete: _prefs?.getBool('${_prefix}setupComplete') ?? false,
    );
  }

  Future<void> updateUserName(String name) async {
    state = state.copyWith(userName: name);
    await _prefs?.setString('${_prefix}userName', name);
  }

  Future<void> updateAvatar(int index) async {
    state = state.copyWith(avatarIndex: index);
    await _prefs?.setInt('${_prefix}avatarIndex', index);
  }

  Future<void> updateGreetingStyle(String style) async {
    state = state.copyWith(greetingStyle: style);
    await _prefs?.setString('${_prefix}greetingStyle', style);
  }

  Future<void> updateDeviceNickname(String nickname) async {
    state = state.copyWith(deviceNickname: nickname);
    await _prefs?.setString('${_prefix}deviceNickname', nickname);
  }

  Future<void> updateEyeStyle(String style) async {
    state = state.copyWith(eyeStyle: style);
    await _prefs?.setString('${_prefix}eyeStyle', style);
  }

  Future<void> updateAnimationSpeed(double speed) async {
    state = state.copyWith(animationSpeed: speed);
    await _prefs?.setDouble('${_prefix}animationSpeed', speed);
  }

  Future<void> updateSleepTime(String time) async {
    state = state.copyWith(sleepTime: time);
    await _prefs?.setString('${_prefix}sleepTime', time);
  }

  Future<void> updateHourlyChime(bool val) async {
    state = state.copyWith(hourlyChime: val);
    await _prefs?.setBool('${_prefix}hourlyChime', val);
  }

  Future<void> updateSetupComplete(bool val) async {
    state = state.copyWith(setupComplete: val);
    await _prefs?.setBool('${_prefix}setupComplete', val);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(() {
  return SettingsNotifier();
});
