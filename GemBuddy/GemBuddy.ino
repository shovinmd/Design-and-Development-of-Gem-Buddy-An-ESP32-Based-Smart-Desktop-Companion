#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <U8g2lib.h>
#include <time.h>
#include <cstring>
#include <esp_sleep.h>
#include <Update.h>
#include <ESPmDNS.h>

#include "GemBuddyConfig.h"
#include "eyes.h"

// ---------------- Forward Declarations ----------------
void openSetupPortal(bool initial, uint32_t durationMs = 10UL * 60UL * 1000UL);
void setupNetworking();

// ---------------- Display ----------------
// For SH1106 OLED screens (fixes the 2-pixel shift/glitch line on the left side)
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);
// For SSD1306 OLED screens (uncomment if using SSD1306)
// U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);

// ---------------- Runtime ----------------
Preferences prefs;
WebServer server(80);

GemSettings settings;
bool restartPending = false;
uint32_t restartAtMs = 0;
bool networkingPending = false;
uint32_t networkingAtMs = 0;

enum FaceMode {
  FACE_DAY,
  FACE_EVENING,
  FACE_NIGHT,
  FACE_WELCOME,
  FACE_MENU,
  FACE_PET,
  FACE_TIME,
  FACE_HEART,
  FACE_ALARM,
  FACE_INFO,
  FACE_WIFI_SETUP,
  FACE_CONFIGURING
};

enum LampMode {
  LAMP_STATIC = 0,
  LAMP_BREATHING = 1,
  LAMP_SLOW_BLINK = 2,
  LAMP_PULSE = 3,
  LAMP_FLASH = 4
};

struct TouchRuntime {
  bool pressed = false;
  bool longHandled = false;
  uint32_t pressedAt = 0;
  uint32_t lastTapAt = 0;
  uint8_t tapCount = 0;
};

struct RuntimeState {
  bool welcomeActive = false;
  uint32_t welcomeUntil = 0;
  int welcomeStep = 0;

  // Picaio eye animation state variables
  int picaioXp = 16;
  int picaioMood = 0;
  int picaioXd = 0;
  bool isBlinking = false;
  uint32_t nextBlinkMs = 0;
  uint32_t blinkEndMs = 0;

  bool menuOpen = false;
  uint8_t menuIndex = 0;
  uint32_t menuUntil = 0;

  bool petActive = false;
  uint32_t petUntil = 0;

  uint32_t lastGreetingAt = 0;
  bool greetingBubbleActive = false;
  uint32_t greetingBubbleUntil = 0;
  uint8_t greetingIndex = 0;

  bool timeOverlayActive = false;
  uint32_t timeOverlayUntil = 0;
  uint32_t lastAutoTimePeek = 0;

  bool alarmActive = false;
  uint32_t alarmUntil = 0;
  uint8_t alarmIndex = 255;
  uint32_t alarmToneStepAt = 0;
  uint8_t alarmToneStep = 0;

  bool heartModeActive = false;
  uint32_t heartModeUntil = 0;
  float pulseBaseline = 0.0f;
  bool pulseAbove = false;
  uint32_t lastBeatMs = 0;
  uint16_t bpm = 0;
  uint32_t lastPulseSampleAt = 0;
  bool fingerPresent = false;
  uint32_t fingerDetectedAt = 0;
  bool pulseCalibrated = false;
  uint8_t bpmValidCount = 0;
  bool alarmMissed = false;
  uint8_t missedAlarmIndex = 255;
  uint32_t lastAppRequestAt = 0;
  uint32_t lastGuardPingMs = 0;  // last time we POSTed a keepalive ping

  bool lampNotificationFlash = false;
  uint32_t lampNotificationUntil = 0;
  uint32_t lampLastTick = 0;

  uint32_t lastFaceFrame = 0;
  uint32_t lastOledUpdate = 0;
  uint32_t lastBatteryRead = 0;
  uint32_t lastLdrRead = 0;
  uint32_t lastAlarmCheck = 0;
  uint32_t lastCloudEvent = 0;
  bool hotspotActiveState = true;
  uint32_t hotspotStateTimer = 0;

  int batteryPercent = 100;
  float batteryVoltage = 4.2f;
  uint16_t ldrRaw = 0;
  bool ambientDark = false;
  bool batteryCritical = false;
  bool batterySaver = false;
  bool deepSleepReady = false;

  FaceMode faceMode = FACE_WELCOME;
  int eyeOffsetX = 0;
  int eyeOffsetY = 0;
  bool blinkFrame = false;
  bool faceSmile = false;
  uint8_t facePhase = 0;

  TouchRuntime touch;
} rt;

static const char* MENU_ITEMS[] = {
  "Alarm",
  "LED Control",
  "Heart Rate",
  "Monitoring",
  "Device Info",
  "WiFi Setup",
  "Reset"
};

constexpr uint8_t MENU_ITEM_COUNT = sizeof(MENU_ITEMS) / sizeof(MENU_ITEMS[0]);
constexpr const char* GEM_HOTSPOT_PASSWORD = "123456789";

// ---------------- Helpers ----------------
void copyText(char* dst, size_t dstSize, const char* src) {
  if (dstSize == 0) return;
  if (!src) src = "";
  strncpy(dst, src, dstSize - 1);
  dst[dstSize - 1] = '\0';
}

bool argTrue(const String& value) {
  String v = value;
  v.trim();
  v.toLowerCase();
  return v == "1" || v == "true" || v == "on" || v == "yes";
}

// ── Cloud / broker helpers ─────────────────────────────────────────────────────
// POST a lightweight keepalive ping to the broker's /api/ping endpoint.
// Called every 30 s when monitoring is enabled and Wi-Fi is up.
void sendGuardPing() {
  if (!settings.monitoringEnabled) return;
  if (WiFi.status() != WL_CONNECTED) return;
  if (strlen(settings.cloudWebhook) < 8) return;

  // Derive the broker base URL from the webhook URL.
  // Webhook is e.g. "https://host/webhook" → ping is "https://host/api/ping"
  String webhook = String(settings.cloudWebhook);
  int lastSlash = webhook.lastIndexOf('/');
  String base = (lastSlash > 8) ? webhook.substring(0, lastSlash) : webhook;
  String pingUrl = base + "/api/ping";

  HTTPClient http;
  http.begin(pingUrl);
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  String body = "source=device";
  body += "&device=";
  body += settings.deviceName;
  body += "&battery=";
  body += String(rt.batteryPercent);
  body += "&ldr=";
  body += String(rt.ldrRaw);

  int code = http.POST(body);
  if (code > 0) Serial.printf("[Ping] /api/ping → %d\n", code);
  http.end();
}
// ──────────────────────────────────────────────────────────────────────────────

void setDefaultSettings(GemSettings& s) {
  GemSettings defaults;
  s = defaults;
}

void saveSettings() {
  prefs.begin(GEM_PREF_NAMESPACE, false);
  prefs.putBytes("settings", &settings, sizeof(settings));
  prefs.end();
}

void scheduleRestart(uint32_t delayMs = 1200) {
  restartPending = true;
  restartAtMs = millis() + delayMs;
}

void scheduleNetworking() {
  networkingPending = true;
  networkingAtMs = millis() + 500;
}

void loadSettings() {
  setDefaultSettings(settings);

  prefs.begin(GEM_PREF_NAMESPACE, true);
  size_t got = prefs.getBytes("settings", &settings, sizeof(settings));
  prefs.end();

  Serial.printf("loadSettings: Read %d bytes from Preferences (expected %d)\n", got, sizeof(settings));
  if (got > 0) {
    Serial.printf("loadSettings: magic = 0x%08X (expected 0x%08X), version = %d (expected %d)\n", 
                  settings.magic, GEM_SETTINGS_MAGIC, settings.version, GEM_SETTINGS_VERSION);
  }

  if (got != sizeof(settings) ||
      settings.magic != GEM_SETTINGS_MAGIC ||
      settings.version != GEM_SETTINGS_VERSION) {
    Serial.println("loadSettings: Settings invalid or missing, resetting to defaults...");
    setDefaultSettings(settings);
    saveSettings();
  } else {
    Serial.println("loadSettings: Settings loaded successfully!");
  }
}

void applyLed(uint8_t pin, uint8_t duty) {
  ledcWrite(pin, duty);
}

void setAllLeds(uint8_t duty) {
  applyLed(PIN_LED1, duty);
  applyLed(PIN_LED2, duty);
  applyLed(PIN_LED3, duty);
  applyLed(PIN_LED4, duty);
}

void setLampOff() {
  settings.lampState = false;
  setAllLeds(0);
}

void setLampOn() {
  settings.lampState = true;
}

void beep(uint16_t freq, uint16_t durationMs) {
  tone(PIN_BUZZER, freq, durationMs);
  delay(durationMs + 5);
  noTone(PIN_BUZZER);
}

void softConfirm() {
  beep(1800, 40);
  delay(20);
  beep(2200, 45);
}

void celebrateTouch() {
  rt.petActive = true;
  rt.petUntil = millis() + 2500;
  setLampOn();
  settings.lampMode = LAMP_BREATHING;
  softConfirm();
}

void toggleLampMode() {
  if (settings.lampState) {
    setLampOff();
  } else {
    setLampOn();
  }
  saveSettings();
  softConfirm();
}

void triggerCloudEvent(const char* reason) {
  if (!settings.monitoringEnabled || WiFi.status() != WL_CONNECTED) return;
  if (settings.cloudWebhook[0] == '\0') return;

  uint32_t now = millis();
  if (now - rt.lastCloudEvent < CLOUD_EVENT_COOLDOWN_MS) return;
  rt.lastCloudEvent = now;

  HTTPClient http;
  http.begin(settings.cloudWebhook);
  http.addHeader("Content-Type", "application/json");

  String payload = "{";
  payload += "\"device\":\"" + String(settings.deviceName) + "\",";
  payload += "\"user\":\"" + String(settings.userName) + "\",";
  payload += "\"reason\":\"" + String(reason) + "\",";
  payload += "\"battery\":" + String(rt.batteryPercent) + ",";
  payload += "\"ldr\":" + String(rt.ldrRaw);
  payload += "}";

  http.POST(payload);
  http.end();
}

void enterDeepSleep() {
  setLampOff();
  noTone(PIN_BUZZER);
  digitalWrite(PIN_PULSE_POWER, LOW);
  u8g2.setPowerSave(1);
  esp_sleep_enable_ext0_wakeup((gpio_num_t)PIN_TOUCH, 1);
  delay(50);
  esp_deep_sleep_start();
}

bool validClock() {
  return time(nullptr) > 1700000000;
}

