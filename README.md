# GEM — Autonomous Smart Desktop Companion (v1 & v2)
**Developed by AWIE LABS** (https://awie.in)

GEM is an autonomous physical desk companion featuring interactive touch sensors, animated OLED eyes, Wi-Fi sync, 4 White LED ambient bulbs, custom low-latency firmware, and optional biometric pulse & motion telemetry in v2 Pro.

---

## 🤖 Product Lineup Overview

| Feature / Hardware Specs | 🔹 GEM v1 (Standard) | 🚀 GEM v2 Pro (Biometric & Motion) |
| :--- | :---: | :---: |
| **Processor** | 32-bit Dual-Core ESP32 | 32-bit Dual-Core ESP32 |
| **Display** | 0.96" OLED Display (128x64) | 0.96" OLED Display (128x64) |
| **Touch Sensor** | Capacitive Touch Sensor | Capacitive Touch Sensor |
| **Motion & Proximity Sensor** | ❌ None | **IR Distance / Motion Sensor** |
| **Heart Rate & Pulse Sensor** | ❌ None | **MAX30102 PPG Pulse Sensor** |
| **Biometric Telemetry** | ❌ Standard Companion | **Real-time Pulse, SpO2 & Motion App Sync** |
| **LED Lighting** | **4 White LED Bulbs** (Pure White) | **4 White LED Bulbs** (Pulse-Synced) |
| **Battery & Charging** | **1000mAh Rechargeable LiPo** | **1500mAh Rechargeable LiPo** |
| **Mobile App Support** | **GEM App** (Wi-Fi 2.4GHz + BLE) | **GEM App** (Wi-Fi 2.4GHz + BLE) |
| **Pre-Book Status** | **Open Soon** | **Open Soon** |

---

## 📁 Repository Structure

```
GEM/
├── GEM_v1_Firmware/             # Base firmware (4 White LEDs + Touch + OLED + 1000mAh)
│   ├── GEM_v1_Firmware.ino
│   ├── GemBuddyConfig.h
│   └── eyes.h
├── GEM_v2_Firmware/             # Pro firmware (MAX30102 Heart Sensor + IR Motion + 4 White LEDs + 1500mAh)
│   ├── GEM_v2_Firmware.ino
│   ├── GemBuddyConfig.h
│   └── eyes.h
├── gem_buddy_app/               # Flutter mobile companion application (GEM App)
├── gem_server/                  # Node.js / Express backend sync server
├── gem_website/                 # GEM showcase web application
└── README.md
```

---

## ⚙️ How to Flash Firmware

### For GEM v1:
1. Open Arduino IDE or PlatformIO.
2. Select target board: `ESP32 Dev Module`.
3. Open `GEM_v1_Firmware/GEM_v1_Firmware.ino`.
4. Flash via Micro-USB / USB-C port.

### For GEM v2:
1. Open `GEM_v2_Firmware/GEM_v2_Firmware.ino`.
2. Ensure `Adafruit_MAX30105` or `MAX30105` library is installed in Arduino IDE.
3. Flash via Micro-USB / USB-C port.

---

© 2026 AWIE LABS. All rights reserved. (https://awie.in)
