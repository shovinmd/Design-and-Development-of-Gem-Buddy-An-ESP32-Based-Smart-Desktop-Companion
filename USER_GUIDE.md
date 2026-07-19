# GEM Buddy — User & Connection Guide (v1.8)

Welcome to your smart desktop companion! GEM Buddy is designed to keep your desk secure, connected, and smarter every day.

---

## 📟 1. Hardware Overview & Device Views

### Physical Layout
- **1. OLED Display:** 1.3" Screen showing emotions, status, Wi-Fi, battery level, and notifications.
- **2. Status LEDs:** Multicolor LEDs on the sides indicating the device state.
- **3. Touch Sensor:** Capacitive touch zone on top for petting, clearing alerts, or toggling Guard Mode.
- **4. USB Type-C Port:** Located on the back for charging and flashing firmware.
- **5. Power Switch:** Slide switch on the back to turn GEM ON/OFF.

### Device Views
- **Top View:** Touch Sensor Area (top cap).
- **Back View:** USB-C Port, Power Switch.
- **Bottom View:** Non-slip Feet, Speaker Grill.

---

## ⚡ 2. Powering & Booting GEM

### Power Options
- **Battery Power:** 600mAh Li-Po Battery providing **3–4 Hours** of wireless backup.
- **Plugged Power:** Recommended for continuous always-on desktop usage (5V 1A USB-C input).
- **Charging Time:** **1–2 Hours** to fully charge via USB Type-C.

### Boot Sequence
Slide the power switch to **ON**. GEM will boot through the following states:
1. **Power ON**
2. **Boot Logo** (OLED displays GEM logo)
3. **Loading...** (System initialization & sensor calibration)
4. **Wi-Fi Connect** (Linking to local wireless network)
5. **Ready** (Happy face active)

### Charge Indicator (LEDs)
When charging, the indicator shows:
- 🔴 **Red:** Charging
- 🔵 **Blue:** Fully Charged (turns blue when complete)

---

## 📶 3. Wi-Fi & App Sync Setup

### Local Connection (Same Wi-Fi)
1. Connect GEM to your Wi-Fi (pre-configured in firmware).
2. GEM's display will show its local IP address.
3. Connect your phone to the same Wi-Fi network.
4. Open the **GEM Buddy App** on your phone.
5. The app will auto-discover and connect to your GEM.

### Cloud Fallback (Different Network / Remote Sync)
1. If on a different network, the app connects to the **Node.js Cloud Broker**.
2. Settings, logs, and alarms are synced securely to the cloud database.
3. The Broker relays remote commands and configuration updates to GEM.
4. This fallback ensures remote connectivity even behind firewalls.

---

## 🛡️ 4. Desk Guard Security Mode

Your active sentinel for the workspace.

### How to Arm / Disarm
- **Via App:** Tap the **Guard Mode** toggle switch on the dashboard.
- **Via Device:** Press and hold the capacitive touch sensor on top of GEM for **2 seconds**.

### Incident Triggers
- **Intruder Shadow Detected:** Light levels suddenly drop (e.g. someone blocking the light).
- **Flash Detected:** Sudden bright light spike (e.g. flashlight or strong light flash).
- **Touch Detected:** Physical touch or movement of the GEM device.

### Alarm & Notifications
- **Trigger:** LEDs flash **Red** and the **Buzzer** sounds.
- **Relay:** Webhook alert is instantly sent to the Cloud Broker.
- **Notification:** A Firebase Cloud Message (FCM) Push Notification is delivered to your phone.
- **To Silence:** Tap the touch sensor on GEM or tap "Disarm" in the app.

---

## 😊 5. OLED Expressions & Touch Input

GEM has feelings too!
- **Happy:** Normal state. Everything is good!
- **Sleep Mode:** Low light levels detected or sleep manually enabled (floats Zzz particles).
- **Alert / Angry:** Security trigger active or device moved.
- **Greeting:** Capacitive touch detected! Displays friendly eyes.

*Tip: Tap the touch sensor to interact, pet GEM, or clear warning screens.*

---

## 🔄 6. OTA (Over-The-Air) Firmware Updates

Keep GEM up-to-date wirelessly.
1. **Open App:** Go to **Settings** -> **OTA Update**.
2. **Check Updates:** Tap to scan for new firmware versions.
3. **Download:** If a new update is found, tap **Flash OTA**.
4. **Transfer:** The firmware file is wirelessly streamed to GEM.
5. **Install & Reboot:** GEM installs the updates and restarts automatically.

⚠️ **Important Update Rules:**
- Do not power off the device during updates.
- Keep a stable Wi-Fi connection.
- Ensure GEM is plugged into USB power during updates.

---

## 🚦 LED Status Guide

Refer to the multicolor side LEDs to understand GEM's current status:
- 🔵 **Blinking Blue:** Booting / Connecting to Wi-Fi
- 🔵 **Solid Blue:** Connected / Normal Operation
- 🟢 **Blinking Green:** Guard Mode Armed & Active
- 🔴 **Blinking Red:** Alert / Incident Triggered
- 🟡 **Blinking Yellow:** Updating Firmware
- 🟣 **Blinking Purple:** Syncing with Cloud

---

## ⚙️ Specifications

- **MCU:** ESP32 Dual-Core
- **Display:** 1.3" OLED (128x64 resolution)
- **Wi-Fi:** 2.4GHz 802.11 b/g/n
- **Battery:** 600mAh Li-Po
- **Backup:** 3–4 Hours active backup
- **Charging:** 5V 1A (USB-C)
- **Sensors:** LDR Light Sensor, Capacitive Touch
- **Audio:** Onboard Buzzer
- **Connectivity:** Wi-Fi, HTTP, Webhooks
- **Cloud Broker:** Node.js Web Server
- **OTA Updates:** Wireless via Wi-Fi
- **Operating Temp:** 0°C – 50°C

---

## 📦 What's in the Box

1. **GEM Buddy Device**
2. **USB Type-C Cable**
3. **User Guide** (You are reading it!)
4. **Thank You Card**

---

## 🛡️ Safety & Care

- Use standard 5V USB power adapters.
- Keep the device away from water and extreme heat.
- Do not drop or apply strong force.
- Clean the device screen and body with a soft, dry cloth.
- For best performance, keep the firmware updated via the app.