void formatLocalDateTime(char* dateBuf, size_t dateLen, char* timeBuf, size_t timeLen, bool withSeconds = false) {
  if (!validClock()) {
    copyText(dateBuf, dateLen, "1970-01-01");
    copyText(timeBuf, timeLen, withSeconds ? "00:00:00" : "00:00");
    return;
  }

  time_t utc = time(nullptr);
  time_t local = utc + (settings.timezoneOffsetMinutes * 60);
  struct tm tmv;
  gmtime_r(&local, &tmv);
  strftime(dateBuf, dateLen, "%Y-%m-%d", &tmv);
  if (withSeconds) {
    strftime(timeBuf, timeLen, "%H:%M:%S", &tmv);
  } else {
    strftime(timeBuf, timeLen, "%H:%M", &tmv);
  }
}

bool isNightTime() {
  if (!validClock()) return false;
  time_t utc = time(nullptr);
  time_t local = utc + (settings.timezoneOffsetMinutes * 60);
  struct tm tmv;
  gmtime_r(&local, &tmv);
  return tmv.tm_hour >= 22 || tmv.tm_hour < 6;
}

bool isEveningTime() {
  if (!validClock()) return false;
  time_t utc = time(nullptr);
  time_t local = utc + (settings.timezoneOffsetMinutes * 60);
  struct tm tmv;
  gmtime_r(&local, &tmv);
  return (tmv.tm_hour >= 18 && tmv.tm_hour < 22);
}

// Auto-lamp schedule:
//   7 PM (19:00) → lamp ON  (warm evening light)
//   5 AM (05:00) → lamp OFF (dawn, sleep mode ends)
void checkAutoLamp() {
  if (!validClock() || rt.batteryCritical) return;

  time_t utc   = time(nullptr);
  time_t local = utc + (settings.timezoneOffsetMinutes * 60);
  struct tm tmv;
  gmtime_r(&local, &tmv);
  uint32_t minuteKey = (uint32_t)(local / 60);

  static uint32_t lastLampOnMinute  = 0;
  static uint32_t lastLampOffMinute = 0;

  // --- 7 PM auto-ON ---
  if (tmv.tm_hour == 19 && tmv.tm_min == 0) {
    if (lastLampOnMinute != minuteKey) {
      lastLampOnMinute = minuteKey;
      if (!settings.lampState) {
        settings.lampState = true;
        if (settings.lampMode == 0) settings.lampMode = LAMP_STATIC;
        saveSettings();
      }
    }
  }

  // --- 5 AM auto-OFF ---
  if (tmv.tm_hour == 5 && tmv.tm_min == 0) {
    if (lastLampOffMinute != minuteKey) {
      lastLampOffMinute = minuteKey;
      if (settings.lampState) {
        settings.lampState = false;
        saveSettings();
      }
    }
  }
}

uint16_t readAnalogAverage(uint8_t pin, uint8_t samples) {
  uint32_t total = 0;
  for (uint8_t i = 0; i < samples; ++i) {
    total += analogReadMilliVolts(pin);
    delay(2);
  }
  return (uint16_t)(total / samples);
}

int readBatteryPercent() {
  float mv = readAnalogAverage(PIN_BATTERY_ADC, 8);
  float volts = (mv / 1000.0f) * BATTERY_DIVIDER_RATIO;
  rt.batteryVoltage = volts;

  if (volts < 2.0f) {
    return 100; // No battery connected, treat as USB-powered 100% to prevent deep sleep
  }

  float percent = 0.0f;
  if (volts >= 4.20f) {
    percent = 100.0f;
  } else if (volts >= 4.00f) {
    percent = 80.0f + ((volts - 4.00f) / 0.20f) * 20.0f;
  } else if (volts >= 3.85f) {
    percent = 60.0f + ((volts - 3.85f) / 0.15f) * 20.0f;
  } else if (volts >= 3.75f) {
    percent = 40.0f + ((volts - 3.75f) / 0.10f) * 20.0f;
  } else if (volts >= 3.65f) {
    percent = 25.0f + ((volts - 3.65f) / 0.10f) * 15.0f;
  } else if (volts >= 3.50f) {
    percent = 15.0f + ((volts - 3.50f) / 0.15f) * 10.0f;
  } else if (volts >= 3.35f) {
    percent = 5.0f + ((volts - 3.35f) / 0.15f) * 10.0f;
  } else if (volts >= BATTERY_MIN_VOLTAGE) {
    percent = ((volts - BATTERY_MIN_VOLTAGE) / (3.35f - BATTERY_MIN_VOLTAGE)) * 5.0f;
  }

  if (percent < 0.0f) percent = 0.0f;
  if (percent > 100.0f) percent = 100.0f;
  return (int)(percent + 0.5f);
}

uint16_t readLdrRaw() {
  return readAnalogAverage(PIN_LDR_ADC, 4);
}

void refreshSensors(bool force = false) {
  uint32_t now = millis();
  if (force || now - rt.lastBatteryRead >= BATTERY_SAMPLE_MS) {
    rt.lastBatteryRead = now;
    rt.batteryPercent = readBatteryPercent();
    rt.batteryCritical = rt.batteryPercent <= 5;
    rt.batterySaver = rt.batteryPercent < 30;
  }

  uint32_t ldrInterval = settings.monitoringEnabled ? 1500UL : LDR_SAMPLE_MS;
  if (force || now - rt.lastLdrRead >= ldrInterval) {
    uint16_t oldLdr = rt.ldrRaw;
    bool wasDark = rt.ambientDark;
    rt.lastLdrRead = now;
    rt.ldrRaw = readLdrRaw();
    rt.ambientDark = rt.ldrRaw < 1600;

    if (!force && !wasDark && rt.ambientDark) {
      if (!settings.lampState) {
        settings.lampState = true;
        settings.lampMode = LAMP_STATIC;
        saveSettings();
      }
    }

    // Detect sudden shift (shadow or flash)
    if (!force && oldLdr > 0 && settings.monitoringEnabled) {
      int diff = (int)rt.ldrRaw - (int)oldLdr;
      if (diff < -800) {
        triggerSecurityAlarm("shadow-detected");
      } else if (diff > 800) {
        triggerSecurityAlarm("flash-detected");
      }
    }
  }
}

void applyPowerPolicy() {
  if (rt.heartModeActive) {
    // Let updateHeartMode manage the LEDs during active pulse scan
    return;
  }

  uint8_t contrast = OLED_CONTRAST_DAY;
  if (isNightTime() || (rt.ambientDark && !validClock())) {
    contrast = OLED_CONTRAST_NIGHT;
  } else if (isEveningTime() || rt.ambientDark) {
    contrast = OLED_CONTRAST_EVENING;
  }

  if (rt.batterySaver) contrast = (uint8_t)((contrast * 3) / 4);
  if (rt.batteryCritical) contrast = OLED_CONTRAST_NIGHT;
  u8g2.setContrast(contrast);

  uint8_t brightness = settings.lampBrightness;
  if (rt.batterySaver) brightness = (uint8_t)max<int>(LED_BRIGHTNESS_MIN, (brightness * 70) / 100);
  if (rt.batteryCritical) brightness = 0;

  if (!settings.lampState || rt.batteryCritical) {
    setAllLeds(0);
    return;
  }

  uint8_t duty = brightness;
  if (settings.lampMode == LAMP_STATIC) {
    setAllLeds(duty);
  } else if (settings.lampMode == LAMP_BREATHING) {
    uint8_t p = (millis() / 14) % 255;
    duty = (uint8_t)((sin((p / 255.0f) * 6.28318f) + 1.0f) * 0.5f * brightness);
    setAllLeds(duty);
  } else if (settings.lampMode == LAMP_SLOW_BLINK) {
    uint8_t on = ((millis() / 700) % 2) ? duty : 0;
    setAllLeds(on);
  } else if (settings.lampMode == LAMP_PULSE) {
    uint8_t wave = (uint8_t)(abs((int)(millis() / 8 % 510) - 255));
    duty = (uint8_t)((255 - wave) * brightness / 255);
    setAllLeds(duty);
  } else if (settings.lampMode == LAMP_FLASH) {
    if (rt.lampNotificationFlash && millis() < rt.lampNotificationUntil) {
      setAllLeds(brightness);
    } else {
      rt.lampNotificationFlash = false;
      setAllLeds(0);
    }
  }
}

void saveLastKnownTime() {
  time_t now = time(nullptr);
  if (now > 1700000000) { // Only save valid time
    prefs.begin(GEM_PREF_NAMESPACE, false);
    prefs.putUInt("lastTime", (uint32_t)now);
    prefs.end();
  }
}

void setTimeFromEpoch(time_t epochUtc) {
  struct timeval tv;
  tv.tv_sec = epochUtc;
  tv.tv_usec = 0;
  settimeofday(&tv, nullptr);
}

void setTimeFromArgs() {
  if (!server.hasArg("epoch")) return;
  time_t epoch = (time_t)server.arg("epoch").toInt();
  if (epoch > 1700000000) {
    setTimeFromEpoch(epoch);
    saveLastKnownTime();
  }
  if (server.hasArg("tz_offset_min")) {
    settings.timezoneOffsetMinutes = server.arg("tz_offset_min").toInt();
  }
  if (server.hasArg("tz_label")) {
    copyText(settings.timezoneLabel, sizeof(settings.timezoneLabel), server.arg("tz_label").c_str());
  }
}

void triggerAlarm(uint8_t idx) {
  if (idx >= settings.alarmCount) return;

  rt.alarmActive = true;
  rt.alarmUntil = millis() + 60000UL; // Rings for 60 seconds (full minute)
  rt.alarmIndex = idx;
  rt.alarmToneStep = 0;
  rt.alarmToneStepAt = 0;
  rt.faceMode = FACE_ALARM;
  rt.timeOverlayActive = false;
  rt.menuOpen = false;
  rt.petActive = false;
  settings.lampState = true;
  settings.lampMode = LAMP_BREATHING;
  rt.lampNotificationUntil = millis() + 60000UL;
  triggerCloudEvent("alarm");
}

void triggerSecurityAlarm(const char* eventName) {
  triggerCloudEvent(eventName);

  rt.alarmActive = true;
  rt.alarmUntil = millis() + 300000UL; // Rings for 300 seconds (5 mins)
  rt.alarmIndex = 254; // special index for security alarm
  rt.alarmToneStep = 0;
  rt.alarmToneStepAt = 0;
  rt.faceMode = FACE_ALARM;
  rt.timeOverlayActive = false;
  rt.menuOpen = false;
  rt.petActive = false;
  settings.lampState = true;
  settings.lampMode = LAMP_FLASH;
  rt.lampNotificationFlash = true;
  rt.lampNotificationUntil = millis() + 300000UL;
}

