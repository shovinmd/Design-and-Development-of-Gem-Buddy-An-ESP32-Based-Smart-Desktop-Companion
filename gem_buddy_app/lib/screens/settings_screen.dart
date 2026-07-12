import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/fade_slide_transition.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  bool _isSavingAndReflashing = false;

  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _ipController;
  late TextEditingController _ssidController;
  late TextEditingController _passController;
  late TextEditingController _brokerController;
  late String _selectedTimezone;

  final List<Map<String, dynamic>> _timezones = [
    {'label': 'Asia/Kolkata', 'offset': 330},
    {'label': 'UTC', 'offset': 0},
    {'label': 'America/New_York', 'offset': -300},
    {'label': 'Europe/London', 'offset': 0},
    {'label': 'Asia/Singapore', 'offset': 480},
  ];

  @override
  void initState() {
    super.initState();
    final userSettings = ref.read(settingsProvider);
    final deviceState = ref.read(deviceProvider);
    _nameController = TextEditingController(text: userSettings.userName);
    _nicknameController = TextEditingController(text: userSettings.deviceNickname);
    _ipController = TextEditingController(text: deviceState.ipAddress);
    _ssidController = TextEditingController();
    _passController = TextEditingController();
    _brokerController = TextEditingController(text: deviceState.brokerIpAddress);

    _selectedTimezone = _timezones.any((tz) => tz['label'] == deviceState.timezoneLabel)
        ? deviceState.timezoneLabel
        : 'Asia/Kolkata';
        
    _loadWifiSettings();
  }

  Future<void> _loadWifiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ssidController.text = prefs.getString('saved_wifi_ssid') ?? '';
        _passController.text = prefs.getString('saved_wifi_pass') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _ipController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    _brokerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);
    final userSettings = ref.watch(settingsProvider);
    
    final deviceNotifier = ref.read(deviceProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

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
                    Text('Settings', style: GlassStyles.titleStyle.copyWith(fontSize: 28, color: GemColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Personalization, connection & device parameters', style: GlassStyles.subtitleStyle),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. USER PROFILE CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 100),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: GemColors.accentBlue, size: 22),
                          SizedBox(width: 10),
                          Text('User Profile & Device Settings', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 14),
                        decoration: _inputDecoration('Your Name', Icons.badge_rounded),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nicknameController,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 14),
                        decoration: _inputDecoration('Device Nickname', Icons.smart_toy_rounded),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTimezone,
                        dropdownColor: GemColors.bgSecondary,
                        style: const TextStyle(
                          color: GemColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Timezone',
                          labelStyle: const TextStyle(color: GemColors.textSecondary, fontSize: 12),
                          prefixIcon: const Icon(Icons.public_rounded, color: GemColors.textSecondary, size: 18),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2))),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: GemColors.accentBlue)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        items: _timezones.map((tz) {
                          return DropdownMenuItem<String>(
                            value: tz['label'],
                            child: Text(tz['label']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedTimezone = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GemColors.accentBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _saveProfileSettings,
                          child: const Text('Save Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. HARDWARE CONNECTION & WI-FI SETUP CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 200),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.router_rounded, color: GemColors.accentBlue, size: 22),
                          SizedBox(width: 10),
                          Text('Hardware Connection', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ipController,
                        enabled: !deviceState.isSimulated,
                        style: TextStyle(color: deviceState.isSimulated ? GemColors.textSecondary.withValues(alpha: 0.5) : GemColors.textPrimary, fontSize: 14),
                        decoration: _inputDecoration('ESP32 local IP Address', Icons.lan_rounded),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            deviceNotifier.updateIpAddress(val.trim());
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ssidController,
                        enabled: !deviceState.isSimulated,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('WiFi SSID', Icons.wifi_rounded),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passController,
                        enabled: !deviceState.isSimulated,
                        obscureText: true,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('WiFi Password', Icons.password_rounded),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deviceState.isSimulated ? Colors.black.withValues(alpha: 0.05) : GemColors.accentBlue,
                            foregroundColor: deviceState.isSimulated ? GemColors.textSecondary : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: deviceState.isSimulated 
                              ? null 
                              : () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  if (_ipController.text.trim().isNotEmpty) {
                                    deviceNotifier.updateIpAddress(_ipController.text.trim());
                                  }
                                  if (_ssidController.text.trim().isNotEmpty) {
                                    await prefs.setString('saved_wifi_ssid', _ssidController.text.trim());
                                    await prefs.setString('saved_wifi_pass', _passController.text.trim());
                                  }
                                  
                                  final success = await deviceNotifier.saveSettings(
                                    wifiSsid: _ssidController.text.trim(),
                                    wifiPass: _passController.text.trim(),
                                    wifiEnabled: true,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Provision command sent!' : 'Failed to reach ESP32 setup portal.'),
                                        backgroundColor: success ? GemColors.statusActive : GemColors.statusAlert,
                                      ),
                                    );
                                  }
                                },
                          child: const Text('Connect ESP32 to Wi-Fi', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. SECURITY NOTIFICATION BROKER CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 300),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.security_rounded, color: GemColors.accentPurple, size: 22),
                              SizedBox(width: 10),
                              Text('Security Broker', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            deviceState.isBrokerConnected ? 'Active' : 'Offline',
                            style: TextStyle(
                              color: deviceState.isBrokerConnected ? GemColors.statusActive : GemColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Allows real-time notifications via WebSocket broker when LDR sensor detects sudden dark/light shifts.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _brokerController,
                              style: const TextStyle(color: GemColors.textPrimary, fontSize: 14),
                              decoration: _inputDecoration('Broker IP/Host', Icons.dns_rounded),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.03),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: deviceState.isBrokerConnected ? GemColors.statusActive : GemColors.accentBlue,
                                  width: 1,
                                ),
                              ),
                            ),
                            onPressed: () {
                              final host = _brokerController.text.trim();
                              if (host.isNotEmpty) {
                                deviceNotifier.connectToBroker(host);
                              }
                            },
                            child: Text(
                              deviceState.isBrokerConnected ? 'Connected' : 'Connect',
                              style: TextStyle(
                                color: deviceState.isBrokerConnected ? GemColors.statusActive : GemColors.accentBlue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. SAVE ALL & REFLASH CARD
              FadeSlideTransition(
                delay: const Duration(milliseconds: 350),
                child: GlassCard(
                  borderColor: _isSavingAndReflashing ? const Color(0xFFFF6B35).withValues(alpha: 0.6) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.backup_rounded, color: Color(0xFFFF6B35), size: 22),
                          SizedBox(width: 10),
                          Text('Save All & Reflash', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Backs up your profile, WiFi, alarms, and all settings to the device, then immediately flashes the latest firmware. Your data is safe after reboot.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      if (_isSavingAndReflashing) ...[
                        LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          backgroundColor: Colors.black.withValues(alpha: 0.08),
                          color: const Color(0xFFFF6B35),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_uploadStatus, style: const TextStyle(color: GemColors.textSecondary, fontSize: 12)),
                            if (_uploadProgress > 0)
                              Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: GemColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _saveAndReflash,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flash_on_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Save Settings & Reflash Firmware', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. FIRMWARE & UPDATES (OTA)
              FadeSlideTransition(
                delay: const Duration(milliseconds: 400),
                child: GlassCard(
                  borderColor: _isUploading ? GemColors.accentBlue.withValues(alpha: 0.5) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.system_update_alt_rounded, color: GemColors.accentBlue, size: 22),
                          SizedBox(width: 10),
                          Text('Firmware & OTA Update', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isUploading) ...[
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          color: GemColors.accentBlue,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_uploadStatus, style: const TextStyle(color: GemColors.textSecondary, fontSize: 12)),
                            Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: GemColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'Automatically check for and flash the latest firmware updates to your GEM device over-the-air.',
                          style: TextStyle(color: GemColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GemColors.accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _checkGithubUpdates,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_download_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: GemColors.textSecondary, fontSize: 12),
      prefixIcon: Icon(icon, color: GemColors.textSecondary, size: 18),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: GemColors.textSecondary.withValues(alpha: 0.2))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: GemColors.accentBlue)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Future<void> _checkGithubUpdates() async {
    const repo = 'shovinmd/Design-and-Development-of-Gem-Buddy-An-ESP32-Based-Smart-Desktop-Companion';

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Checking for updates...';
    });

    try {
      final url = 'https://api.github.com/repos/$repo/releases/latest';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String;
        final assets = data['assets'] as List;

        // Find binary asset
        dynamic binaryAsset;
        for (final asset in assets) {
          if ((asset['name'] as String).endsWith('.bin')) {
            binaryAsset = asset;
            break;
          }
        }

        if (binaryAsset == null) {
          setState(() {
            _isUploading = false;
          });
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: GemColors.bgPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: GemColors.glassBorder)),
                title: const Text('No Asset Found', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold)),
                content: const Text('Could not find any compiled firmware (.bin) file in the latest release.', style: TextStyle(color: GemColors.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK', style: TextStyle(color: GemColors.accentBlue)),
                  ),
                ],
              ),
            );
          }
          return;
        }

        final downloadUrl = binaryAsset['browser_download_url'] as String;
        final assetName = binaryAsset['name'] as String;

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                backgroundColor: GemColors.bgPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: GemColors.glassBorder)),
                title: const Text('Update Available', style: TextStyle(color: GemColors.textPrimary, fontWeight: FontWeight.bold)),
                content: Text(
                  'A new firmware release is available!\n\nVersion: $tagName\nFilename: $assetName\n\nDo you want to download and install this update now?',
                  style: const TextStyle(color: GemColors.textSecondary, height: 1.3),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: GemColors.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GemColors.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _downloadAndInstallFirmware(downloadUrl, assetName);
                    },
                    child: const Text('Install Update', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        }
      } else {
        throw Exception('Failed to fetch release: Status code ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking updates: $e'),
            backgroundColor: GemColors.statusAlert,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndInstallFirmware(String downloadUrl, String filename) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Downloading firmware update...';
    });

    try {
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        setState(() {
          _uploadStatus = 'Initiating OTA Flash...';
        });

        final deviceNotifier = ref.read(deviceProvider.notifier);
        final success = await deviceNotifier.uploadFirmware(
          bytes,
          filename,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatus = progress >= 1.0 
                  ? 'Finalizing reboot...' 
                  : 'Uploading firmware to GEM...';
            });
          },
        );

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Firmware update successful! GEM is rebooting.' : 'Firmware update failed.'),
              backgroundColor: success ? GemColors.statusActive : GemColors.statusAlert,
            ),
          );
        }
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update firmware: $e'),
            backgroundColor: GemColors.statusAlert,
          ),
        );
      }
    }
  }

  /// Saves ALL current settings to the device first, then flashes latest GitHub firmware.
  /// This guarantees settings survive the reflash and reboot.
  Future<void> _saveAndReflash() async {
    const repo = 'shovinmd/Design-and-Development-of-Gem-Buddy-An-ESP32-Based-Smart-Desktop-Companion';

    setState(() {
      _isSavingAndReflashing = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Step 1/3 — Saving all settings to device...';
    });

    // ── Step 1: Save everything ───────────────────────────────────────────
    try {
      final deviceNotifier = ref.read(deviceProvider.notifier);
      final settingsNotifier = ref.read(settingsProvider.notifier);
      final deviceState = ref.read(deviceProvider);
      final tzMatch = _timezones.firstWhere(
        (tz) => tz['label'] == _selectedTimezone,
        orElse: () => {'label': 'Asia/Kolkata', 'offset': 330},
      );

      await settingsNotifier.updateUserName(_nameController.text.trim());
      await settingsNotifier.updateDeviceNickname(_nicknameController.text.trim());

      await deviceNotifier.saveSettings(
        userName: _nameController.text.trim(),
        deviceName: _nicknameController.text.trim(),
        timezoneLabel: tzMatch['label'] as String,
        timezoneOffsetMinutes: tzMatch['offset'] as int,
        wifiSsid: _ssidController.text.trim().isNotEmpty ? _ssidController.text.trim() : null,
        wifiPass: _passController.text.isNotEmpty ? _passController.text : null,
        wifiEnabled: deviceState.wifiEnabled,
        alarms: deviceState.alarms,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings save failed: $e'), backgroundColor: GemColors.statusAlert),
        );
      }
      setState(() { _isSavingAndReflashing = false; });
      return;
    }

    // ── Step 2: Fetch latest release from GitHub ──────────────────────────
    setState(() { _uploadStatus = 'Step 2/3 — Checking latest firmware release...'; });
    try {
      final releaseResponse = await http.get(
        Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      ).timeout(const Duration(seconds: 10));

      if (releaseResponse.statusCode != 200) {
        throw Exception('GitHub returned ${releaseResponse.statusCode}');
      }

      final data = json.decode(releaseResponse.body);
      final assets = data['assets'] as List;
      dynamic binaryAsset;
      for (final asset in assets) {
        if ((asset['name'] as String).endsWith('.bin')) {
          binaryAsset = asset;
          break;
        }
      }

      if (binaryAsset == null) {
        throw Exception('No .bin firmware file found in the latest release.');
      }

      final downloadUrl = binaryAsset['browser_download_url'] as String;
      final filename    = binaryAsset['name'] as String;
      final tagName     = data['tag_name'] as String;

      // ── Step 3: Download & flash ────────────────────────────────────────
      setState(() { _uploadStatus = 'Step 3/3 — Downloading $filename ($tagName)...'; });

      final firmwareResponse = await http.get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 120));

      if (firmwareResponse.statusCode != 200) {
        throw Exception('Download failed: HTTP ${firmwareResponse.statusCode}');
      }

      final bytes = firmwareResponse.bodyBytes;
      setState(() { _uploadStatus = 'Flashing firmware to GEM device...'; });

      final deviceNotifier = ref.read(deviceProvider.notifier);
      final success = await deviceNotifier.uploadFirmware(
        bytes,
        filename,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatus = progress >= 1.0
                  ? '✅ Flash done — GEM is rebooting with your settings!'
                  : 'Flashing: ${(progress * 100).toStringAsFixed(0)}% complete...';
            });
          }
        },
      );

      if (mounted) {
        setState(() { _isSavingAndReflashing = false; _uploadProgress = 0.0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '🚀 Done! GEM reflashed with $tagName and all your settings preserved.'
                : '⚠️ Firmware flash failed. Settings were saved — try flashing again.'),
            backgroundColor: success ? GemColors.statusActive : GemColors.statusAlert,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSavingAndReflashing = false; _uploadProgress = 0.0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reflash failed: $e\n(Settings were already saved to the device.)'),
            backgroundColor: GemColors.statusAlert,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _saveProfileSettings() async {
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final deviceNotifier = ref.read(deviceProvider.notifier);
    final tzMatch = _timezones.firstWhere((tz) => tz['label'] == _selectedTimezone);

    // Save to user preferences provider
    await settingsNotifier.updateUserName(_nameController.text.trim());
    await settingsNotifier.updateDeviceNickname(_nicknameController.text.trim());

    if (_ipController.text.trim().isNotEmpty) {
      deviceNotifier.updateIpAddress(_ipController.text.trim());
    }

    // Save WiFi locally
    final prefs = await SharedPreferences.getInstance();
    if (_ssidController.text.trim().isNotEmpty) {
      await prefs.setString('saved_wifi_ssid', _ssidController.text.trim());
      await prefs.setString('saved_wifi_pass', _passController.text.trim());
    }

    // Save to device provider & sync with ESP32
    final success = await deviceNotifier.saveSettings(
      userName: _nameController.text.trim(),
      deviceName: _nicknameController.text.trim(),
      timezoneLabel: tzMatch['label'] as String,
      timezoneOffsetMinutes: tzMatch['offset'] as int,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile settings synced locally and with device!' : 'Profile settings saved locally.'),
          backgroundColor: success ? GemColors.statusActive : GemColors.statusWarning,
        ),
      );
    }
  }
}
