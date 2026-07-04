#include <Arduino.h>
#include <U8g2lib.h>
#include "../GemBuddyConfig.h" // For pin definitions

// Initialize SH1106 OLED
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);

// Override touch pin to Pin 18 for this hardware configuration
#define PIN_TOUCH_TEST 18

// Heartbeat detection states
float pulseBaseline = 0.0f;
bool pulseAbove = false;
uint32_t lastBeatMs = 0;
uint16_t calculatedBpm = 0;

// Session control states
bool sessionRunning = false;
bool sessionFinished = false;
uint32_t sessionStartTimeMs = 0;
const uint32_t SESSION_DURATION_MS = 20000; // 20 seconds

// Debounce touch states
bool lastTouchState = false;
bool debouncedState = false;
uint32_t lastDebounceTime = 0;
const uint32_t DEBOUNCE_DELAY_MS = 50;

// LED Pulse Fading State
int ledBrightness = 0;

// Hardware test states (read every 500ms)
uint32_t lastHwReadMs = 0;
uint16_t ldrRaw = 0;

// Hysteresis threshold definitions
const int THRESHOLD_VAL = 1900;
bool beatDetected = false;

// Helper: Average analog readings to prevent jitter
uint16_t readAnalogAverage(uint8_t pin, uint8_t samples) {
  uint32_t total = 0;
  for (uint8_t i = 0; i < samples; ++i) {
    total += analogReadMilliVolts(pin);
    delay(2);
  }
  return (uint16_t)(total / samples);
}


// Returns true once when touch pin is pressed
bool checkTouchTrigger() {
  bool currentReading = (digitalRead(PIN_TOUCH_TEST) == HIGH);
  bool triggered = false;
  
  if (currentReading != lastTouchState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY_MS) {
    if (currentReading != debouncedState) {
      debouncedState = currentReading;
      if (debouncedState == true) {
        triggered = true; // Press event
      }
    }
  }
  
  lastTouchState = currentReading;
  return triggered;
}

void startSession() {
  sessionRunning = true;
  sessionFinished = false;
  sessionStartTimeMs = millis();
  
  // Power ON the Pulse Sensor
  digitalWrite(PIN_PULSE_POWER, HIGH);
  
  // Reset calculation states
  beatDetected = false;
  pulseAbove = false;
  lastBeatMs = 0;
  calculatedBpm = 0;
  ledBrightness = 0;
  
  // Double-beep to indicate start
  tone(PIN_BUZZER, 1000, 100);
  delay(120);
  tone(PIN_BUZZER, 1500, 150);
  
  Serial.println(F("\n>>> 20-Second Heart Rate Measurement Started... <<<"));
}

void stopSession(bool completed) {
  sessionRunning = false;
  
  // Power OFF the Pulse Sensor
  digitalWrite(PIN_PULSE_POWER, LOW);
  
  // Turn OFF all LEDs
  analogWrite(PIN_LED1, 0);
  analogWrite(PIN_LED2, 0);
  analogWrite(PIN_LED3, 0);
  analogWrite(PIN_LED4, 0);
  ledBrightness = 0;

  if (completed) {
    sessionFinished = true;
    
    // Complete chime
    tone(PIN_BUZZER, 1200, 150);
    delay(200);
    tone(PIN_BUZZER, 1200, 300);
    
    Serial.println(F(">>> Measurement Complete! <<<"));
    Serial.print(F("Final Heart Rate: "));
    Serial.print(calculatedBpm);
    Serial.println(F(" BPM"));
  } else {
    sessionFinished = false;
    
    // Cancel tone
    tone(PIN_BUZZER, 600, 250);
    Serial.println(F(">>> Measurement Canceled. <<<"));
  }
}

void handleTrigger() {
  if (sessionRunning) {
    stopSession(false); // Cancel session
  } else {
    startSession(); // Start session
  }
}

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println(F("\n====== GemBuddy Hardware Test & Diagnostic ======"));

  // Initialize pins
  pinMode(PIN_TOUCH_TEST, INPUT_PULLDOWN);
  pinMode(PIN_PULSE_POWER, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LDR_ADC, INPUT);
  pinMode(PIN_PULSE_ADC, INPUT);
  
  pinMode(PIN_LED1, OUTPUT);
  pinMode(PIN_LED2, OUTPUT);
  pinMode(PIN_LED3, OUTPUT);
  pinMode(PIN_LED4, OUTPUT);
  
  // Set ADC Attenuation to 11dB (allows 0-3.3V range)
  analogSetPinAttenuation(PIN_LDR_ADC, ADC_11db);
  analogSetPinAttenuation(PIN_PULSE_ADC, ADC_11db);

  // Initialize display
  u8g2.begin();
  u8g2.setPowerSave(0);
  
  // --- LED SEQUENCE TEST ---
  Serial.println(F("Testing LEDs in sequence..."));
  analogWrite(PIN_LED1, 100); delay(150); analogWrite(PIN_LED1, 0);
  analogWrite(PIN_LED2, 100); delay(150); analogWrite(PIN_LED2, 0);
  analogWrite(PIN_LED3, 100); delay(150); analogWrite(PIN_LED3, 0);
  analogWrite(PIN_LED4, 100); delay(150); analogWrite(PIN_LED4, 0);
  
  // --- BUZZER TEST ---
  Serial.println(F("Testing Buzzer..."));
  tone(PIN_BUZZER, 2000, 80);
  
  // Read initial HW levels
  ldrRaw = readAnalogAverage(PIN_LDR_ADC, 4);

  Serial.println(F("OLED Initialized."));
  Serial.println(F("Controls:"));
  Serial.println(F("  - Touch Pin 18 to start/stop the 20-second pulse test"));
  Serial.println(F("  - Type 'on' or 't' to start/toggle via Serial"));
  Serial.println(F("  - Type 'off' to stop via Serial"));
}