void checkAlarms() {
  if (!validClock() || settings.alarmCount == 0) return;
  if (millis() - rt.lastAlarmCheck < ALARM_CHECK_MS) return;
  rt.lastAlarmCheck = millis();

  time_t utc = time(nullptr);
  time_t local = utc + (settings.timezoneOffsetMinutes * 60);
  struct tm tmv;
  gmtime_r(&local, &tmv);
  uint32_t minuteKey = (uint32_t)(local / 60);

  for (uint8_t i = 0; i < settings.alarmCount && i < 6; ++i) {
    if (!settings.alarms[i].enabled) continue;
    if (tmv.tm_hour == settings.alarms[i].hour && tmv.tm_min == settings.alarms[i].minute) {
      static uint32_t lastMinuteKey[6] = {0, 0, 0, 0, 0, 0};
      if (lastMinuteKey[i] != minuteKey) {
        lastMinuteKey[i] = minuteKey;
        triggerAlarm(i);
      }
    }
  }
}

void updateAlarmRuntime() {
  if (!rt.alarmActive) return;
  uint32_t now = millis();
  if (now >= rt.alarmUntil) {
    rt.alarmActive = false;
    noTone(PIN_BUZZER);
    if (rt.alarmIndex != 254) {
      rt.alarmMissed = true;
      rt.missedAlarmIndex = rt.alarmIndex;
    } else {
      rt.alarmIndex = 255;
      rt.faceMode = FACE_DAY;
      setLampOff();
    }
    return;
  }

  if (now >= rt.alarmToneStepAt) {
    uint8_t hr = 7;
    if (rt.alarmIndex < 6) {
      hr = settings.alarms[rt.alarmIndex].hour;
    }

    uint16_t note = 0;
    if (rt.alarmIndex == 254) {
      // Security siren: fast alternating high/low pitch
      note = (rt.alarmToneStep % 2 == 0) ? 2000 : 1000;
      rt.alarmToneStepAt = now + 150;
    } else if (hr >= 5 && hr < 12) {
      // Morning (Wake Up): Bird chirp (fast high pitch trills)
      static const uint16_t birdNotes[] = { 2500, 3200, 2500, 0, 0, 2800, 3500, 0, 0, 0 };
      note = birdNotes[rt.alarmToneStep % 10];
    } else if (hr >= 12 && hr < 17) {
      // Afternoon Alert: Bouncy, energetic chime
      static const uint16_t afternoonNotes[] = { 880, 0, 880, 0, 988, 0, 988, 0, 1175, 0, 1318, 0, 1175, 988, 880, 0 };
      note = afternoonNotes[rt.alarmToneStep % 16];
    } else if (hr >= 17 && hr < 21) {
      // Evening Alert: Warm, comforting harmonic chime
      static const uint16_t eveningNotes[] = { 440, 554, 659, 880, 659, 554, 440, 0, 494, 622, 740, 988, 740, 622, 494, 0 };
      note = eveningNotes[rt.alarmToneStep % 16];
    } else {
      // Night Alert: Soft, slow, low-pitch calming lullaby
      static const uint16_t nightNotes[] = { 349, 0, 440, 0, 523, 0, 440, 0, 392, 0, 494, 0, 587, 0, 494, 0 };
      note = nightNotes[rt.alarmToneStep % 16];
    }

    rt.alarmToneStep++;
    if (rt.alarmIndex != 254 && hr >= 5 && hr < 12) {
      rt.alarmToneStepAt = now + 80; // Fast for birds
    } else {
      rt.alarmToneStepAt = now + 220;
    }
    
    if (note == 0) {
      noTone(PIN_BUZZER);
    } else {
      if (rt.alarmIndex != 254 && hr >= 5 && hr < 12) {
        tone(PIN_BUZZER, note, 60);
      } else {
        tone(PIN_BUZZER, note, 160);
      }
    }
  }
}

void startHeartMode() {
  rt.heartModeActive = true;
  rt.heartModeUntil = millis() + HEART_MODE_TIMEOUT_MS;
  rt.pulseBaseline = 0.0f;
  rt.pulseAbove = false;
  rt.lastBeatMs = 0;
  rt.bpm = 0;
  rt.lastPulseSampleAt = 0;
  rt.fingerPresent = false;
  digitalWrite(PIN_PULSE_POWER, HIGH);
  rt.faceMode = FACE_HEART;
}

void stopHeartMode() {
  rt.heartModeActive = false;
  rt.fingerPresent = false;
  digitalWrite(PIN_PULSE_POWER, LOW);
  setAllLeds(0); // Reset all LEDs when heartbeat scanning stops
  if (rt.faceMode == FACE_HEART) {
    rt.faceMode = FACE_DAY;
  }
}

void updateHeartMode() {
  if (!rt.heartModeActive) return;

  uint32_t now = millis();
  if (now >= rt.heartModeUntil) {
    stopHeartMode();
    return;
  }

  if (now - rt.lastPulseSampleAt < HEART_SAMPLE_MS) return;
  rt.lastPulseSampleAt = now;

  int raw = analogRead(PIN_PULSE_ADC);

  // Finger presence: sensor idle (no finger) reads near 0 or near 4095
  bool fingerNow = (raw > 200 && raw < 3900);
  bool oldFinger = rt.fingerPresent;
  rt.fingerPresent = fingerNow;

  if (!oldFinger && fingerNow) {
    // Finger just placed — reset all state for fresh session
    rt.fingerDetectedAt  = now;
    rt.pulseCalibrated   = false;
    rt.pulseBaseline     = (float)raw;
    rt.pulseAbove        = false;
    rt.lastBeatMs        = 0;
    rt.bpm               = 0;
  }

  if (!fingerNow) {
    rt.bpm               = 0;
    rt.pulseAbove        = false;
    rt.pulseBaseline     = 0.0f;
    rt.fingerDetectedAt  = 0;
    rt.pulseCalibrated   = false;
    setAllLeds(0);
    return;
  }

  uint32_t elapsed = now - rt.fingerDetectedAt;

  // ── Phase 1: Fast calibration (first 2 s) ──────────────────────────────
  if (elapsed < 2000) {
    // Aggressively track baseline during calibration so it settles quickly
    if (rt.pulseBaseline <= 1.0f) rt.pulseBaseline = (float)raw;
    rt.pulseBaseline = rt.pulseBaseline * 0.90f + (float)raw * 0.10f;
    rt.pulseAbove    = false;
    return; // Don't detect beats yet
  }

  // ── Phase 2: Measurement ───────────────────────────────────────────────
  if (!rt.pulseCalibrated) {
    rt.pulseCalibrated = true;
    rt.lastBeatMs      = now; // Anchor so first interval is valid
  }

  // Slow-track baseline to follow DC drift without following the pulse itself
  rt.pulseBaseline = rt.pulseBaseline * 0.98f + (float)raw * 0.02f;
  float threshold  = rt.pulseBaseline + 25.0f;

  // Stale signal → clear BPM (no beat for 3 seconds)
  if (rt.lastBeatMs > 0 && (now - rt.lastBeatMs) > 3000) {
    rt.bpm = 0;
  }

  // Rising-edge beat detection with 300 ms refractory period
  if (!rt.pulseAbove && (float)raw > threshold && (now - rt.lastBeatMs) > 300) {
    rt.pulseAbove = true;

    if (rt.lastBeatMs > 0) {
      uint32_t interval = now - rt.lastBeatMs;
      uint32_t bpmCalc  = 60000UL / interval;
      // Only accept physiologically plausible BPM (40–180)
      if (bpmCalc >= 40 && bpmCalc <= 180) {
        rt.bpm = (uint16_t)bpmCalc;
        rt.bpmValidCount++;
        if (rt.bpmValidCount == 4) {
          triggerCloudEvent("heart-scan"); // Updates the app!
          rt.heartModeUntil = now + 3000; // Hold the value on screen for 3s then auto exit
        }
      } else {
        rt.bpmValidCount = 0;
      }
    }
    rt.lastBeatMs = now;

    // Visual + audio beat feedback
    setAllLeds(255);
    tone(PIN_BUZZER, 1200, 35);
  }

  // Falling edge — reset trigger and fade LEDs
  if (rt.pulseAbove && (float)raw < rt.pulseBaseline) {
    rt.pulseAbove = false;
    setAllLeds(0);
  }
}

void openMenu() {
  rt.menuOpen = true;
  rt.menuIndex = 0;
  rt.menuUntil = millis() + 15000;
  rt.faceMode = FACE_MENU;
}

void closeMenu() {
  rt.menuOpen = false;
  rt.faceMode = FACE_DAY;
}

void showInfoPage() {
  rt.faceMode = FACE_INFO;
  rt.timeOverlayUntil = millis() + 6000;
}

void activateMenuItem() {
  closeMenu(); // Close menu first so the display shows the activated feature
  switch (rt.menuIndex) {
    case 0:
      if (settings.alarmCount > 0) {
        settings.alarms[0].enabled = !settings.alarms[0].enabled;
        saveSettings();
      }
      rt.faceMode = FACE_ALARM;
      rt.timeOverlayUntil = millis() + 3000;
      break;
    case 1:
      settings.lampState = !settings.lampState;
      if (settings.lampState && settings.lampMode == 0) settings.lampMode = LAMP_STATIC;
      saveSettings();
      break;
    case 2:
      if (rt.heartModeActive) {
        stopHeartMode();
      } else {
        startHeartMode();
      }
      break;
    case 3:
      if (!settings.monitoringEnabled && WiFi.status() != WL_CONNECTED) {
        tone(PIN_BUZZER, 200, 150);
        delay(200);
        tone(PIN_BUZZER, 200, 150);
        showInfoPage(); // Show network status screen
        break;
      }
      settings.monitoringEnabled = !settings.monitoringEnabled;
      if (settings.monitoringEnabled) {
        settings.wifiEnabled = true;
        setupNetworking(); // Auto connect WiFi on Guard Mode activation
        rt.lampNotificationFlash = true;
        rt.lampNotificationUntil = millis() + 2500;
      }
      saveSettings();
      break;
    case 4:
      showInfoPage();
      break;
    case 5:
      openSetupPortal(true);
      rt.faceMode = FACE_WIFI_SETUP;
      softConfirm();
      break;
    case 6:
      memset(&settings, 0, sizeof(settings));
      setDefaultSettings(settings);
      saveSettings();
      rt.welcomeActive = true;
      rt.welcomeStep = 0;
      rt.welcomeUntil = millis() + BOOT_WELCOME_MS;
      break;
  }
}

void updateMenuTimeout() {
  if (rt.menuOpen && millis() > rt.menuUntil) {
    closeMenu();
  }
}

void drawCentered(int y, const char* text, const uint8_t* font) {
  u8g2.setFont(font);
  int16_t w = u8g2.getStrWidth(text);
  u8g2.drawStr((OLED_WIDTH - w) / 2, y, text);
}

void drawBatteryBar() {
  // Battery display disabled
}

