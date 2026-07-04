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

#include "GemBuddyConfig.h"

// ---------------- Forward Declarations ----------------
void openSetupPortal(bool initial, uint32_t durationMs = 10UL * 60UL * 1000UL);
void setupNetworking();

// ---------------- Display ----------------
// For SH1106 OLED screens (fixes the 2-pixel shift/glitch line on the left side)
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, u8x8_pin_none);
// For SSD1306 OLED screens (uncomment if using SSD1306)
// U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, u8x8_pin_none);

// ---------------- Runtime ----------------
Preferences prefs;
WebServer server(80);

GemSettings settings;
bool restartPending = false;
uint32_t restartAtMs = 0;

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
  FACE_WIFI_SETUP
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

  bool menuOpen = false;
  uint8_t menuIndex = 0;
  uint32_t menuUntil = 0;

  bool petActive = false;
  uint32_t petUntil = 0;

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

  bool lampNotificationFlash = false;
  uint32_t lampNotificationUntil = 0;
  uint32_t lampLastTick = 0;

  uint32_t lastFaceFrame = 0;
  uint32_t lastOledUpdate = 0;
  uint32_t lastBatteryRead = 0;
  uint32_t lastLdrRead = 0;
  uint32_t lastAlarmCheck = 0;
  uint32_t lastCloudEvent = 0;

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
constexpr const char* GEM_HOTSPOT_PASSWORD = "12345678";

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

void loadSettings() {
  setDefaultSettings(settings);

  prefs.begin(GEM_PREF_NAMESPACE, true);
  size_t got = prefs.getBytes("settings", &settings, sizeof(settings));
  prefs.end();

  if (got != sizeof(settings) ||
      settings.magic != GEM_SETTINGS_MAGIC ||
      settings.version != GEM_SETTINGS_VERSION) {
    setDefaultSettings(settings);
    saveSettings();
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
    rt.lastLdrRead = now;
    rt.ldrRaw = readLdrRaw();
    rt.ambientDark = rt.ldrRaw < 1600;

    // Detect sudden shift (shadow or flash)
    if (!force && oldLdr > 0 && settings.monitoringEnabled) {
      int diff = (int)rt.ldrRaw - (int)oldLdr;
      if (diff < -800) {
        triggerCloudEvent("shadow-detected");
      } else if (diff > 800) {
        triggerCloudEvent("flash-detected");
      }
    }
  }
}

