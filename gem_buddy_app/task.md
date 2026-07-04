# GEM Companion App — Task List

- `[x]` **Phase 1: Project Setup & Initialization**
  - `[x]` Create Flutter project `gem_buddy_app` in workspace
  - `[x]` Configure app package and name to **GEM**
  - `[x]` Update `pubspec.yaml` with Riverpod, HTTP, SharedPreferences, and standard assets/icons
  - `[x]` Set up Android output configurations to rename compiled APK to `GEM.apk`

- `[x]` **Phase 2: Liquid Glass Design System**
  - `[x]` Create colors palette in `theme/colors.dart`
  - `[x]` Define glass containers, borders, and shadows in `theme/glass_styles.dart`
  - `[x]` Implement reusable `GlassCard` widget
  - `[x]` Implement `FloatingGlassNavBar` navigation bar

- `[x]` **Phase 3: Widgets & OLED Face Painter**
  - `[x]` Build custom `OledFacePainter` for Canvas OLED face representation
  - `[x]` Create `OledFaceWidget` with animations (Zzz, heart floaties, blinking, sleeping, alarm, scanning)
  - `[x]` Develop helper layouts for Bento grid structures

- `[x]` **Phase 4: State Management & API Integration**
  - `[x]` Implement Riverpod Device state provider (`device_provider.dart`)
  - `[x]` Build HTTP integration functions mapping to `/api/state`, `/api/save`, `/api/time`
  - `[x]` Add a comprehensive fallback Simulated Mode for when the ESP32 is offline
  - `[x]` Implement local settings persistence provider (`settings_provider.dart`)
  - `[x]` Implement event logger & local history timeline (`timeline_provider.dart`)
  - `[x]` Implement 3D Model carousel and status display
  - `[x]` Update `lib/screens/home_screen.dart` to cycle 3D images every 3 seconds
  - `[x]` Overlay connection and LDR state on home screen
  - `[x]` Remove battery monitoring UI elements

- `[x]` **Phase 5: Page Developments**
  - `[x]` Develop Home Dashboard page (`home_screen.dart`)
  - `[x]` Develop Control page (`control_screen.dart`) with Alarms list and LED controls
  - `[x]` Develop Security page (`security_screen.dart`)
  - `[x]` Develop Timeline history page (`timeline_screen.dart`)
  - `[x]` Develop Settings & Setup page (`settings_screen.dart`)

- `[x]` **Phase 6: Circular Eyes & OTA System Updates**
  - `[x]` Redesign `OledFaceWidget` eyes to match F9:Iris circular look (Flutter)
  - `[x]` Align eyes and mouth symmetrically in the Flutter UI canvas
  - `[x]` Update `drawFaceEyes` and eye coordinates in `GemBuddy.ino` (ESP32)
  - `[x]` Integrate `<Update.h>` OTA API at `/api/update` in `GemBuddy.ino`
  - `[x]` Add `file_picker` dependency to `pubspec.yaml`
  - `[x]` Implement `uploadFirmware` in `device_provider.dart`
  - `[x]` Add OTA update upload button in `settings_screen.dart`

- `[x]` **Phase 7: Node.js Webhook Broker Server**
  - `[x]` Create `server.js` with Express + WebSocket handling (ESP32 webhook -> WebSocket)
  - `[x]` Setup WebSocket client listening in `device_provider.dart` to show live local notifications
  - `[x]` Create documentation on running the node server

- `[x]` **Phase 8: App Icon & Launcher Branding**
  - `[x]` Place the premium generated gem logo as the launcher icon asset
  - `[x]` Configure `flutter_launcher_icons` and generate Android/iOS icons
  - `[x]` Perform final compilation build test of the APK
