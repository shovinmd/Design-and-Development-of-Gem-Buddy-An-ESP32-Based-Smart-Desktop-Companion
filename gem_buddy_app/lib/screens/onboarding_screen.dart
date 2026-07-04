import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../theme/glass_styles.dart';
import '../widgets/glass_card.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Shovin');
  final _nicknameController = TextEditingController(text: 'GEM');
  final _wifiSsidController = TextEditingController();
  final _wifiPassController = TextEditingController();
  
  String _selectedTimezone = 'Asia/Kolkata';
  final List<Map<String, dynamic>> _timezones = [
    {'label': 'Asia/Kolkata', 'offset': 330},
    {'label': 'UTC', 'offset': 0},
    {'label': 'America/New_York', 'offset': -300},
    {'label': 'Europe/London', 'offset': 0},
    {'label': 'Asia/Singapore', 'offset': 480},
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    super.dispose();
  }

  Future<void> _submitSetup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSubmitting = true;
    });

    final deviceNotifier = ref.read(deviceProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Save locally to preferences
    await settingsNotifier.updateUserName(_nameController.text.trim());
    await settingsNotifier.updateDeviceNickname(_nicknameController.text.trim());
    await settingsNotifier.updateSetupComplete(true);

    // Find selected offset
    final tzMatch = _timezones.firstWhere((tz) => tz['label'] == _selectedTimezone);
    
    // Save to the physical/simulated device via network call
    final success = await deviceNotifier.saveSettings(
      userName: _nameController.text.trim(),
      deviceName: _nicknameController.text.trim(),
      wifiSsid: _wifiSsidController.text.isNotEmpty ? _wifiSsidController.text.trim() : null,
      wifiPass: _wifiPassController.text.isNotEmpty ? _wifiPassController.text : null,
      wifiEnabled: _wifiSsidController.text.isNotEmpty,
      timezoneLabel: tzMatch['label'] as String,
      timezoneOffsetMinutes: tzMatch['offset'] as int,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Connection established! GEM is synced.'),
            backgroundColor: GemColors.statusActive,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Device saved in offline standby mode.'),
            backgroundColor: GemColors.statusWarning,
          ),
        );
        // Force state complete locally to let user continue
        deviceNotifier.setSimulationMode(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GemColors.accentBlue.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.android_rounded,
                            size: 60,
                            color: GemColors.accentBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Brand Header
                  Text(
                    'GEM BUDDY',
                    style: GlassStyles.titleStyle.copyWith(
                      fontSize: 28,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set up your smart desk companion',
                    textAlign: TextAlign.center,
                    style: GlassStyles.subtitleStyle,
                  ),
                  const SizedBox(height: 24),

                  // Main Setup Form Glass Card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Settings',
                          style: TextStyle(
                            color: GemColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // User Name Input
                        _buildInputField(
                          controller: _nameController,
                          label: 'Your Name',
                          icon: Icons.person_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Device Nickname Input
                        _buildInputField(
                          controller: _nicknameController,
                          label: 'GEM Nickname',
                          icon: Icons.smart_toy_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please name your device';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Timezone Dropdown Input
                        DropdownButtonFormField<String>(
                          value: _selectedTimezone,
                          dropdownColor: GemColors.bgSecondary,
                          style: const TextStyle(
                            color: GemColors.textPrimary,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Timezone',
                            labelStyle: const TextStyle(color: GemColors.textSecondary),
                            prefixIcon: const Icon(Icons.public_rounded, color: GemColors.accentBlue),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: GemColors.accentBlue.withValues(alpha: 0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: GemColors.accentBlue.withValues(alpha: 0.1)),
                            ),
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
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: GemColors.glassBorder),
                        ),

                        const Text(
                          'Wi-Fi Connection (Optional)',
                          style: TextStyle(
                            color: GemColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // WiFi SSID Input
                        _buildInputField(
                          controller: _wifiSsidController,
                          label: 'Wi-Fi SSID',
                          icon: Icons.wifi_rounded,
                        ),
                        const SizedBox(height: 12),

                        // WiFi Password Input
                        _buildInputField(
                          controller: _wifiPassController,
                          label: 'Wi-Fi Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connect & Save Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GemColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'CONNECT & START',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        color: GemColors.textPrimary,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: GemColors.textSecondary),
        prefixIcon: Icon(icon, color: GemColors.accentBlue),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GemColors.accentBlue.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GemColors.accentBlue.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}