void applyPowerPolicy() {
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
  rt.alarmUntil = millis() + 15000;
  rt.alarmIndex = idx;
  rt.alarmToneStep = 0;
  rt.alarmToneStepAt = 0;
  rt.faceMode = FACE_ALARM;
  rt.timeOverlayActive = false;
  rt.menuOpen = false;
  rt.petActive = false;
  settings.lampState = true;
  settings.lampMode = LAMP_BREATHING;
  rt.lampNotificationFlash = true;
  rt.lampNotificationUntil = millis() + 15000;
  triggerCloudEvent("alarm");
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

  for (uint8_t i = 0; i < settings.alarmCount && i < 3; ++i) {
    if (!settings.alarms[i].enabled) continue;
    if (tmv.tm_hour == settings.alarms[i].hour && tmv.tm_min == settings.alarms[i].minute) {
      static uint32_t lastMinuteKey[3] = {0, 0, 0};
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
    rt.alarmIndex = 255;
    noTone(PIN_BUZZER);
    return;
  }

  if (now >= rt.alarmToneStepAt) {
    static const uint16_t notes[] = { 784, 988, 1175, 988, 784, 0 };
    uint16_t note = notes[rt.alarmToneStep % (sizeof(notes) / sizeof(notes[0]))];
    rt.alarmToneStep++;
    rt.alarmToneStepAt = now + 240;
    if (note == 0) {
      noTone(PIN_BUZZER);
    } else {
      tone(PIN_BUZZER, note, 180);
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
  digitalWrite(PIN_PULSE_POWER, HIGH);
  rt.faceMode = FACE_HEART;
}

void stopHeartMode() {
  rt.heartModeActive = false;
  digitalWrite(PIN_PULSE_POWER, LOW);
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
  if (rt.pulseBaseline <= 1.0f) {
    rt.pulseBaseline = raw;
  }

  rt.pulseBaseline = rt.pulseBaseline * 0.96f + raw * 0.04f;
  float threshold = rt.pulseBaseline * 1.06f;

  if (!rt.pulseAbove && raw > threshold && now - rt.lastBeatMs > 300) {
    rt.pulseAbove = true;
    if (rt.lastBeatMs > 0) {
      uint32_t interval = now - rt.lastBeatMs;
      if (interval >= 300 && interval <= 1800) {
        rt.bpm = (uint16_t)(60000UL / interval);
      }
    }
    rt.lastBeatMs = now;
    applyLed(PIN_LED4, 255);
    tone(PIN_BUZZER, 1600, 40);
  }

  if (rt.pulseAbove && raw < rt.pulseBaseline) {
    rt.pulseAbove = false;
    applyLed(PIN_LED4, 0);
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
      startHeartMode();
      break;
    case 3:
      settings.monitoringEnabled = !settings.monitoringEnabled;
      saveSettings();
      if (settings.monitoringEnabled) {
        rt.lampNotificationFlash = true;
        rt.lampNotificationUntil = millis() + 2500;
      }
      break;
    case 4:
      showInfoPage();
      break;
    case 5:
      closeMenu();
      openSetupPortal(true);
      rt.faceMode = FACE_WIFI_SETUP;
      softConfirm();
      break;
    case 6:
      memset(&settings, 0, sizeof(settings));
      setDefaultSettings(settings);
      saveSettings();
      rt.welcomeActive = true;
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
  int percent = rt.batteryPercent;
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;

  char text[8];
  snprintf(text, sizeof(text), "%d%%", percent);
  u8g2.setFont(u8g2_font_4x6_tr);
  u8g2.drawStr(92, 8, text);

  int x = 110, y = 2, w = 14, h = 8;
  u8g2.drawFrame(x, y, w, h);
  u8g2.drawBox(x + w, y + 2, 2, 4);
  int fill = map(percent, 0, 100, 0, w - 4);
  if (fill > 0) u8g2.drawBox(x + 2, y + 2, fill, h - 4);
}

void drawFaceEyes(int cx, int cy, bool closed, int pupilX, int pupilY, bool happy) {
  int r = 8;
  if (closed) {
    u8g2.drawLine(cx - r, cy, cx + r, cy);
    return;
  }

  if (happy) {
    u8g2.drawArc(cx, cy + 2, r, 200, 340);
    u8g2.drawArc(cx, cy + 2, r - 1, 200, 340);
    return;
  }

  // Outer white circle
  u8g2.drawDisc(cx, cy, r);
  u8g2.setDrawColor(0);
  u8g2.drawDisc(cx, cy, r - 2);

  // Moving iris ring outline & black pupil
  u8g2.setDrawColor(1);
  u8g2.drawDisc(cx + pupilX, cy + pupilY, r - 3);
  u8g2.setDrawColor(0);
  u8g2.drawDisc(cx + pupilX, cy + pupilY, r - 5);

  u8g2.setDrawColor(1);
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
  u8g2.setFont(u8g2_font_6x10_tr);
  u8g2.drawStr(10, 14, settings.deviceName);
  u8g2.setFont(u8g2_font_ncenB08_tr);
  u8g2.drawStr(30, 34, timeBuf);
  u8g2.setFont(u8g2_font_5x7_tr);
  u8g2.drawStr(26, 48, dateBuf);
  u8g2.drawStr(12, 58, settings.userName);
  u8g2.sendBuffer();
}

void drawWelcomeScreen() {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawCentered(18, "Hello, I am", u8g2_font_6x10_tr);
  drawCentered(30, settings.deviceName, u8g2_font_ncenB08_tr);
  drawCentered(44, "Welcome, I am your GEM", u8g2_font_5x7_tr);
  drawCentered(56, "Use the app to bring me to life", u8g2_font_5x7_tr);
  u8g2.sendBuffer();
}

void drawMenuScreen() {
  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  u8g2.setFont(u8g2_font_6x10_tr);
  u8g2.drawStr(10, 12, "Gem Menu");
  drawBatteryBar();

  for (uint8_t i = 0; i < MENU_ITEM_COUNT; ++i) {
    int y = 22 + (i * 5);
    if (y > 58) break;
    if (i == rt.menuIndex) {
      u8g2.drawBox(6, y - 4, 116, 6);
      u8g2.setDrawColor(0);
    }
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(10, y, MENU_ITEMS[i]);
    u8g2.setDrawColor(1);
  }
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
  u8g2.drawStr(10, 24, "SSID: GEM-Setup");
  u8g2.drawStr(10, 34, "Pass: 12345678");
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
  bool night = isNightTime();
  bool evening = isEveningTime() || rt.ambientDark;
  bool closed = night || (rt.faceMode == FACE_PET && (millis() / 100) % 2 == 0);
  bool happy = rt.faceMode == FACE_PET || rt.faceMode == FACE_HEART || rt.faceMode == FACE_MENU;
  bool smile = true;

  int pupilX = rt.eyeOffsetX;
  int pupilY = rt.eyeOffsetY;

  if (night) {
    pupilX = 0;
    pupilY = 0;
  } else if (evening) {
    pupilY = 1;
  }

  if (rt.faceMode == FACE_ALARM) {
    closed = false;
    happy = false;
    smile = false;
    pupilX = 0;
    pupilY = -1;
  }

  u8g2.clearBuffer();
  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawBatteryBar();
  u8g2.setFont(u8g2_font_5x7_tr);
  u8g2.drawStr(8, 11, settings.userName);
  u8g2.drawStr(82, 11, settings.deviceName);

  // Draw circular eyes centered symmetrically
  drawFaceEyes(34, 28, closed, pupilX, pupilY, happy);
  drawFaceEyes(94, 28, closed, pupilX, pupilY, happy);

  drawMouth(64, 48, smile, rt.faceMode == FACE_PET);

  if (rt.faceMode == FACE_PET) {
    drawHearts();
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(22, 57, "I like your company");
  } else if (rt.faceMode == FACE_NIGHT) {
    drawZzz();
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(12, 57, "I am getting sleepy...");
  } else if (rt.faceMode == FACE_HEART) {
    u8g2.setFont(u8g2_font_6x10_tr);
    u8g2.drawStr(82, 32, "BPM");
    char bpmText[8];
    snprintf(bpmText, sizeof(bpmText), "%u", rt.bpm);
    u8g2.drawStr(90, 44, bpmText);
  } else if (rt.faceMode == FACE_ALARM) {
    u8g2.setFont(u8g2_font_5x7_tr);
    u8g2.drawStr(12, 57, settings.alarms[rt.alarmIndex].name);
  } else {
    u8g2.setFont(u8g2_font_5x7_tr);
    if (night) {
      u8g2.drawStr(12, 57, "Night sleep mode");
    } else if (evening) {
      u8g2.drawStr(12, 57, "Evening relax mode");
    } else {
      u8g2.drawStr(12, 57, "Day mode");
    }
  }

  if (settings.lampState) {
    u8g2.drawStr(94, 57, "Lamp");
  }

  u8g2.sendBuffer();
}

void renderScreen() {
  if (rt.welcomeActive) {
    drawWelcomeScreen();
    return;
  }

  if (rt.timeOverlayActive && millis() < rt.timeOverlayUntil) {
    drawTimeOverlay();
    return;
  }

  if (rt.menuOpen) {
    drawMenuScreen();
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

void updateFaceAnimation() {
  uint32_t now = millis();
  if (now - rt.lastFaceFrame < OLED_REFRESH_MS) return;
  rt.lastFaceFrame = now;

  if (rt.welcomeActive) {
    return;
  }

  uint32_t framePeriod = FACE_FRAME_MS_DAY;
  if (isNightTime()) {
    framePeriod = FACE_FRAME_MS_NIGHT;
    if (rt.faceMode != FACE_WIFI_SETUP) {
      rt.faceMode = FACE_NIGHT;
    }
  } else if (isEveningTime() || rt.ambientDark) {
    framePeriod = FACE_FRAME_MS_EVENING;
    if (rt.faceMode != FACE_PET && rt.faceMode != FACE_HEART && rt.faceMode != FACE_ALARM && !rt.menuOpen && rt.faceMode != FACE_WIFI_SETUP) {
      rt.faceMode = FACE_EVENING;
    }
  } else if (rt.faceMode != FACE_PET && rt.faceMode != FACE_HEART && rt.faceMode != FACE_ALARM && !rt.menuOpen && rt.faceMode != FACE_WIFI_SETUP) {
    rt.faceMode = FACE_DAY;
  }

  if (rt.petActive) {
    framePeriod = FACE_FRAME_MS_PET;
  }

  rt.facePhase = (rt.facePhase + 1) % 16;
  rt.blinkFrame = (rt.facePhase == 6 || rt.facePhase == 12);

  if (rt.facePhase < 4) {
    rt.eyeOffsetX = 0;
    rt.eyeOffsetY = 0;
  } else if (rt.facePhase < 7) {
    rt.eyeOffsetX = -2;
    rt.eyeOffsetY = 0;
  } else if (rt.facePhase < 10) {
    rt.eyeOffsetX = 2;
    rt.eyeOffsetY = 0;
  } else {
    rt.eyeOffsetX = 0;
    rt.eyeOffsetY = (rt.facePhase % 2 == 0) ? -1 : 1;
  }

  if (rt.petActive && now >= rt.petUntil) {
    rt.petActive = false;
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
    rt.welcomeActive = false;
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

  if (rt.touch.tapCount == 2) {
    openMenu();
    rt.touch.tapCount = 0;
    return;
  }

  if (rt.touch.tapCount == 3) {
    toggleLampMode();
    rt.touch.tapCount = 0;
    return;
  }
}

void handleTouchInput() {
  uint32_t now = millis();
  bool pressed = digitalRead(PIN_TOUCH) == HIGH;
  if (rt.faceMode == FACE_WIFI_SETUP) {
    if (pressed && !rt.touch.pressed) {
      rt.touch.pressed = true;
      rt.touch.pressedAt = now;
    }
    if (!pressed && rt.touch.pressed) {
      rt.touch.pressed = false;
      closeWiFiSetup();
    }
    return;
  }
  now = millis();

  if (pressed && !rt.touch.pressed) {
    rt.touch.pressed = true;
    rt.touch.pressedAt = now;
    rt.touch.longHandled = false;
    triggerCloudEvent("touch-down");
  }

  if (pressed && rt.touch.pressed && !rt.touch.longHandled && now - rt.touch.pressedAt >= LONG_TOUCH_MS) {
    rt.touch.longHandled = true;
    celebrateTouch();
    triggerCloudEvent("long-touch");
  }

  if (!pressed && rt.touch.pressed) {
    uint32_t heldMs = now - rt.touch.pressedAt;
    rt.touch.pressed = false;

    if (rt.touch.longHandled) {
      rt.petActive = true;
      rt.petUntil = now + 2500;
      rt.timeOverlayActive = false;
      return;
    }

    handleTouchReleaseTap(heldMs);
  }

  if (rt.touch.tapCount > 0 && now - rt.touch.lastTapAt > TAP_WINDOW_MS) {
    rt.touch.tapCount = 0;
  }

  if (rt.menuOpen && now > rt.menuUntil) {
    closeMenu();
  }
}

void openSetupPortal(bool initial, uint32_t durationMs) {
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP(initial ? "GEM-Setup" : "GEM-Config", GEM_HOTSPOT_PASSWORD);
  rt.menuUntil = millis() + durationMs;
}

void startHotspotPortal(bool allowStation, bool initialSetup) {
  WiFi.mode(allowStation ? WIFI_AP_STA : WIFI_AP);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP(initialSetup ? "GEM-Setup" : "GEM-Config", GEM_HOTSPOT_PASSWORD);
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
  json += "\"ip\":\"" + WiFi.localIP().toString() + "\"";
  json += ",\"alarms\":[";
  for (uint8_t i = 0; i < settings.alarmCount && i < 3; ++i) {
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
  html.reserve(2600);
  html += "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<meta charset='utf-8'><title>GEM</title>";
  html += "<style>";
  html += "body{margin:0;font-family:system-ui;background:linear-gradient(135deg,#09111f,#1b2a44);color:#eef3ff;padding:18px}";
  html += ".card{max-width:720px;margin:0 auto;background:rgba(255,255,255,.08);backdrop-filter:blur(16px);border:1px solid rgba(255,255,255,.16);border-radius:24px;padding:20px;box-shadow:0 24px 60px rgba(0,0,0,.35)}";
  html += "h1{margin:0 0 10px;font-size:28px}";
  html += ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}";
  html += ".tile{background:rgba(255,255,255,.08);padding:14px;border-radius:18px}";
  html += "label{display:block;font-size:12px;opacity:.8;margin-top:10px}";
  html += "input,select{width:100%;padding:10px;border-radius:12px;border:1px solid rgba(255,255,255,.18);background:#0f1726;color:#fff}";
  html += "button{margin-top:12px;padding:12px 16px;border:0;border-radius:999px;background:#79d8ff;color:#08202d;font-weight:700}";
  html += "a{color:#79d8ff}";
  html += "</style></head><body><div class='card'>";
  html += "<h1>GEM Setup</h1>";
  html += "<div class='grid'>";
  html += "<div class='tile'>Device: " + String(settings.deviceName) + "<br>User: " + String(settings.userName) + "<br>Battery: " + String(rt.batteryPercent) + "%</div>";
  html += "<div class='tile'>Wi-Fi: " + String(WiFi.status() == WL_CONNECTED ? "connected" : "offline") + "<br>Hotspot: " + String(settings.hotspotEnabled ? "enabled" : "off") + "</div>";
  html += "<div class='tile'>Time: " + String(validClock() ? "set" : "not set") + "<br>Local IP: " + WiFi.localIP().toString() + "</div>";
  html += "</div>";
  html += "<p>Use the app or this page to save the first setup, alarms, LED settings, time, and hotspot behavior.</p>";
  html += "<form method='post' action='/api/save'>";
  html += "<label>User name</label><input name='userName' value='" + String(settings.userName) + "'>";
  html += "<label>Device name</label><input name='deviceName' value='" + String(settings.deviceName) + "'>";
  html += "<label>Timezone label</label><input name='tzLabel' value='" + String(settings.timezoneLabel) + "'>";
  html += "<label>Timezone offset minutes</label><input name='tzOffset' value='" + String(settings.timezoneOffsetMinutes) + "'>";
  html += "<label>Wi-Fi SSID</label><input name='wifiSsid' value='" + String(settings.wifiSsid) + "'>";
  html += "<label>Wi-Fi password</label><input name='wifiPass' type='password' value='" + String(settings.wifiPass) + "'>";
  html += "<label><input type='checkbox' name='wifiEnabled' ";
  if (settings.wifiEnabled) html += "checked";
  html += "> Enable Wi-Fi</label>";
  html += "<label><input type='checkbox' name='hotspotEnabled' ";
  if (settings.hotspotEnabled) html += "checked";
  html += "> Keep hotspot active</label>";
  html += "<label><input type='checkbox' name='monitoringEnabled' ";
  if (settings.monitoringEnabled) html += "checked";
  html += "> Monitoring</label>";
  html += "<label>Webhook URL</label><input name='webhook' value='" + String(settings.cloudWebhook) + "'>";
  html += "<button type='submit'>Save Settings and Reboot</button></form>";
  html += "<p><a href='/api/state'>JSON state</a> | <a href='/api/factory-reset'>Factory reset</a></p>";
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

void applySettingsFromRequest() {
  if (server.hasArg("userName")) copyText(settings.userName, sizeof(settings.userName), server.arg("userName").c_str());
  if (server.hasArg("deviceName")) copyText(settings.deviceName, sizeof(settings.deviceName), server.arg("deviceName").c_str());
  if (server.hasArg("tzLabel")) copyText(settings.timezoneLabel, sizeof(settings.timezoneLabel), server.arg("tzLabel").c_str());
  if (server.hasArg("tzOffset")) settings.timezoneOffsetMinutes = server.arg("tzOffset").toInt();
  if (server.hasArg("wifiSsid")) copyText(settings.wifiSsid, sizeof(settings.wifiSsid), server.arg("wifiSsid").c_str());
  if (server.hasArg("wifiPass")) copyText(settings.wifiPass, sizeof(settings.wifiPass), server.arg("wifiPass").c_str());
  settings.wifiEnabled = server.hasArg("wifiEnabled");
  settings.hotspotEnabled = server.hasArg("hotspotEnabled");
  settings.monitoringEnabled = server.hasArg("monitoringEnabled");
  if (server.hasArg("webhook")) copyText(settings.cloudWebhook, sizeof(settings.cloudWebhook), server.arg("webhook").c_str());

  for (uint8_t i = 0; i < 3; ++i) {
    String base = "alarm" + String(i);
    String hourKey = base + "_hour";
    String minKey = base + "_minute";
    String nameKey = base + "_name";
    String enabledKey = base + "_enabled";
    if (server.hasArg(hourKey)) settings.alarms[i].hour = (uint8_t)server.arg(hourKey).toInt();
    if (server.hasArg(minKey)) settings.alarms[i].minute = (uint8_t)server.arg(minKey).toInt();
    if (server.hasArg(nameKey)) copyText(settings.alarms[i].name, sizeof(settings.alarms[i].name), server.arg(nameKey).c_str());
    settings.alarms[i].enabled = server.hasArg(enabledKey) ? argTrue(server.arg(enabledKey)) : settings.alarms[i].enabled;
  }

  if (server.hasArg("alarmCount")) {
    int count = server.arg("alarmCount").toInt();
    if (count < 0) count = 0;
    if (count > 3) count = 3;
    settings.alarmCount = (uint8_t)count;
  }

  if (server.hasArg("lampMode")) settings.lampMode = (uint8_t)server.arg("lampMode").toInt();
  if (server.hasArg("lampBrightness")) settings.lampBrightness = (uint8_t)server.arg("lampBrightness").toInt();
  if (server.hasArg("lampState")) settings.lampState = argTrue(server.arg("lampState"));
  if (server.hasArg("ledAutoOffMinutes")) settings.ledAutoOffMinutes = (uint8_t)server.arg("ledAutoOffMinutes").toInt();

  settings.setupComplete = true;
  saveSettings();
}

void handleSave() {
  applySettingsFromRequest();
  if (server.hasArg("epoch")) {
    setTimeFromArgs();
  }

  String response = "<html><body>Saved to flash. Rebooting... <a href='/'>Back</a></body></html>";
  server.send(200, "text/html", response);
  scheduleRestart();
}

void handleState() {
  server.send(200, "application/json", buildStateJson());
}

void handleTimeSet() {
  setTimeFromArgs();
  server.send(200, "application/json", "{\"ok\":true}");
}

void handleFactoryReset() {
  setDefaultSettings(settings);
  saveSettings();
  rt.welcomeActive = true;
  rt.welcomeUntil = millis() + BOOT_WELCOME_MS;
  server.send(200, "text/plain", "Factory reset done. Rebooting...");
  scheduleRestart();
}

void handleNotFound() {
  server.send(404, "text/plain", "GEM says not found");
}

void setupPins() {
  pinMode(PIN_TOUCH, INPUT);
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
  WiFi.mode(WIFI_OFF);

  const bool canConnectStation = settings.wifiEnabled && settings.wifiSsid[0] != '\0';
  const bool keepHotspot = settings.hotspotEnabled;

  if (keepHotspot) {
    startHotspotPortal(canConnectStation, false);
  }

  if (canConnectStation) {
    WiFi.mode(keepHotspot ? WIFI_AP_STA : WIFI_STA);
    WiFi.begin(settings.wifiSsid, settings.wifiPass);
    uint32_t start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 12000) {
      delay(250);
    }
    if (WiFi.status() != WL_CONNECTED && !keepHotspot) {
      WiFi.mode(WIFI_OFF);
    }
  } else {
    WiFi.mode(keepHotspot ? WIFI_AP : WIFI_OFF);
  }
}

void setupServer() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/state", HTTP_GET, handleState);
  server.on("/api/save", HTTP_ANY, handleSave);
  server.on("/api/time", HTTP_ANY, handleTimeSet);
  server.on("/api/factory-reset", HTTP_GET, handleFactoryReset);
  
  // OTA firmware update endpoint
  server.on("/api/update", HTTP_POST, []() {
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

void setup() {
  Serial.begin(115200);
  setupPins();
  u8g2.begin();

  loadSettings();
  bootScreen(!settings.setupComplete);
  if (!settings.setupComplete) {
    rt.welcomeUntil = millis() + BOOT_WELCOME_MS;
    rt.welcomeActive = true;
  } else {
    rt.welcomeUntil = 0;
    rt.welcomeActive = false;
  }

  refreshSensors(true);
  setupNetworking();
  setupServer();

  if (validClock()) {
    rt.welcomeActive = false;
  }

  renderScreen();
}

void loop() {
  server.handleClient();
  if (restartPending && (int32_t)(millis() - restartAtMs) >= 0) {
    delay(100);
    ESP.restart();
  }
  refreshSensors(false);
  handleTouchInput();
  updateWelcomeState();
  updateMenuTimeout();
  updateHeartMode();
  updateAlarmRuntime();
  checkAlarms();
  maybeWakeTimeDisplay();
  updateLampAutoOff();

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

  if (rt.welcomeActive && millis() >= rt.welcomeUntil) {
    rt.welcomeActive = false;
  }

  updateFaceAnimation();

  if (millis() - rt.lastOledUpdate >= OLED_REFRESH_MS) {
    rt.lastOledUpdate = millis();
    renderScreen();
  }
}
