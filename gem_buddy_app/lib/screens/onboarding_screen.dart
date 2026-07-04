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

  int _currentStep = 0; // 0: Connect to Hotspot Guide, 1: Configuration Form
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _currentStep == 0 ? _buildHotspotStep() : _buildConfigStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHotspotStep() {
    return Column(
      key: const ValueKey('hotspot_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        const PulsingWifiIcon(),
        const SizedBox(height: 24),
        
        Text(
          'CONNECT TO GEM',
          style: GlassStyles.titleStyle.copyWith(
            fontSize: 24,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connect to the companion device hotspot first',
          textAlign: TextAlign.center,
          style: GlassStyles.subtitleStyle,
        ),
        const SizedBox(height: 24),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Setup Instructions',
                style: TextStyle(
                  color: GemColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildStepItem(
                1,
                'Power On GEM Buddy',
                'Turn on your companion device and wait for the greeting screen to display instruction details.',
              ),
              _buildStepItem(
                2,
                'Open Wi-Fi Settings',
                'Go to your phone\'s Settings > Wi-Fi and search for nearby networks.',
              ),
              _buildStepItem(
                3,
                'Connect to network',
                'Select "GEM Buddy" and connect. No password is required by default, or enter "12345678" if prompted.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'I AM CONNECTED',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('config_step'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header Row with Back Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: GemColors.textSecondary),
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                  });
                },
              ),
              const Expanded(
                child: Text(
                  'DEVICE CONFIGURATION',
                  style: TextStyle(
                    color: GemColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                  initialValue: _selectedTimezone,
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
    );
  }

  Widget _buildStepItem(int number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: GemColors.accentBlue,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: GemColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: GemColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class PulsingWifiIcon extends StatefulWidget {
  const PulsingWifiIcon({super.key});

  @override
  State<PulsingWifiIcon> createState() => _PulsingWifiIconState();
}

class _PulsingWifiIconState extends State<PulsingWifiIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GemColors.accentBlue.withValues(alpha: 0.05),
          border: Border.all(
            color: GemColors.accentBlue.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: GemColors.accentBlue.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.wifi_rounded,
          size: 64,
          color: GemColors.accentBlue,
        ),
      ),
    );
  }
}