void drawFaceEyes() {
  int base_x1 = 16;
  int base_x2 = 80;
  int shift = (rt.picaioXp - 16) / 4; // Scale pupil movement to +/- 4 pixels
  int x1 = base_x1 + rt.picaioXd + shift;
  int x2 = base_x2 + rt.picaioXd + shift;

  // Clamp coordinates to prevent side wrap-around glitches
  if (x1 < 0) x1 = 0;
  if (x1 > 48) x1 = 48;
  if (x2 < 48) x2 = 48;
  if (x2 > 96) x2 = 96;

  // Draw the eyes centered (y = 12)
  if (rt.isBlinking || rt.picaioMood == 2) {
    u8g2.drawBitmap(x1, 12, 4, 32, eye0);
    u8g2.drawBitmap(x2, 12, 4, 32, eye0);
  } else {
    int m = rt.picaioMood;
    if (rt.picaioXp < 6) {
      u8g2.drawBitmap(x1, 12, 4, 32, peyes[m][1][0]);
      u8g2.drawBitmap(x2, 12, 4, 32, peyes[m][1][1]);
    } else if (rt.picaioXp < 26) {
      u8g2.drawBitmap(x1, 12, 4, 32, peyes[m][0][0]);
      u8g2.drawBitmap(x2, 12, 4, 32, peyes[m][0][1]);
    } else {
      u8g2.drawBitmap(x1, 12, 4, 32, peyes[m][2][0]);
      u8g2.drawBitmap(x2, 12, 4, 32, peyes[m][2][1]);
    }
  }
}

void drawMouth(int cx, int cy, bool smile, bool tiny) {
  if (smile) {
    u8g2.drawArc(cx, cy, tiny ? 5 : 7, 200, 340);
  } else {
    u8g2.drawArc(cx, cy + 1, tiny ? 4 : 6, 20, 160);
  }
}

void drawHearts() {
  u8g2.drawStr(8, 52, "<3");
  u8g2.drawStr(108, 52, "<3");
}

void drawZzz() {
  u8g2.setFont(u8g2_font_6x10_tr);
  u8g2.drawStr(92, 20, "Z");
  u8g2.drawStr(102, 14, "z");
  u8g2.drawStr(110, 10, "z");
}

void drawTimeOverlay() {
  char dateBuf[16];
  char timeBuf[16];
  formatLocalDateTime(dateBuf, sizeof(dateBuf), timeBuf, sizeof(timeBuf), false);

  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawBatteryBar();
  
  // Show premium "LIVE" status badge if app is actively connected (polling within last 10 seconds)
  if (rt.lastAppRequestAt > 0 && millis() - rt.lastAppRequestAt < 10000) {
    u8g2.setFont(u8g2_font_4x6_tr);
    u8g2.drawRBox(96, 6, 22, 9, 2);
    u8g2.setDrawColor(0);
    u8g2.drawStr(99, 13, "LIVE");
    u8g2.setDrawColor(1);
  }

  drawCentered(24, timeBuf, u8g2_font_7x14_tf);
  drawCentered(40, dateBuf, u8g2_font_6x10_tf);
  u8g2.setFont(u8g2_font_5x7_tr);
  u8g2.drawStr(12, 58, settings.userName);
  u8g2.sendBuffer();
}

void drawWelcomeScreen() {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  if (rt.welcomeStep == 0) {
    drawCentered(20, "Hello! I am GEM", u8g2_font_6x10_tr);
    drawCentered(36, "your smart companion", u8g2_font_5x7_tr);
    drawCentered(48, "Let's bring me to life!", u8g2_font_5x7_tr);
  } else if (rt.welcomeStep == 1) {
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(8, 14, "Connect to Wi-Fi:");
    u8g2.drawStr(8, 24, "SSID: GEM Buddy");
    u8g2.drawStr(8, 34, "Pass: 123456789");
    u8g2.drawStr(8, 44, "Go to: 192.168.4.1");
    u8g2.drawStr(8, 54, "Use the app to setup");
  } else if (rt.welcomeStep == 2) {
    char welcomeLine[40];
    snprintf(welcomeLine, sizeof(welcomeLine), "Hello, %s!", settings.userName);
    drawCentered(20, welcomeLine, u8g2_font_6x10_tr);
    
    char nameLine[40];
    snprintf(nameLine, sizeof(nameLine), "I am %s", settings.deviceName);
    drawCentered(36, nameLine, u8g2_font_5x7_tr);
    
    drawCentered(48, "your smart companion", u8g2_font_5x7_tr);
  }
  u8g2.sendBuffer();
}

void drawConfiguringScreen() {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawCentered(18, "Configuring GEM", u8g2_font_6x10_tr);
  drawCentered(32, "Saving settings to flash", u8g2_font_5x7_tr);
  
  // Draw an animated loading bar based on millis()
  int progress = (millis() / 20) % 100;
  int w = map(progress, 0, 99, 0, 80);
  u8g2.drawFrame(24, 44, 80, 8);
  u8g2.drawBox(26, 46, w, 4);
  
  u8g2.sendBuffer();
}

void drawMenuScreen() {
  u8g2.clearBuffer();

  // Center header
  u8g2.setFont(u8g2_font_6x10_tf);
  int16_t headerW = u8g2.getStrWidth("GEM Menu");
  u8g2.drawStr((128 - headerW) / 2, 11, "GEM Menu");
  u8g2.drawLine(2, 14, 126, 14);

  // Draw rounded card frame in the center
  u8g2.drawRFrame(16, 24, 96, 24, 4);

  // Center the active menu item text inside the card
  u8g2.setFont(u8g2_font_7x14_tf); // Premium larger font
  const char* activeItemText = MENU_ITEMS[rt.menuIndex];
  if (rt.menuIndex == 2 && rt.heartModeActive) {
    activeItemText = "Stop Heart Scan";
  }
  int16_t itemW = u8g2.getStrWidth(activeItemText);
  u8g2.drawStr((128 - itemW) / 2, 40, activeItemText);

  // Draw left and right pointing arrows next to the card
  // Left arrow: <
  u8g2.drawTriangle(6, 36, 10, 32, 10, 40);
  // Right arrow: >
  u8g2.drawTriangle(122, 36, 118, 32, 118, 40);

  u8g2.sendBuffer();
}

void drawInfoScreen() {
  char timeBuf[16];
  char dateBuf[16];
  formatLocalDateTime(dateBuf, sizeof(dateBuf), timeBuf, sizeof(timeBuf), true);

  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawBatteryBar();
  u8g2.setFont(u8g2_font_6x10_tr);
  u8g2.drawStr(10, 12, settings.deviceName);
  u8g2.setFont(u8g2_font_5x7_tr);
  u8g2.drawStr(10, 22, "User:");
  u8g2.drawStr(42, 22, settings.userName);
  u8g2.drawStr(10, 30, "TZ:");
  u8g2.drawStr(42, 30, settings.timezoneLabel);
  u8g2.drawStr(10, 38, "Time:");
  u8g2.drawStr(42, 38, timeBuf);
  u8g2.drawStr(10, 46, "Date:");
  u8g2.drawStr(42, 46, dateBuf);
  u8g2.drawStr(10, 54, settings.setupComplete ? "Saved in flash" : "First boot setup");
  u8g2.sendBuffer();
}

void drawWiFiSetupScreen() {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawBatteryBar();
  u8g2.setFont(u8g2_font_6x10_tr);
  u8g2.drawStr(10, 12, "WiFi Setup Mode");
  u8g2.setFont(u8g2_font_5x7_tr);
  u8g2.drawStr(10, 24, "SSID: GEM Buddy");
  u8g2.drawStr(10, 34, "Pass: 123456789");
  u8g2.drawStr(10, 44, "IP: 192.168.4.1");
  u8g2.drawStr(10, 54, "Tap touch to exit");
  u8g2.sendBuffer();
}

void closeWiFiSetup() {
  rt.faceMode = FACE_DAY;
  setupNetworking();
  softConfirm();
}

