import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _ipController;
  late TextEditingController _ssidController;
  late TextEditingController _passController;
  late TextEditingController _brokerController;
  late String _selectedTimezone;
  int _hotspotTimeout = 20;

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
    _hotspotTimeout = deviceState.hotspotTimeoutMinutes;
        
    _loadWifiSettings();
  }

  Future<void> _loadWifiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ssidController.text = prefs.getString('saved_wifi_ssid') ?? '';
        _passController.text = prefs.getString('saved_wifi_pass') ?? '';
        _hotspotTimeout = prefs.getInt('saved_hotspotTimeoutMinutes') ?? ref.read(deviceProvider).hotspotTimeoutMinutes;
      });
    }
  }

  void _scanWifiNetworks() async {
    final deviceState = ref.read(deviceProvider);
    if (deviceState.isSimulated) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(GemColors.accentBlue),
        ),
      ),
    );
    final networks = await ref.read(deviceProvider.notifier).scanWifiNetworks();
    if (mounted) Navigator.of(context).pop(); // pop loading

    if (networks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No 2.4GHz WiFi networks found.'),
            backgroundColor: GemColors.statusAlert,
          ),
        );
      }
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: GemColors.bgSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available WiFi Networks',
                    style: TextStyle(
                      color: GemColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select a 2.4GHz network to connect your GEM Buddy',
                    style: TextStyle(
                      color: GemColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: networks.length,
                      itemBuilder: (context, index) {
                        final net = networks[index];
                        final ssid = net['ssid'] ?? '';
                        final rssi = net['rssi'] ?? -100;
                        final enc = net['encryption'] ?? 0;
                        final isSecure = enc != 0;

                        return ListTile(
                          leading: Icon(
                            Icons.wifi_rounded,
                            color: GemColors.accentBlue.withValues(alpha: rssi > -60 ? 1.0 : rssi > -75 ? 0.7 : 0.4),
                          ),
                          title: Text(
                            ssid,
                            style: const TextStyle(color: GemColors.textPrimary),
                          ),
                          subtitle: Text(
                            'Signal: $rssi dBm',
                            style: const TextStyle(color: GemColors.textSecondary, fontSize: 11),
                          ),
                          trailing: isSecure
                              ? const Icon(Icons.lock_rounded, color: GemColors.textSecondary, size: 16)
                              : null,
                          onTap: () {
                            setState(() {
                              _ssidController.text = ssid;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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
                        decoration: _inputDecoration('WiFi SSID', Icons.wifi_rounded).copyWith(
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded, color: GemColors.accentBlue),
                            tooltip: 'Scan WiFi Networks',
                            onPressed: deviceState.isSimulated ? null : _scanWifiNetworks,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passController,
                        enabled: !deviceState.isSimulated,
                        obscureText: true,
                        style: const TextStyle(color: GemColors.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('WiFi Password', Icons.password_rounded),
                      ),

                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: _hotspotTimeout,
                        dropdownColor: GemColors.bgSecondary,
                        style: const TextStyle(
                          color: GemColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: _inputDecoration('Hotspot Hosting Window', Icons.wifi_tethering_rounded),
                        items: const [
                          DropdownMenuItem<int>(value: 0, child: Text('Always On')),
                          DropdownMenuItem<int>(value: 20, child: Text('20 min')),
                          DropdownMenuItem<int>(value: 40, child: Text('40 min')),
                          DropdownMenuItem<int>(value: 60, child: Text('1 hr')),
                          DropdownMenuItem<int>(value: 120, child: Text('2 hr')),
                        ],
                        onChanged: deviceState.isSimulated ? null : (val) {
                          if (val != null) {
                            setState(() {
                              _hotspotTimeout = val;
                            });
                          }
                        },
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
                                    await prefs.setInt('saved_hotspotTimeoutMinutes', _hotspotTimeout);
                                  }
                                  
                                  final error = await deviceNotifier.saveSettings(
                                    wifiSsid: _ssidController.text.trim(),
                                    wifiPass: _passController.text.trim(),
                                    wifiEnabled: true,
                                    hotspotTimeoutMinutes: _hotspotTimeout,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error == null ? 'Provision command sent!' : 'Provisioning failed: $error'),
                                        backgroundColor: error == null ? GemColors.statusActive : GemColors.statusAlert,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. FIRMWARE & UPDATES (OTA)
              FadeSlideTransition(
                delay: const Duration(milliseconds: 350),
                child: GlassCard(
                  borderColor: _isUploading ? GemColors.accentBlue.withValues(alpha: 0.5) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.system_update_alt_rounded, color: GemColors.accentBlue, size: 22),
                          SizedBox(width: 10),
                          Text('Update Device', style: TextStyle(color: GemColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Flash the bundled firmware update directly to your GEM device over-the-air in the background.',
                        style: TextStyle(color: GemColors.textSecondary, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Creator', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                                Text('Shovin', style: TextStyle(color: GemColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Device Version', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                                Text(
                                  deviceState.isSimulated 
                                      ? '1.6 (Simulated)' 
                                      : (deviceState.firmwareVersion.isEmpty ? 'Unknown' : deviceState.firmwareVersion), 
                                  style: const TextStyle(color: GemColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Available Update', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                                Text('1.6', style: TextStyle(color: GemColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Release Date', style: TextStyle(color: GemColors.textSecondary, fontSize: 13)),
                                Text('July 19, 2026', style: TextStyle(color: GemColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
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
                      ] else
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GemColors.accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _flashFirmwareBackground,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.system_update_alt_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
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

  Future<void> _flashFirmwareBackground() async {
    final deviceState = ref.read(deviceProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    if (!deviceState.isConnected && !deviceState.isSimulated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: App is not connected to the GEM device. Please check your Wi-Fi connection.'),
            backgroundColor: GemColors.statusAlert,
          ),
        );
      }
      return;
    }

    final bool isUpToDate = deviceState.firmwareVersion == '1.6';
    String titleText = 'Update Device?';
    String messageText = 'Do you want to flash the update? The GEM device will reboot automatically once completed.';
    String confirmButtonText = 'Update';

    if (isUpToDate) {
      titleText = 'Device Up to Date';
      messageText = 'Your GEM device is already running the latest firmware version (1.6). Do you still want to re-flash and override it?';
      confirmButtonText = 'Override';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          borderColor: GemColors.accentBlue.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    color: GemColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  messageText,
                  style: const TextStyle(
                    color: GemColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: GemColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GemColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(true),
                      child: Text(confirmButtonText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadStatus = 'Loading firmware asset...';
      });

      final byteData = await rootBundle.load('assets/firmware.bin');
      final fileBytes = byteData.buffer.asUint8List();

      if (mounted) {
        setState(() {
          _uploadStatus = 'Uploading firmware...';
        });
      }

      StateSetter? dialogStateSetter;
      bool dialogOpen = true;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              dialogStateSetter = setDialogState;
              return Dialog(
                backgroundColor: Colors.transparent,
                child: GlassCard(
                  borderColor: GemColors.accentBlue.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Firmware Update',
                              style: TextStyle(
                                color: GemColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: GemColors.textSecondary, size: 20),
                              onPressed: () {
                                deviceNotifier.cancelUpload();
                                Navigator.of(dialogCtx).pop();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(color: GemColors.accentBlue),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          color: GemColors.accentBlue,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _uploadStatus,
                                style: const TextStyle(color: GemColors.textSecondary, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: GemColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: GemColors.statusAlert),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              deviceNotifier.cancelUpload();
                              Navigator.of(dialogCtx).pop();
                            },
                            child: const Text(
                              'Cancel Update',
                              style: TextStyle(
                                color: GemColors.statusAlert,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ).then((_) => dialogOpen = false);

      const password = '123456789';
      final success = await deviceNotifier.uploadFirmware(
        fileBytes,
        'firmware.bin',
        password: password,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatus = progress >= 1.0
                  ? '✅ Upload complete — GEM is rebooting!'
                  : 'Uploading: ${(progress * 100).toStringAsFixed(0)}%';
            });
            if (dialogStateSetter != null) {
              dialogStateSetter!(() {});
            }
          }
        },
      );

      if (dialogOpen && mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Firmware update successful! GEM is rebooting.' : 'Firmware update failed or cancelled.'),
            backgroundColor: success ? GemColors.statusActive : GemColors.statusAlert,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: GemColors.statusAlert,
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
    final error = await deviceNotifier.saveSettings(
      userName: _nameController.text.trim(),
      deviceName: _nicknameController.text.trim(),
      wifiSsid: _ssidController.text.trim().isNotEmpty ? _ssidController.text.trim() : null,
      wifiPass: _passController.text.trim().isNotEmpty ? _passController.text.trim() : null,
      timezoneLabel: tzMatch['label'] as String,
      timezoneOffsetMinutes: tzMatch['offset'] as int,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error == null ? 'Profile settings synced locally and with device!' : 'Sync failed: $error'),
          backgroundColor: error == null ? GemColors.statusActive : GemColors.statusWarning,
        ),
      );
    }
  }
}
