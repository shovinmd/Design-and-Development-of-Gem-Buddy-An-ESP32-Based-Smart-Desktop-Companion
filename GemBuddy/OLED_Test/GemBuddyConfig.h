#pragma once

#include <Arduino.h>

// ---------------- Pin Map ----------------
// OLED I2C
constexpr uint8_t PIN_OLED_SDA = 21;
constexpr uint8_t PIN_OLED_SCL = 22;
// Touch sensor input
constexpr uint8_t PIN_TOUCH = 4;   // Boot strap pin, keep idle LOW at reset.
// ADC1 inputs so Wi-Fi can stay compatible
constexpr uint8_t PIN_LDR_ADC = 35;
constexpr uint8_t PIN_BATTERY_ADC = 34;
// LED outputs
constexpr uint8_t PIN_LED1 = 25;
constexpr uint8_t PIN_LED2 = 26;
constexpr uint8_t PIN_LED3 = 27;
constexpr uint8_t PIN_LED4 = 14;
// Heart sensor
constexpr uint8_t PIN_PULSE_ADC = 32;
constexpr uint8_t PIN_PULSE_POWER = 13;
// Sound
constexpr uint8_t PIN_BUZZER = 33;

// ---------------- Firmware Identity ----------------
constexpr const char* GEM_DEVICE_PREFIX = "GEM";
constexpr const char* GEM_PREF_NAMESPACE = "gembuddy";
constexpr uint32_t GEM_SETTINGS_MAGIC = 0x47454D42; // GEMB
constexpr uint16_t GEM_SETTINGS_VERSION = 2;

// ---------------- Timing ----------------
constexpr uint32_t BOOT_WELCOME_MS = 2000;
constexpr uint32_t FACE_FRAME_MS_DAY = 180;
constexpr uint32_t FACE_FRAME_MS_EVENING = 260;
constexpr uint32_t FACE_FRAME_MS_NIGHT = 420;
constexpr uint32_t FACE_FRAME_MS_PET = 120;
constexpr uint32_t TIME_OVERLAY_MS = 3000;
constexpr uint32_t AUTO_TIME_PEEK_MS = 15000;
constexpr uint32_t LDR_SAMPLE_MS = 45000;
constexpr uint32_t BATTERY_SAMPLE_MS = 180000;
constexpr uint32_t OLED_REFRESH_MS = 120;
constexpr uint32_t HEART_SAMPLE_MS = 12;
constexpr uint32_t TAP_WINDOW_MS = 420;
constexpr uint32_t LONG_TOUCH_MS = 900;
constexpr uint32_t ALARM_CHECK_MS = 1000;
constexpr uint32_t CLOUD_EVENT_COOLDOWN_MS = 60000;
constexpr uint32_t HEART_MODE_TIMEOUT_MS = 30000;

// ---------------- OLED / Face ----------------
constexpr uint8_t OLED_WIDTH = 128;
constexpr uint8_t OLED_HEIGHT = 64;
constexpr uint8_t OLED_CONTRAST_DAY = 255;
constexpr uint8_t OLED_CONTRAST_EVENING = 120;
constexpr uint8_t OLED_CONTRAST_NIGHT = 35;

// ---------------- Battery ----------------
constexpr float BATTERY_MIN_VOLTAGE = 3.20f;
constexpr float BATTERY_MAX_VOLTAGE = 4.20f;
constexpr float BATTERY_DIVIDER_RATIO = 2.0f;

// ---------------- Lamp / LEDs ----------------
constexpr uint8_t LED_BRIGHTNESS_MAX = 255;
constexpr uint8_t LED_BRIGHTNESS_MIN = 16;

// ---------------- Settings ----------------
struct GemAlarm {
  bool enabled = false;
  uint8_t hour = 7;
  uint8_t minute = 0;
  char name[24] = "Alarm";
};

struct GemSettings {
  uint32_t magic = GEM_SETTINGS_MAGIC;
  uint16_t version = GEM_SETTINGS_VERSION;

  char userName[24] = "Friend";
  char deviceName[24] = "GEM";
  char timezoneLabel[40] = "Asia/Calcutta";
  int32_t timezoneOffsetMinutes = 330;

  char wifiSsid[32] = "";
  char wifiPass[64] = "";
  bool wifiEnabled = false;
  bool setupComplete = false;
  bool hotspotEnabled = false;

  bool monitoringEnabled = false;
  char cloudWebhook[128] = "";

  bool lampState = false;
  uint8_t lampMode = 0;
  uint8_t lampBrightness = 140;
  uint8_t ledAutoOffMinutes = 10;

  uint8_t alarmCount = 2;
  GemAlarm alarms[3];
};