void drawFaceScreen() {
  u8g2.clearBuffer();

  // Dedicated Alarm / Reminder Screen - Centered Layout!
  if (rt.faceMode == FACE_ALARM) {
    u8g2.drawRFrame(4, 4, 120, 56, 8);
    u8g2.setFont(u8g2_font_6x10_tf);
    if (rt.alarmActive) {
      drawCentered(16, "🚨 REMINDER 🚨", u8g2_font_6x10_tf);
    } else if (rt.alarmMissed) {
      drawCentered(16, "🚨 MISSED 🚨", u8g2_font_6x10_tf);
    }
    u8g2.drawHLine(12, 20, 104);
    
    char alarmName[24] = "Alarm";
    uint8_t dispIndex = rt.alarmActive ? rt.alarmIndex : rt.missedAlarmIndex;
    if (dispIndex < 3) {
      strcpy(alarmName, settings.alarms[dispIndex].name);
    }
    drawCentered(36, alarmName, u8g2_font_7x14_tf);
    
    char tBuf[16];
    char dBuf[16];
    formatLocalDateTime(dBuf, sizeof(dBuf), tBuf, sizeof(tBuf), false);
    char timeLabel[32];
    snprintf(timeLabel, sizeof(timeLabel), "Time: %s", tBuf);
    drawCentered(52, timeLabel, u8g2_font_5x7_tr);
    
    u8g2.sendBuffer();
    return;
  }

  // Dedicated Heart Rate Scan Dashboard - NO Eyes!
  if (rt.faceMode == FACE_HEART) {
    u8g2.setFont(u8g2_font_6x10_tf);
    u8g2.drawStr(12, 14, "HEART RATE SCAN");
    u8g2.drawHLine(6, 17, 116);

    // Beating heart on the left side
    int hcx = 36;
    int hcy = 38;
    bool isBeating = rt.pulseAbove || (rt.lastBeatMs > 0 && (millis() - rt.lastBeatMs < 200));
    if (isBeating) {
      u8g2.drawDisc(hcx - 6, hcy - 4, 6);
      u8g2.drawDisc(hcx + 6, hcy - 4, 6);
      u8g2.drawTriangle(hcx - 12, hcy - 2, hcx + 12, hcy - 2, hcx, hcy + 12);
    } else {
      u8g2.drawDisc(hcx - 5, hcy - 3, 5);
      u8g2.drawDisc(hcx + 5, hcy - 3, 5);
      u8g2.drawTriangle(hcx - 10, hcy - 2, hcx + 10, hcy - 2, hcx, hcy + 10);
    }

    // BPM text on the right side
    u8g2.setFont(u8g2_font_7x14_tf);
    char bpmStr[16];
    if (rt.bpm > 0 && (millis() - rt.lastBeatMs < 4000)) {
      snprintf(bpmStr, sizeof(bpmStr), "%d", rt.bpm);
    } else {
      strcpy(bpmStr, "--");
    }
    u8g2.drawStr(80, 36, bpmStr);
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(80, 48, "BPM");
    
    if (!rt.fingerPresent) {
      u8g2.setFont(u8g2_font_4x6_tr);
      u8g2.drawStr(74, 58, "Place Finger...");
    } else if (!rt.pulseCalibrated) {
      u8g2.setFont(u8g2_font_4x6_tr);
      u8g2.drawStr(74, 58, "Calibrating...");
    } else {
      u8g2.setFont(u8g2_font_4x6_tr);
      u8g2.drawStr(74, 58, "Scanning...");
    }
    
    u8g2.sendBuffer();
    return;
  }

  // Small clock on top-left
  char timeStr[16];
  char dateStr[16];
  formatLocalDateTime(dateStr, sizeof(dateStr), timeStr, sizeof(timeStr), false);
  u8g2.setFont(u8g2_font_4x6_tr);
  u8g2.drawStr(4, 8, timeStr);

  // Draw WiFi symbol if connected, or slashed symbol if enabled but disconnected (at x = 114, y = 8)
  if (WiFi.status() == WL_CONNECTED) {
    u8g2.drawDisc(114, 8, 1);
    u8g2.drawCircle(114, 8, 3, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
    u8g2.drawCircle(114, 8, 5, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
  } else if (settings.wifiEnabled) {
    u8g2.drawDisc(114, 8, 1);
    u8g2.drawCircle(114, 8, 3, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
    u8g2.drawCircle(114, 8, 5, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
    u8g2.drawLine(109, 2, 118, 9);
  }

  // Draw Lock symbol next to WiFi (at x = 120, y = 5) if security active
  if (settings.monitoringEnabled) {
    u8g2.drawBox(120, 5, 5, 4);
    u8g2.drawCircle(122, 5, 2, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
  }

  // Draw Picaio eyes
  drawFaceEyes();

  // Greeting speech bubble at the bottom - shown when pet active or periodic greeting active
  if (rt.petActive || rt.greetingBubbleActive) {
    u8g2.drawRFrame(2, 46, 124, 18, 3);
    u8g2.setFont(u8g2_font_5x7_tr);
    // Draw speech bubble tip pointing up to the left eye
    u8g2.drawTriangle(30, 46, 34, 42, 38, 46);
    u8g2.setDrawColor(0);
    u8g2.drawLine(31, 46, 37, 46);
    u8g2.setDrawColor(1);
    
    char msg[32] = "";
    if (settings.monitoringEnabled) {
      strcpy(msg, "PLEASE DON'T TOUCH ME!");
    } else if (rt.petActive) {
      snprintf(msg, sizeof(msg), "Hello %s!", settings.userName);
    } else {
      switch (rt.greetingIndex) {
        case 0:
          snprintf(msg, sizeof(msg), "Hello %s!", settings.userName);
          break;
        case 1:
          strcpy(msg, "How are you?");
          break;
        case 2:
          strcpy(msg, "What's going on?");
          break;
        case 3: {
          char tBuf[16];
          char dBuf[16];
          formatLocalDateTime(dBuf, sizeof(dBuf), tBuf, sizeof(tBuf), false);
          snprintf(msg, sizeof(msg), "Time: %s", tBuf);
          break;
        }
        case 4:
        default: {
          int count = 0;
          char nextAlarmTime[16] = "";
          for (uint8_t i = 0; i < settings.alarmCount && i < 6; ++i) {
            if (settings.alarms[i].enabled) {
              count++;
              snprintf(nextAlarmTime, sizeof(nextAlarmTime), "%02d:%02d", settings.alarms[i].hour, settings.alarms[i].minute);
            }
          }
          if (count > 0) {
            snprintf(msg, sizeof(msg), "Alarm at %s", nextAlarmTime);
          } else {
            if (validClock()) {
              time_t utc = time(nullptr);
              time_t local = utc + (settings.timezoneOffsetMinutes * 60);
              struct tm tmv;
              gmtime_r(&local, &tmv);
              int hr = tmv.tm_hour;
              if (hr >= 5 && hr < 12) {
                strcpy(msg, "Good morning!");
              } else if (hr >= 12 && hr < 17) {
                strcpy(msg, "Good afternoon!");
              } else if (hr >= 17 && hr < 22) {
                strcpy(msg, "Good evening!");
              } else {
                strcpy(msg, "Good night!");
              }
            } else {
              strcpy(msg, "Good day!");
            }
          }
          break;
        }
      }
    }
    u8g2.drawStr(8, 57, msg);
  } 
  else if (rt.faceMode == FACE_NIGHT) {
    drawZzz();
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(12, 57, "Sleeping...");
  }

  u8g2.sendBuffer();
}

void renderScreen() {
  if (rt.faceMode == FACE_CONFIGURING) {
    drawConfiguringScreen();
    return;
  }

  if (rt.menuOpen) {
    drawMenuScreen();
    return;
  }

  if (rt.welcomeActive) {
    drawWelcomeScreen();
    return;
  }

  if (rt.timeOverlayActive && millis() < rt.timeOverlayUntil) {
    drawTimeOverlay();
    return;
  }

  if (rt.faceMode == FACE_INFO) {
    drawInfoScreen();
    return;
  }

  if (rt.faceMode == FACE_WIFI_SETUP) {
    drawWiFiSetupScreen();
    return;
  }

  drawFaceScreen();
}

void handleBlinks() {
  uint32_t now = millis();
  if (rt.isBlinking) {
    if (now >= rt.blinkEndMs) {
      rt.isBlinking = false;
      rt.nextBlinkMs = now + random(2500, 7000);
    }
  } else {
    if (now >= rt.nextBlinkMs && rt.picaioMood != 2) {
      rt.isBlinking = true;
      rt.blinkEndMs = now + random(100, 200);
    }
  }
}

void updateFaceAnimation() {
  uint32_t now = millis();
  if (now - rt.lastFaceFrame < OLED_REFRESH_MS) return;
  rt.lastFaceFrame = now;

  if (rt.welcomeActive || rt.faceMode == FACE_CONFIGURING) {
    return;
  }

  // Update Picaio mood mapping
  if (settings.monitoringEnabled) {
    rt.picaioMood = 3; // Angry / Alert
    rt.faceMode = FACE_DAY; // Ensure eyes are visible
  } else if (isNightTime() && rt.ambientDark) {
    rt.picaioMood = 2; // Sleeping / Closed
    rt.faceMode = FACE_NIGHT;
  } else if (isNightTime() && !rt.ambientDark) {
    rt.picaioMood = 4; // Sad / Tired
    rt.faceMode = FACE_EVENING;
  } else {
    switch (rt.faceMode) {
      case FACE_PET:
        rt.picaioMood = 1; // Happy
        break;
      case FACE_ALARM:
        rt.picaioMood = 3; // Angry / Alert
        break;
      case FACE_HEART:
        rt.picaioMood = 1; // Happy
        break;
      case FACE_WIFI_SETUP:
      case FACE_MENU:
        rt.picaioMood = 5; // Suspicious / Wide
        break;
      case FACE_EVENING:
        rt.picaioMood = 4; // Sad / Tired
        break;
      case FACE_DAY:
      default:
        rt.picaioMood = 0; // Neutral
        break;
    }
  }

  // Jitter pupil drift slightly to make it organic
  int n = random(0, 10);
  if (n < 4) rt.picaioXd--;
  if (n > 6) rt.picaioXd++;
  if (rt.picaioXd < -4) rt.picaioXd = -3;
  if (rt.picaioXd > 4) rt.picaioXd = 3;

  // Auto-cycle gaze direction randomly
  static uint32_t lastGazeCycleMs = 0;
  static uint32_t nextGazeIntervalMs = 4000;
  if (now - lastGazeCycleMs >= nextGazeIntervalMs) {
    lastGazeCycleMs = now;
    nextGazeIntervalMs = random(4000, 8000);
    int randDir = random(0, 3);
    if (randDir == 0) rt.picaioXp = 2; // Look Left
    else if (randDir == 1) rt.picaioXp = 16; // Center
    else rt.picaioXp = 30; // Look Right
  }

  if (rt.petActive && now >= rt.petUntil) {
    rt.petActive = false;
    rt.faceMode = FACE_DAY;
  }

  if (now - rt.lastAutoTimePeek >= AUTO_TIME_PEEK_MS) {
    rt.lastAutoTimePeek = now;
    rt.timeOverlayActive = true;
    rt.timeOverlayUntil = now + TIME_OVERLAY_MS;
  }
}

void maybeWakeTimeDisplay() {
  if (!rt.timeOverlayActive) return;
  if (millis() >= rt.timeOverlayUntil) {
    rt.timeOverlayActive = false;
  }
}

void updateWelcomeState() {
  if (rt.welcomeActive && millis() > rt.welcomeUntil) {
    if (!settings.setupComplete && rt.welcomeStep == 0) {
      rt.welcomeStep = 1;
      rt.welcomeUntil = millis() + 600000UL; // 10 minutes setup screen
    } else {
      rt.welcomeActive = false;
      rt.faceMode = FACE_DAY;
    }
  }
}

void updatePeriodicGreeting() {
  if (rt.welcomeActive || rt.menuOpen || rt.faceMode == FACE_MENU || rt.faceMode == FACE_WIFI_SETUP || rt.faceMode == FACE_CONFIGURING) {
    rt.greetingBubbleActive = false;
    return;
  }

  uint32_t now = millis();
  // Trigger every 4 seconds (2 seconds on, 2 seconds off)
  if (now - rt.lastGreetingAt >= 5000) {
    rt.lastGreetingAt = now;
    rt.greetingBubbleActive = true;
    rt.greetingBubbleUntil = now + 2000;
    rt.greetingIndex = (rt.greetingIndex + 1) % 5;
  }
  if (rt.greetingBubbleActive && now >= rt.greetingBubbleUntil) {
    rt.greetingBubbleActive = false;
  }
}

void updateLampAutoOff() {
  if (!settings.lampState || settings.ledAutoOffMinutes == 0) return;
  static uint32_t lampOnSince = 0;
  if (settings.lampState && lampOnSince == 0) lampOnSince = millis();
  if (!settings.lampState) lampOnSince = 0;
  if (lampOnSince && millis() - lampOnSince > (uint32_t)settings.ledAutoOffMinutes * 60000UL) {
    setLampOff();
    lampOnSince = 0;
    saveSettings();
  }
}

void handleTouchReleaseTap(uint32_t heldMs) {
  if (heldMs >= LONG_TOUCH_MS) {
    return;
  }

  uint32_t now = millis();
  if (rt.faceMode == FACE_WIFI_SETUP) {
    closeWiFiSetup();
    return;
  }
  if (rt.menuOpen) {
    rt.menuIndex = (rt.menuIndex + 1) % MENU_ITEM_COUNT;
    rt.menuUntil = now + 15000;
    return;
  }

  if (now - rt.touch.lastTapAt > TAP_WINDOW_MS) {
    rt.touch.tapCount = 0;
  }

  rt.touch.tapCount++;
  rt.touch.lastTapAt = now;

  if (rt.touch.tapCount == 3) {
    toggleLampMode();
    rt.touch.tapCount = 0;
    return;
  }
}

void handleTouchInput() {
  if (rt.welcomeActive || rt.faceMode == FACE_CONFIGURING) {
    return;
  }
  uint32_t now = millis();
  bool pressed = digitalRead(PIN_TOUCH) == HIGH;

  // Alarm dismissal moved to long press only

  // Track touch press transition
  if (pressed && !rt.touch.pressed) {
    Serial.println("Touch down");
    tone(PIN_BUZZER, 2000, 50);
    rt.touch.pressed = true;
    rt.touch.pressedAt = now;
    rt.touch.longHandled = false;
    if (settings.monitoringEnabled) {
      triggerSecurityAlarm("touch-detected");
    } else {
      triggerCloudEvent("touch-down");
    }
  }

  // Detect long touch while holding
  if (pressed && rt.touch.pressed && !rt.touch.longHandled && now - rt.touch.pressedAt >= LONG_TOUCH_MS) {
    rt.touch.longHandled = true;
    Serial.println("Long touch detected");
    tone(PIN_BUZZER, 2400, 150);

    if (rt.alarmActive || (rt.faceMode == FACE_ALARM && rt.alarmMissed)) {
      rt.alarmActive = false;
      rt.alarmMissed = false;
      rt.alarmIndex = 255;
      rt.missedAlarmIndex = 255;
      noTone(PIN_BUZZER);
      rt.faceMode = FACE_DAY;
      setLampOff();
      saveSettings();
      triggerCloudEvent("alarm-dismissed");
      return;
    }

    // If inside a sub-mode page (heart rate, info, wifi setup), long press exits to default face
    if (rt.faceMode == FACE_HEART || rt.faceMode == FACE_INFO || rt.faceMode == FACE_WIFI_SETUP) {
      if (rt.faceMode == FACE_HEART) {
        stopHeartMode();
      } else if (rt.faceMode == FACE_WIFI_SETUP) {
        closeWiFiSetup();
      } else {
        rt.faceMode = FACE_DAY;
      }
      rt.menuOpen = false;
      Serial.println("Exited sub-mode via long press");
    }
    // Else if menu is open, long press selects/activates highlight item
    else if (rt.menuOpen) {
      activateMenuItem();
      Serial.println("Selected menu item via long press");
    }
    // Else, we are on normal screen: long press opens the menu
    else {
      openMenu();
      triggerCloudEvent("long-touch");
      Serial.println("Opened menu via long press");
    }
  }

  // Handle release
  if (!pressed && rt.touch.pressed) {
    uint32_t heldMs = now - rt.touch.pressedAt;
    Serial.printf("Touch up, held %u ms\n", heldMs);
    rt.touch.pressed = false;

    if (rt.touch.longHandled) {
      return;
    }

    handleTouchReleaseTap(heldMs);
  }

  // Only reset the tapCount if the sensor is NOT currently pressed.
  if (!pressed && rt.touch.tapCount > 0 && now - rt.touch.lastTapAt > TAP_WINDOW_MS) {
    rt.touch.tapCount = 0;
  }

  if (rt.menuOpen && now > rt.menuUntil) {
    closeMenu();
  }
}

void openSetupPortal(bool initial, uint32_t durationMs) {
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP("GEM Buddy", GEM_HOTSPOT_PASSWORD);
  rt.menuUntil = millis() + durationMs;
  rt.hotspotActiveState = true;
  rt.hotspotStateTimer = millis() + 600000UL;
}

void startHotspotPortal(bool allowStation, bool initialSetup) {
  WiFi.mode(allowStation ? WIFI_AP_STA : WIFI_AP);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP("GEM Buddy", GEM_HOTSPOT_PASSWORD);
}

void connectSavedWiFi() {
  return; // Deprecated, WiFi connection is fully handled by setupNetworking()

  WiFi.mode(WIFI_STA);
  WiFi.begin(settings.wifiSsid, settings.wifiPass);

  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 12000) {
    delay(250);
  }
}

String jsonString(const char* value) {
  String out = "\"";
  if (!value) value = "";
  for (const char* p = value; *p; ++p) {
    if (*p == '\\' || *p == '"') out += '\\';
    out += *p;
  }
  out += "\"";
  return out;
}

String buildStateJson() {
  String json;
  json.reserve(2048);
  json += "{";
  json += "\"deviceName\":" + jsonString(settings.deviceName) + ",";
  json += "\"userName\":" + jsonString(settings.userName) + ",";
  json += "\"timezoneLabel\":" + jsonString(settings.timezoneLabel) + ",";
  json += "\"timezoneOffsetMinutes\":" + String(settings.timezoneOffsetMinutes) + ",";
  json += "\"wifiEnabled\":" + String(settings.wifiEnabled ? "true" : "false") + ",";
  json += "\"wifiConnected\":" + String(WiFi.status() == WL_CONNECTED ? "true" : "false") + ",";
  json += "\"setupComplete\":" + String(settings.setupComplete ? "true" : "false") + ",";
  json += "\"hotspotEnabled\":" + String(settings.hotspotEnabled ? "true" : "false") + ",";
  json += "\"hotspotActive\":" + String((WiFi.getMode() == WIFI_AP || WiFi.getMode() == WIFI_AP_STA) ? "true" : "false") + ",";
  json += "\"batteryPercent\":" + String(rt.batteryPercent) + ",";
  json += "\"batteryVoltage\":" + String(rt.batteryVoltage, 2) + ",";
  json += "\"ldrRaw\":" + String(rt.ldrRaw) + ",";
  json += "\"lampState\":" + String(settings.lampState ? "true" : "false") + ",";
  json += "\"lampMode\":" + String(settings.lampMode) + ",";
  json += "\"monitoringEnabled\":" + String(settings.monitoringEnabled ? "true" : "false") + ",";
  json += "\"faceMode\":" + String((int)rt.faceMode) + ",";
  json += "\"timeValid\":" + String(validClock() ? "true" : "false") + ",";
  json += "\"bpm\":" + String(rt.bpm) + ",";
  json += "\"ip\":\"" + WiFi.localIP().toString() + "\"";
  json += ",\"alarms\":[";
  for (uint8_t i = 0; i < settings.alarmCount && i < 6; ++i) {
    if (i) json += ",";
    json += "{";
    json += "\"enabled\":" + String(settings.alarms[i].enabled ? "true" : "false") + ",";
    json += "\"hour\":" + String(settings.alarms[i].hour) + ",";
    json += "\"minute\":" + String(settings.alarms[i].minute) + ",";
    json += "\"name\":" + jsonString(settings.alarms[i].name);
    json += "}";
  }
  json += "]";
  json += "}";
  return json;
}

void handleRoot() {
  String html;
  html.reserve(6000);

  // --- Head & Styles ---
  html += "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta charset='utf-8'><title>GEM Buddy Setup</title><style>";
  html += "*{box-sizing:border-box;margin:0;padding:0}";
  html += "body{font-family:system-ui,-apple-system,sans-serif;background:linear-gradient(135deg,#09111f 0%,#1b2a44 100%);color:#eef3ff;min-height:100vh;padding:16px}";
  html += ".wrap{max-width:680px;margin:0 auto}";
  html += "h1{font-size:26px;font-weight:800;margin-bottom:4px}";
  html += ".sub{font-size:13px;opacity:.55;margin-bottom:20px}";
  html += ".card{background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.13);border-radius:20px;padding:18px;margin-bottom:16px;backdrop-filter:blur(12px)}";
  html += ".card h2{font-size:14px;font-weight:700;letter-spacing:.5px;text-transform:uppercase;opacity:.6;margin-bottom:14px}";
  html += ".row{display:grid;grid-template-columns:1fr 1fr;gap:10px}";
  html += "label{display:block;font-size:11px;opacity:.65;margin-bottom:4px;margin-top:12px}";
  html += "input[type=text],input[type=password],input[type=time]{width:100%;padding:9px 12px;border-radius:10px;border:1px solid rgba(255,255,255,.15);background:rgba(0,0,0,.35);color:#fff;font-size:13px}";
  html += "input[type=text]:focus,input[type=password]:focus,input[type=time]:focus{outline:none;border-color:#79d8ff}";
  html += ".alarm-block{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.09);border-radius:14px;padding:12px;margin-bottom:10px}";
  html += ".alarm-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px}";
  html += ".alarm-header span{font-size:13px;font-weight:600;opacity:.8}";
  html += ".toggle{display:flex;align-items:center;gap:6px;font-size:12px;opacity:.7;cursor:pointer}";
  html += ".toggle input[type=checkbox]{width:16px;height:16px;accent-color:#79d8ff;cursor:pointer}";
  html += ".stat{display:inline-block;background:rgba(121,216,255,.12);border-radius:8px;padding:4px 10px;font-size:12px;margin:3px 3px 3px 0}";
  html += ".stat.ok{background:rgba(80,220,140,.15);color:#50dc8c}";
  html += ".stat.off{background:rgba(255,255,255,.06);opacity:.5}";
  html += ".btn{display:block;width:100%;margin-top:16px;padding:13px;border:0;border-radius:14px;background:linear-gradient(90deg,#79d8ff,#4fb3e8);color:#06192a;font-size:15px;font-weight:800;cursor:pointer;letter-spacing:.3px}";
  html += ".btn:hover{opacity:.9}";
  html += ".link-row{text-align:center;margin-top:14px;font-size:12px;opacity:.45}";
  html += ".link-row a{color:#79d8ff}";
  html += "</style></head><body><div class='wrap'>";

  // --- Header ---
  html += "<h1>⚡ GEM Buddy</h1>";
  html += "<p class='sub'>Device Setup & Configuration Portal</p>";

  // --- Status Card ---
  html += "<div class='card'><h2>Live Status</h2>";
  html += "<span class='stat" + String(WiFi.status() == WL_CONNECTED ? " ok" : " off") + "'>";
  html += WiFi.status() == WL_CONNECTED ? "📶 Wi-Fi On" : "📶 Wi-Fi Off";
  html += "</span>";
  html += "<span class='stat" + String(validClock() ? " ok" : " off") + "'>";
  html += validClock() ? "🕐 Time Set" : "🕐 Time Not Set";
  html += "</span>";
  html += "<span class='stat" + String(settings.monitoringEnabled ? " ok" : " off") + "'>";
  html += settings.monitoringEnabled ? "🔒 Guard On" : "🔒 Guard Off";
  html += "</span>";
  html += "<span class='stat'>";
  html += "🔋 " + String(rt.batteryPercent) + "%";
  html += "</span>";
  if (WiFi.status() == WL_CONNECTED) {
    html += "<span class='stat ok'>📍 " + WiFi.localIP().toString() + "</span>";
  }
  html += "</div>";

  // --- Main Form ---
  html += "<form method='post' action='/api/save'>";

  // Profile
  html += "<div class='card'><h2>👤 Profile</h2>";
  html += "<label>Your Name</label><input type='text' name='userName' value='" + String(settings.userName) + "'>";
  html += "<label>Device Nickname</label><input type='text' name='deviceName' value='" + String(settings.deviceName) + "'>";
  html += "<div class='row'>";
  html += "<div><label>Timezone Label</label><input type='text' name='tzLabel' value='" + String(settings.timezoneLabel) + "'></div>";
  html += "<div><label>UTC Offset (min)</label><input type='text' name='tzOffset' value='" + String(settings.timezoneOffsetMinutes) + "'></div>";
  html += "</div></div>";

  // Wi-Fi
  html += "<div class='card'><h2>📶 Wi-Fi Connection</h2>";
  html += "<label>SSID (Network Name)</label><input type='text' name='wifiSsid' value='" + String(settings.wifiSsid) + "'>";
  html += "<label>Password</label><input type='password' name='wifiPass' value='" + String(settings.wifiPass) + "'>";
  html += "<label class='toggle' style='margin-top:14px'><input type='checkbox' name='wifiEnabled'";
  if (settings.wifiEnabled) html += " checked";
  html += "> Connect to Wi-Fi on boot</label>";
  html += "<label class='toggle'><input type='checkbox' name='hotspotEnabled'";
  if (settings.hotspotEnabled) html += " checked";
  html += "> Keep hotspot (AP) always active</label>";
  html += "</div>";

  // Security
  html += "<div class='card'><h2>🔒 Desk Security</h2>";
  html += "<label class='toggle' style='margin-top:0'><input type='checkbox' name='monitoringEnabled'";
  if (settings.monitoringEnabled) html += " checked";
  html += "> Enable shadow/movement monitoring</label>";
  html += "<label>Cloud Webhook URL (for alerts)</label><input type='text' name='webhook' value='" + String(settings.cloudWebhook) + "'>";
  html += "</div>";

  // Alarms — 6 slots
  html += "<div class='card'><h2>⏰ Reminders & Alarms (max 6)</h2>";
  for (uint8_t i = 0; i < 6; i++) {
    bool hasAlarm = (i < settings.alarmCount);
    String aName  = hasAlarm ? String(settings.alarms[i].name)   : "Alarm " + String(i + 1);
    uint8_t aHour = hasAlarm ? settings.alarms[i].hour   : 7;
    uint8_t aMin  = hasAlarm ? settings.alarms[i].minute : 0;
    bool aEnabled = hasAlarm ? settings.alarms[i].enabled : false;

    char timeBuf[6];
    snprintf(timeBuf, sizeof(timeBuf), "%02d:%02d", aHour, aMin);

    html += "<div class='alarm-block'>";
    html += "<div class='alarm-header'><span>Reminder " + String(i + 1) + "</span>";
    html += "<label class='toggle'><input type='checkbox' name='alarm" + String(i) + "_enabled'";
    if (aEnabled) html += " checked";
    html += "> Enabled</label></div>";
    html += "<div class='row'>";
    html += "<div><label>Time</label><input type='time' name='alarm" + String(i) + "_hour' value='" + String(timeBuf) + "' onchange=\"var p=this.value.split(':');document.getElementById('am" + String(i) + "h').value=p[0];document.getElementById('am" + String(i) + "m').value=p[1];\"></div>";
    html += "<div><label>Name / Label</label><input type='text' name='alarm" + String(i) + "_name' value='" + aName + "'></div>";
    html += "</div>";
    // Hidden fields to submit hour and minute separately from the time input
    html += "<input type='hidden' id='am" + String(i) + "h' name='alarm" + String(i) + "_hour_v' value='" + String(aHour) + "'>";
    html += "<input type='hidden' id='am" + String(i) + "m' name='alarm" + String(i) + "_minute_v' value='" + String(aMin) + "'>";
    html += "</div>";
  }
  html += "<input type='hidden' name='alarmCount' value='6'>";
  html += "</div>";

  // Submit
  html += "<button class='btn' type='submit'>💾 Save All Settings & Reboot</button>";
  html += "</form>";

  // Links
  html += "<p class='link-row'><a href='/api/state'>JSON State</a> &nbsp;|&nbsp; <a href='/api/factory-reset'>Factory Reset</a></p>";
  html += "</div></body></html>";

  server.send(200, "text/html", html);
}


void applySettingsFromRequest() {
  bool oldMonitoring = settings.monitoringEnabled;
  bool oldWifi = settings.wifiEnabled;

  if (server.hasArg("userName")) copyText(settings.userName, sizeof(settings.userName), server.arg("userName").c_str());
  if (server.hasArg("deviceName")) copyText(settings.deviceName, sizeof(settings.deviceName), server.arg("deviceName").c_str());
  if (server.hasArg("tzLabel")) copyText(settings.timezoneLabel, sizeof(settings.timezoneLabel), server.arg("tzLabel").c_str());
  if (server.hasArg("tzOffset")) settings.timezoneOffsetMinutes = server.arg("tzOffset").toInt();
  if (server.hasArg("wifiSsid")) copyText(settings.wifiSsid, sizeof(settings.wifiSsid), server.arg("wifiSsid").c_str());
  if (server.hasArg("wifiPass")) copyText(settings.wifiPass, sizeof(settings.wifiPass), server.arg("wifiPass").c_str());
  settings.wifiEnabled = server.hasArg("wifiEnabled") ? argTrue(server.arg("wifiEnabled")) : false;
  settings.hotspotEnabled = server.hasArg("hotspotEnabled") ? argTrue(server.arg("hotspotEnabled")) : false;
  settings.monitoringEnabled = server.hasArg("monitoringEnabled") ? argTrue(server.arg("monitoringEnabled")) : false;
  if (server.hasArg("webhook")) copyText(settings.cloudWebhook, sizeof(settings.cloudWebhook), server.arg("webhook").c_str());

  if (settings.monitoringEnabled && (!oldMonitoring || !settings.wifiEnabled)) {
    settings.wifiEnabled = true;
    scheduleNetworking();
  }

  for (uint8_t i = 0; i < 6; ++i) {
    String base = "alarm" + String(i);
    String hourKey = base + "_hour";   // may be "HH:MM" from time input or plain int from app
    String minKey  = base + "_minute"; // plain int from app only
    String nameKey = base + "_name";
    String enabledKey = base + "_enabled";

    if (server.hasArg(hourKey)) {
      String val = server.arg(hourKey);
      int colonIdx = val.indexOf(':');
      if (colonIdx >= 0) {
        // Format "HH:MM" from browser time input
        settings.alarms[i].hour   = (uint8_t)val.substring(0, colonIdx).toInt();
        settings.alarms[i].minute = (uint8_t)val.substring(colonIdx + 1).toInt();
      } else {
        // Plain integer from app API
        settings.alarms[i].hour = (uint8_t)val.toInt();
        if (server.hasArg(minKey)) {
          settings.alarms[i].minute = (uint8_t)server.arg(minKey).toInt();
        }
      }
    }
    if (server.hasArg(nameKey)) {
      copyText(settings.alarms[i].name, sizeof(settings.alarms[i].name), server.arg(nameKey).c_str());
    }
    // Checkboxes: present = enabled, absent = disabled (both web portal and app POST)
    settings.alarms[i].enabled = server.hasArg(enabledKey) ? argTrue(server.arg(enabledKey)) : false;
  }

  if (server.hasArg("alarmCount")) {
    int count = server.arg("alarmCount").toInt();
    if (count < 0) count = 0;
    if (count > 6) count = 6;
    settings.alarmCount = (uint8_t)count;
  }

  if (server.hasArg("lampMode")) settings.lampMode = (uint8_t)server.arg("lampMode").toInt();
  if (server.hasArg("lampBrightness")) settings.lampBrightness = (uint8_t)server.arg("lampBrightness").toInt();
  if (server.hasArg("lampState")) {
    settings.lampState = argTrue(server.arg("lampState"));
    if (!settings.lampState && rt.alarmActive) {
      rt.alarmActive = false;
      rt.alarmIndex = 255;
      noTone(PIN_BUZZER);
      rt.faceMode = FACE_DAY;
      setAllLeds(0);
    }
  }
  if (server.hasArg("ledAutoOffMinutes")) settings.ledAutoOffMinutes = (uint8_t)server.arg("ledAutoOffMinutes").toInt();

  settings.setupComplete = true;
  saveSettings();
}

void handleSave() {
  rt.lastAppRequestAt = millis();
  applySettingsFromRequest();
  if (server.hasArg("epoch")) {
    setTimeFromArgs();
  }

  bool needsReboot = false;
  if (server.hasArg("wifiSsid") || server.hasArg("wifiPass") || server.hasArg("reboot")) {
    needsReboot = true;
  }

  server.sendHeader("Access-Control-Allow-Origin", "*");
  if (needsReboot) {
    rt.faceMode = FACE_CONFIGURING;
    rt.welcomeActive = false;
    rt.lastOledUpdate = 0; // Force immediate redraw
    renderScreen();

    String response = "<html><body>Saved to flash. Rebooting... <a href='/'>Back</a></body></html>";
    server.send(200, "text/html", response);
    scheduleRestart();
  } else {
    server.send(200, "application/json", "{\"ok\":true}");
  }
}

void handleState() {
  rt.lastAppRequestAt = millis();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", buildStateJson());
}

void handleTimeSet() {
  rt.lastAppRequestAt = millis();
  setTimeFromArgs();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"ok\":true}");
}

void handleFactoryReset() {
  setDefaultSettings(settings);
  saveSettings();
  
  rt.faceMode = FACE_CONFIGURING;
  rt.welcomeActive = false;
  rt.lastOledUpdate = 0; // Force immediate redraw
  renderScreen();

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "text/plain", "Factory reset done. Rebooting...");
  scheduleRestart();
}

void handleHeartApi() {
  rt.lastAppRequestAt = millis();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  if (server.hasArg("action")) {
    String action = server.arg("action");
    if (action == "start") {
      startHeartMode();
      server.send(200, "application/json", "{\"ok\":true,\"scanning\":true}");
      return;
    } else if (action == "stop") {
      stopHeartMode();
      server.send(200, "application/json", "{\"ok\":true,\"scanning\":false}");
      return;
    }
  }
  server.send(200, "application/json", "{\"ok\":true,\"scanning\":" + String(rt.heartModeActive ? "true" : "false") + ",\"bpm\":" + String(rt.bpm) + "}");
}

void handleNotFound() {
  server.send(404, "text/plain", "GEM says not found");
}

void setupPins() {
  pinMode(PIN_TOUCH, INPUT_PULLDOWN);
  pinMode(PIN_PULSE_POWER, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LDR_ADC, INPUT);
  pinMode(PIN_BATTERY_ADC, INPUT);
  pinMode(PIN_PULSE_ADC, INPUT);

  analogSetPinAttenuation(PIN_LDR_ADC, ADC_11db);
  analogSetPinAttenuation(PIN_BATTERY_ADC, ADC_11db);
  analogSetPinAttenuation(PIN_PULSE_ADC, ADC_11db);

  ledcAttach(PIN_LED1, 5000, 8);
  ledcAttach(PIN_LED2, 5000, 8);
  ledcAttach(PIN_LED3, 5000, 8);
  ledcAttach(PIN_LED4, 5000, 8);
  setAllLeds(0);
  digitalWrite(PIN_PULSE_POWER, LOW);
}
void setupNetworking() {
  Serial.println("Shutting down WiFi radio...");
  WiFi.mode(WIFI_OFF);
  delay(150); // Allow RF radio to settle

  const bool canConnectStation = settings.wifiEnabled && settings.wifiSsid[0] != '\0';
  // Keep hotspot active on boot for 10 min window (even if hotspotEnabled is false in settings)
  const bool keepHotspot = true; 

  Serial.println("Starting SoftAP hotspot (temporary boot window)...");
  startHotspotPortal(canConnectStation, !settings.setupComplete);
  delay(100); // Allow hotspot startup to settle

  if (canConnectStation) {
    Serial.println("Configuring station connection...");
    WiFi.mode(WIFI_AP_STA);
    delay(100); // Allow mode transition to settle
    
    // Mask SSID for security print
    char maskedSsid[32] = "";
    if (strlen(settings.wifiSsid) > 3) {
      strncpy(maskedSsid, settings.wifiSsid, 3);
      maskedSsid[3] = '\0';
      strcat(maskedSsid, "...");
    } else {
      strcpy(maskedSsid, "...");
    }
    Serial.printf("Connecting to station SSID: %s (pass length: %d)\n", maskedSsid, strlen(settings.wifiPass));
    
    if (settings.wifiPass[0] == '\0') {
      WiFi.begin(settings.wifiSsid);
    } else {
      WiFi.begin(settings.wifiSsid, settings.wifiPass);
    }

    uint32_t start = millis();
    Serial.print("Connecting to Wi-Fi");
    while (WiFi.status() != WL_CONNECTED && millis() - start < 12000) {
      delay(250);
      Serial.print(".");
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("WiFi Connected! IP: " + WiFi.localIP().toString());
      configTime(settings.timezoneOffsetMinutes * 60, 0, "pool.ntp.org", "time.nist.gov");
      Serial.println("NTP Time Sync Configured.");
      
      if (MDNS.begin("gem-buddy")) {
        Serial.println("mDNS responder started: gem-buddy.local");
        MDNS.addService("http", "tcp", 80);
      } else {
        Serial.println("Error setting up MDNS responder!");
      }
    } else {
      Serial.println("WiFi Connection Failed!");
      // Hotspot is already started, so we don't need to start a fallback.
    }
  } else {
    Serial.println("No Station configuration. Setting Mode...");
    WiFi.mode(WIFI_AP);
    delay(100);
  }
}
void setupServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/state", HTTP_GET, handleState);
  server.on("/api/save", HTTP_ANY, handleSave);
  server.on("/api/time", HTTP_ANY, handleTimeSet);
  server.on("/api/factory-reset", HTTP_GET, handleFactoryReset);
  server.on("/api/heart", HTTP_ANY, handleHeartApi);
  
  // OTA firmware update endpoint
  server.on("/api/update", HTTP_POST, []() {
    server.sendHeader("Access-Control-Allow-Origin", "*");
    server.sendHeader("Connection", "close");
    server.send(200, "text/plain", (Update.hasError()) ? "FAIL" : "OK");
    delay(1000);
    ESP.restart();
  }, []() {
    HTTPUpload& upload = server.upload();
    if (upload.status == UPLOAD_FILE_START) {
      Serial.printf("Update: %s\n", upload.filename.c_str());
      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) { // start with max available size
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_WRITE) {
      if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_END) {
      if (Update.end(true)) { // true to set the size to the current progress
        Serial.printf("Update Success: %u\nRebooting...\n", upload.totalSize);
      } else {
        Update.printError(Serial);
      }
    }
  });

  server.onNotFound(handleNotFound);
  server.begin();
}

void bootScreen(bool initial) {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  if (initial) {
    drawCentered(18, "GEM", u8g2_font_ncenB08_tr);
    drawCentered(32, "Hello!", u8g2_font_5x7_tr);
    drawCentered(42, "Welcome, I am GEM", u8g2_font_5x7_tr);
    drawCentered(54, "Use the app to bring me to life", u8g2_font_5x7_tr);
  } else {
    drawCentered(25, "GEM", u8g2_font_ncenB08_tr);
    drawCentered(44, "Starting...", u8g2_font_5x7_tr);
  }
  u8g2.sendBuffer();
}

void printResetReason() {
  esp_reset_reason_t reason = esp_reset_reason();
  Serial.printf("ESP32 Reset Reason: %d - ", reason);
  switch (reason) {
    case ESP_RST_UNKNOWN:   Serial.println("Unknown"); break;
    case ESP_RST_POWERON:   Serial.println("Power-on"); break;
    case ESP_RST_EXT:       Serial.println("External pin"); break;
    case ESP_RST_SW:        Serial.println("Software reset"); break;
    case ESP_RST_PANIC:     Serial.println("Exception/Panic"); break;
    case ESP_RST_INT_WDT:   Serial.println("Interrupt Watchdog"); break;
    case ESP_RST_TASK_WDT:  Serial.println("Task Watchdog"); break;
    case ESP_RST_WDT:       Serial.println("Other Watchdog"); break;
    case ESP_RST_DEEPSLEEP: Serial.println("Deep Sleep"); break;
    case ESP_RST_BROWNOUT:  Serial.println("Brownout"); break;
    case ESP_RST_SDIO:      Serial.println("SDIO"); break;
    default:                Serial.println("Other"); break;
  }
}

void setup() {
  Serial.begin(115200);
  delay(500); // Give serial monitor time to connect
  Serial.println("\n=================================");
  Serial.println("GEM Starting Setup Sequence...");
  printResetReason();
  
  Serial.println("[1/7] Initializing Pins...");
  setupPins();
  
  Serial.println("[2/7] Initializing Display...");
  u8g2.begin();
  Serial.println("Display initialized successfully");

  Serial.println("[3/7] Loading Settings...");
  loadSettings();
  Serial.printf("Settings loaded: setupComplete = %s\n", settings.setupComplete ? "true" : "false");

  // Restore last known time from NVS to prevent resetting to 1970 on boot
  prefs.begin(GEM_PREF_NAMESPACE, true);
  uint32_t lastTime = prefs.getUInt("lastTime", 1700000000);
  prefs.end();
  struct timeval tv;
  tv.tv_sec = lastTime;
  tv.tv_usec = 0;
  settimeofday(&tv, nullptr);
  Serial.printf("System time initialized to last known epoch: %u\n", lastTime);
  
  bootScreen(!settings.setupComplete);
  
  if (!settings.setupComplete) {
    rt.welcomeActive = true;
    rt.welcomeStep = 0;
    rt.welcomeUntil = millis() + 8000; // 8 seconds hello screen
  } else {
    rt.welcomeActive = true;
    rt.welcomeStep = 2; // Returning user greeting
    rt.welcomeUntil = millis() + 8000; // 8 seconds personalized greeting screen
    rt.faceMode = FACE_WELCOME;
  }
  
  // Initialize hotspot timer cycle on boot (start with 10-minute ON phase)
  rt.hotspotActiveState = true;
  rt.hotspotStateTimer = millis() + 600000UL;

  Serial.println("[4/7] Refreshing Sensors...");
  refreshSensors(true);
  Serial.println("Sensors refreshed successfully");
  
  Serial.println("[5/7] Initializing Networking...");
  setupNetworking();
  Serial.println("Networking initialization finished");
  
  Serial.println("[6/7] Initializing Web Server...");
  setupServer();
  Serial.println("Web server started successfully");

  if (validClock() && settings.setupComplete) {
    rt.welcomeActive = false;
  }

  Serial.println("[7/7] Rendering first screen...");
  renderScreen();
  Serial.println("Setup Sequence Finished!");
  Serial.println("=================================\n");
}
void updateHotspotTimeout() {
  if (settings.hotspotEnabled) return;
  if (!settings.setupComplete) return;

  const bool canConnectStation = settings.wifiEnabled && settings.wifiSsid[0] != '\0';
  uint32_t now = millis();

  if (rt.hotspotActiveState) {
    // Hotspot is in the ON phase of the cycle
    int stationNum = WiFi.softAPgetStationNum();
    if (stationNum > 0) {
      // Client connected, keep ON timer extended
      rt.hotspotStateTimer = now + 600000UL;
    } else if (now > rt.hotspotStateTimer) {
      Serial.println("Hotspot cycle: Transitioning to OFF phase (20 mins)...");
      rt.hotspotActiveState = false;
      rt.hotspotStateTimer = now + 1200000UL;
      
      if (WiFi.status() == WL_CONNECTED) {
        WiFi.mode(WIFI_STA);
      } else {
        WiFi.mode(WIFI_OFF);
      }
    }
  } else {
    // Hotspot is in the OFF phase of the cycle
    if (now > rt.hotspotStateTimer) {
      Serial.println("Hotspot cycle: Transitioning to ON phase (10 mins)...");
      rt.hotspotActiveState = true;
      rt.hotspotStateTimer = now + 600000UL;
      
      startHotspotPortal(canConnectStation, false);
    }
  }
}

void loop() {
  server.handleClient();
  if (restartPending && (int32_t)(millis() - restartAtMs) >= 0) {
    delay(100);
    ESP.restart();
  }
  if (networkingPending && !restartPending && (int32_t)(millis() - networkingAtMs) >= 0) {
    networkingPending = false;
    setupNetworking();
  }
  refreshSensors(false);
  handleTouchInput();
  updateWelcomeState();
  updatePeriodicGreeting();
  updateHotspotTimeout();
  updateMenuTimeout();
  updateHeartMode();
  updateAlarmRuntime();
  checkAlarms();
  checkAutoLamp();
  maybeWakeTimeDisplay();
  updateLampAutoOff();

  // Periodically save the last known time to NVS (every 60 seconds) if time is valid
  static uint32_t lastTimeSaveMs = 0;
  if (validClock() && millis() - lastTimeSaveMs >= 60000) {
    lastTimeSaveMs = millis();
    saveLastKnownTime();
  }

  // Guard-mode keepalive ping to broker every 30 seconds
  if (settings.monitoringEnabled && millis() - rt.lastGuardPingMs >= 30000UL) {
    rt.lastGuardPingMs = millis();
    sendGuardPing();
  }

  if (rt.batteryCritical) {
    if (!rt.deepSleepReady) {
      rt.deepSleepReady = true;
      delay(100);
      enterDeepSleep();
    }
  }

  applyPowerPolicy();

  if (rt.timeOverlayActive && millis() >= rt.timeOverlayUntil) {
    rt.timeOverlayActive = false;
  }

  updateFaceAnimation();
  handleBlinks();

  if (millis() - rt.lastOledUpdate >= OLED_REFRESH_MS) {
    rt.lastOledUpdate = millis();
    renderScreen();
  }
}