int loopCount = 0;
static String serialBuffer = "";

void loop() {
  // Check for serial commands
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r' || c == '\n') {
      serialBuffer.trim();
      serialBuffer.toLowerCase();
      
      if (serialBuffer == "on") {
        if (!sessionRunning) {
          startSession();
        } else {
          Serial.println(F("Session is already running."));
        }
      } else if (serialBuffer == "off") {
        if (sessionRunning) {
          stopSession(false);
        } else {
          Serial.println(F("No active session to stop."));
        }
      } else if (serialBuffer == "t") {
        handleTrigger();
      } else if (serialBuffer == "b") {
        tone(PIN_BUZZER, 1000, 200); // Beep command
      }
      serialBuffer = ""; // Reset buffer
    } else {
      if (c >= 32 && c <= 126) {
        serialBuffer += c;
      }
    }
  }

  // Check for physical touch trigger on Pin 18
  if (checkTouchTrigger()) {
    handleTrigger();
  }

  uint32_t nowMs = millis();

  // Periodic sensor reader (every 500ms when not running active high-frequency pulse test)
  if (!sessionRunning && (nowMs - lastHwReadMs >= 500)) {
    lastHwReadMs = nowMs;
    ldrRaw = readAnalogAverage(PIN_LDR_ADC, 4);
    
    // Map LDR to LED brightness (Standby Interactive Feedback)
    // Darker room (low raw value) -> brighter LEDs
    int ledVal = map(ldrRaw, 0, 4095, 255, 0);
    if (ledVal < 0) ledVal = 0;
    if (ledVal > 255) ledVal = 255;
    
    analogWrite(PIN_LED1, ledVal);
    analogWrite(PIN_LED2, ledVal);
    analogWrite(PIN_LED3, ledVal);
    analogWrite(PIN_LED4, ledVal);
  }

  // If session is running, process sensor readings and timer
  if (sessionRunning) {
    if (nowMs - sessionStartTimeMs >= SESSION_DURATION_MS) {
      stopSession(true); // Completed!
    } else {
      int rawVal = analogRead(PIN_PULSE_ADC);
      uint32_t elapsedMs = nowMs - sessionStartTimeMs;

      if (elapsedMs < 2000) {
        // --- 1. CALIBRATION PHASE (First 2 Seconds) ---
        if (pulseBaseline <= 1.0f) {
          pulseBaseline = rawVal;
        }
        pulseBaseline = pulseBaseline * 0.90f + rawVal * 0.10f;
        beatDetected = false;
        pulseAbove = false;
      } 
      else {
        // --- 2. MEASUREMENT PHASE (After 2 Seconds) ---
        pulseBaseline = pulseBaseline * 0.98f + rawVal * 0.02f;
        float threshold = pulseBaseline + 25.0f;

        // Trigger beat on rising edge above threshold (with 300ms lockout)
        if (rawVal > threshold && !beatDetected && (nowMs - lastBeatMs > 300)) {
          beatDetected = true;
          pulseAbove = true; // Animate screen heart

          if (lastBeatMs > 0) {
            uint32_t interval = nowMs - lastBeatMs;
            uint32_t localBpm = 60000UL / interval;

            if (localBpm >= 40 && localBpm <= 180) {
              calculatedBpm = localBpm;
              
              // Beep on beat detection
              tone(PIN_BUZZER, 1200, 35);
              
              Serial.print(F("❤️ Beat Detected | BPM: "));
              Serial.println(calculatedBpm);
            }
          }
          lastBeatMs = nowMs;
          ledBrightness = 255;
        }

        // Reset trigger after signal falls below baseline
        if (rawVal < pulseBaseline) {
          beatDetected = false;
          pulseAbove = false;
        }
      }

      // Print raw value, baseline, and BPM for plotting
      Serial.print(rawVal);
      Serial.print(F(","));
      Serial.print((int)pulseBaseline);
      Serial.print(F(","));
      Serial.println(calculatedBpm);
    }
  }

  // Handle smooth LED fading (during pulse test)
  if (sessionRunning) {
    if (ledBrightness > 0) {
      ledBrightness = (ledBrightness * 85) / 100;
      if (ledBrightness < 5) ledBrightness = 0;
    }
    analogWrite(PIN_LED1, ledBrightness);
    analogWrite(PIN_LED2, ledBrightness);
    analogWrite(PIN_LED3, ledBrightness);
    analogWrite(PIN_LED4, ledBrightness);
  }

  // Update OLED at 10Hz (~100ms)
  loopCount++;
  if (loopCount >= 20) {
    loopCount = 0;
    u8g2.clearBuffer();

    if (sessionRunning) {
      // --- MEASURING SCREEN ---
      u8g2.drawRFrame(2, 2, 124, 60, 8);
      int elapsedMs = nowMs - sessionStartTimeMs;

      if (elapsedMs < 2000) {
        u8g2.setFont(u8g2_font_6x10_tf);
        u8g2.drawStr((128 - u8g2.getStrWidth("CALIBRATING...")) / 2, 22, "CALIBRATING...");
        
        u8g2.setFont(u8g2_font_5x7_tr);
        u8g2.drawStr((128 - u8g2.getStrWidth("Place finger & hold steady")) / 2, 38, "Place finger & hold steady");
        u8g2.drawStr((128 - u8g2.getStrWidth("Analyzing signal...")) / 2, 48, "Analyzing signal...");
      } else {
        u8g2.setFont(u8g2_font_6x10_tf);
        u8g2.drawStr((128 - u8g2.getStrWidth("MEASURING...")) / 2, 16, "MEASURING...");

        int secondsLeft = (SESSION_DURATION_MS - elapsedMs) / 1000;
        if (secondsLeft < 0) secondsLeft = 0;
        
        char timeStr[16];
        snprintf(timeStr, sizeof(timeStr), "Time Left: %ds", secondsLeft);
        u8g2.setFont(u8g2_font_5x7_tr);
        u8g2.drawStr((128 - u8g2.getStrWidth(timeStr)) / 2, 28, timeStr);

        char bpmStr[32];
        if (calculatedBpm > 0 && (nowMs - lastBeatMs < 3000)) {
          snprintf(bpmStr, sizeof(bpmStr), "%d BPM", calculatedBpm);
        } else {
          snprintf(bpmStr, sizeof(bpmStr), "-- BPM");
        }
        u8g2.setFont(u8g2_font_7x14_tf);
        int16_t bpmW = u8g2.getStrWidth(bpmStr);
        int textX = (128 - bpmW - 14) / 2;
        u8g2.drawStr(textX, 48, bpmStr);

        int cx = textX + bpmW + 10;
        int cy = 40;
        if (pulseAbove || ledBrightness > 120) {
          u8g2.drawDisc(cx - 3, cy, 3);
          u8g2.drawDisc(cx + 3, cy, 3);
          u8g2.drawTriangle(cx - 6, cy, cx + 6, cy, cx, cy + 7);
        } else {
          u8g2.drawDisc(cx - 2, cy, 2);
          u8g2.drawDisc(cx + 2, cy, 2);
          u8g2.drawTriangle(cx - 4, cy, cx + 4, cy, cx, cy + 5);
        }
      }
    } 
    else if (sessionFinished) {
      // --- COMPLETED RESULT SCREEN ---
      u8g2.drawRFrame(2, 2, 124, 60, 8);

      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr((128 - u8g2.getStrWidth("TEST COMPLETE")) / 2, 16, "TEST COMPLETE");

      u8g2.setFont(u8g2_font_5x7_tr);
      u8g2.drawStr((128 - u8g2.getStrWidth("Your Heart Rate:")) / 2, 28, "Your Heart Rate:");

      char finalStr[16];
      snprintf(finalStr, sizeof(finalStr), "%d BPM", calculatedBpm);
      u8g2.setFont(u8g2_font_7x14_tf);
      u8g2.drawStr((128 - u8g2.getStrWidth(finalStr)) / 2, 44, finalStr);

      u8g2.setFont(u8g2_font_5x7_tr);
      u8g2.drawStr((128 - u8g2.getStrWidth("Touch to Restart")) / 2, 56, "Touch to Restart");
    } 
    else {
      // --- STANDBY DASHBOARD (TESTS ALL SENSORS AT ONCE) ---
      u8g2.drawRFrame(2, 2, 124, 60, 8);

      // Title
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr((128 - u8g2.getStrWidth("GEM HARDWARE DIAG")) / 2, 14, "GEM HARDWARE DIAG");

      // Line Separator
      u8g2.drawHLine(6, 17, 116);

      // Raw Real-time readings
      u8g2.setFont(u8g2_font_5x7_tr);

      // 1. Touch pin state
      char touchStr[16];
      snprintf(touchStr, sizeof(touchStr), "Touch T18: %s", (digitalRead(PIN_TOUCH_TEST) == HIGH) ? "YES" : "NO");
      u8g2.drawStr(8, 28, touchStr);

      // 2. LDR reading
      char ldrStr[24];
      snprintf(ldrStr, sizeof(ldrStr), "LDR Level: %d", ldrRaw);
      u8g2.drawStr(8, 40, ldrStr);

      // Instruct to start test
      u8g2.drawStr((128 - u8g2.getStrWidth("Tap T18 to start Pulse")) / 2, 54, "Tap T18 to start Pulse");
    }

    u8g2.sendBuffer();
  }

  // Sample loop execution at 200Hz (5ms interval)
  delay(5);
}
