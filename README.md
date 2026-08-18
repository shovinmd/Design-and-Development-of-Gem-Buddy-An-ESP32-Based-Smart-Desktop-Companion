# GEM — Autonomous Smart Desktop Companion (v1 & v2)
**Developed by AWIE LABS** (https://awie.in)

GEM is an autonomous physical desk companion featuring interactive touch sensors, animated OLED eyes, Wi-Fi sync, dynamic LED mood lights, custom low-latency firmware, and optional biometric pulse telemetry.

---

## 🤖 Product Lineup Overview

| Feature / Hardware Specs | 🔹 GEM v1 (Standard) | 🚀 GEM v2 (Pro Biometric) |
| :--- | :---: | :---: |
| **Processor** | 32-bit Dual-Core ESP32 | 32-bit Dual-Core ESP32 |
| **Display** | 0.96" OLED Display (128x64) | 0.96" OLED Display (128x64) |
| **Touch Sensor** | Capacitive Touch Sensor | Capacitive Touch Sensor |
| **Proximity & Motion Sensor** | **IR Distance / Motion Sensor** | **IR Distance / Motion Sensor** |
| **Heart Rate & Pulse Sensor** | ❌ None | **MAX30102 PPG Pulse Sensor** |
| **Biometric Telemetry** | ❌ Standard Companion | **Real-time Pulse Oximeter & App Sync** |
| **RGB Mood Lighting** | Addressable WS2812B Hair LEDs | Addressable WS2812B Hair LEDs |
| **Connectivity** | Wi-Fi 2.4GHz + BLE | Wi-Fi 2.4GHz + BLE |
| **Power Management** | Rechargeable LiPo Battery | Rechargeable LiPo Battery |
| **Pre-Book Status** | **Open Soon** | **Open Soon** |

---

## 📁 Repository Structure

```
GEM/
├── GEM_v1_Firmware/             # Base firmware without pulse sensor (IR motion + Touch + OLED)
│   ├── GEM_v1_Firmware.ino
│   ├── GemBuddyConfig.h
│   └── eyes.h
├── GEM_v2_Firmware/             # Pro firmware with MAX30102 Heart Rate + IR motion sensor
│   ├── GEM_v2_Firmware.ino
│   ├── GemBuddyConfig.h
│   └── eyes.h
├── gem_buddy_app/               # Flutter mobile companion application
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
