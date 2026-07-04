#include <Arduino.h>
#include <U8g2lib.h>
#include "../GemBuddyConfig.h" // For PIN_OLED_SDA, PIN_OLED_SCL, and PIN_TOUCH

// Initialize the display using the requested U8g2 software I2C settings
// For SH1106 OLED screens (fixes the 2-pixel shift/glitch line on the left side)
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);
// For SSD1306 OLED screens (uncomment if using SSD1306)
// U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);

#include "eyes.h"

// ---------------- Scene State Machine ----------------
enum TestScene {
  SCENE_BOOT,
  SCENE_DEFAULT,
  SCENE_MENU,
  SCENE_SUBMENU_SETTINGS,
  SCENE_HEART_BEAT,
  SCENE_ACTION_CONFIRM
};

TestScene currentScene = SCENE_BOOT;
uint32_t sceneTimerMs = 0;          // Used for boot timer / transitions
uint32_t actionConfirmEndMs = 0;
char actionConfirmMsg[32] = "";
TestScene nextSceneAfterConfirm = SCENE_MENU;

// ---------------- State Variables ----------------
int xp = 16;        // Horizontal pupil position (0 to 32, 16 is center)
int mood = 0;       // Current eye expression mood (0 to 5)
int xd = 0;         // Jitter offset (-4 to 4)
bool autoMode = true;

uint32_t lastDrawMs = 0;
const uint32_t DRAW_INTERVAL_MS = 40; // ~25 fps

// Blink/Sleep state machine
bool isBlinking = false;
uint32_t nextBlinkMs = 0;
uint32_t blinkEndMs = 0;

// Auto mode cycle timers
uint32_t lastCycleMs = 0;
const uint32_t CYCLE_INTERVAL_MS = 2500;

// Time tracking variables
uint32_t lastTimeUpdateMs = 0;
int hours = 10;
int minutes = 8;
int seconds = 0;

void updateClock() {
  uint32_t now = millis();
  if (now - lastTimeUpdateMs >= 1000) {
    seconds += (now - lastTimeUpdateMs) / 1000;
    lastTimeUpdateMs = now - (now - lastTimeUpdateMs) % 1000;
    if (seconds >= 60) {
      minutes += seconds / 60;
      seconds %= 60;
      if (minutes >= 60) {
        hours += minutes / 60;
        minutes %= 60;
        if (hours >= 24) {
          hours %= 24;
        }
      }
    }
  }
}

// Greeting state variables
uint32_t lastGreetingTriggerMs = 0;
bool greetingActive = false;
uint32_t greetingEndMs = 0;
const uint32_t GREETING_INTERVAL_MS = 5000; // Trigger every 5 seconds
const uint32_t GREETING_DURATION_MS = 2000; // Stay for 2 seconds

void handleGreetings() {
  uint32_t now = millis();
  if (now - lastGreetingTriggerMs >= GREETING_INTERVAL_MS) {
    lastGreetingTriggerMs = now;
    greetingActive = true;
    greetingEndMs = now + GREETING_DURATION_MS;
  }
  if (greetingActive && now >= greetingEndMs) {
    greetingActive = false;
  }
}

// ---------------- Demo / Slideshow Mode ----------------
uint32_t lastSceneCycleMs = 0;
const uint32_t SCENE_CYCLE_INTERVAL_MS = 8000; // Cycle scenes every 8 seconds

uint32_t lastMenuCursorCycleMs = 0;
const uint32_t MENU_CURSOR_CYCLE_INTERVAL_MS = 2000; // Move menu highlight every 2 seconds

void resetSlideshowTimer() {
  lastSceneCycleMs = millis();
  lastMenuCursorCycleMs = millis();
}

// ---------------- Touch Sensor States ----------------
bool lastTouchState = false;
uint32_t touchPressTimeMs = 0;
bool longPressHandled = false;
const uint32_t LONG_PRESS_THRESHOLD_MS = 600;

// ---------------- Menu Data ----------------
const char* mainMenu[] = {
  "LED Control",
  "Heart Beat",
  "Settings",
  "Reminders",
  "Desk Lock",
  "About"
};
const int mainMenuCount = 6;
int mainMenuItemSelected = 0;

const char* settingsMenu[] = {
  "Alarms",
  "WiFi",
  "Reset",
  "< Back"
};
const int settingsMenuCount = 4;
int settingsMenuItemSelected = 0;

// ---------------- Heart Beat Data ----------------
int simBPM = 72;

// ---------------- Navigation Actions ----------------
void showConfirmation(const char* msg, TestScene returnScene) {
  strncpy(actionConfirmMsg, msg, sizeof(actionConfirmMsg) - 1);
  actionConfirmMsg[sizeof(actionConfirmMsg) - 1] = '\0';
  currentScene = SCENE_ACTION_CONFIRM;
  actionConfirmEndMs = millis() + 1500;
  nextSceneAfterConfirm = returnScene;
  resetSlideshowTimer();
}

void handleShortTap() {
  resetSlideshowTimer();
  switch (currentScene) {
    case SCENE_BOOT:
      currentScene = SCENE_DEFAULT;
      break;
      
    case SCENE_DEFAULT:
      currentScene = SCENE_MENU;
      break;
      
    case SCENE_MENU:
      mainMenuItemSelected = (mainMenuItemSelected + 1) % mainMenuCount;
      break;
      
    case SCENE_SUBMENU_SETTINGS:
      settingsMenuItemSelected = (settingsMenuItemSelected + 1) % settingsMenuCount;
      break;
      
    case SCENE_HEART_BEAT:
      // Cycle simulated heart rates
      if (simBPM == 72) simBPM = 85;
      else if (simBPM == 85) simBPM = 60;
      else if (simBPM == 60) simBPM = 110;
      else simBPM = 72;
      Serial.print(F("BPM Changed to: ")); Serial.println(simBPM);
      break;
      
    case SCENE_ACTION_CONFIRM:
      currentScene = nextSceneAfterConfirm;
      break;
  }
}

void handleLongPress() {
  resetSlideshowTimer();
  switch (currentScene) {
    case SCENE_BOOT:
      currentScene = SCENE_DEFAULT;
      break;
      
    case SCENE_DEFAULT:
      currentScene = SCENE_MENU;
      break;
      
    case SCENE_MENU:
      if (mainMenuItemSelected == 0) {
        showConfirmation("LED Mode Toggled", SCENE_MENU);
      } else if (mainMenuItemSelected == 1) {
        currentScene = SCENE_HEART_BEAT;
      } else if (mainMenuItemSelected == 2) {
        currentScene = SCENE_SUBMENU_SETTINGS;
        settingsMenuItemSelected = 0;
      } else if (mainMenuItemSelected == 3) {
        showConfirmation("Reminders: Active", SCENE_MENU);
      } else if (mainMenuItemSelected == 4) {
        showConfirmation("Desk Lock Active", SCENE_MENU);
      } else if (mainMenuItemSelected == 5) {
        showConfirmation("GEM Lar-1 v1.0", SCENE_MENU);
      }
      break;
      
    case SCENE_SUBMENU_SETTINGS:
      if (settingsMenuItemSelected == 0) {
        showConfirmation("Alarms: Enabled", SCENE_SUBMENU_SETTINGS);
      } else if (settingsMenuItemSelected == 1) {
        showConfirmation("WiFi: Config AP", SCENE_SUBMENU_SETTINGS);
      } else if (settingsMenuItemSelected == 2) {
        showConfirmation("Device Reset...", SCENE_BOOT);
        sceneTimerMs = millis() + 3000;
      } else if (settingsMenuItemSelected == 3) {
        currentScene = SCENE_MENU;
      }
      break;
      
    case SCENE_HEART_BEAT:
      currentScene = SCENE_MENU;
      break;
      
    case SCENE_ACTION_CONFIRM:
      currentScene = nextSceneAfterConfirm;
      break;
  }
}

void updateTouch() {
  bool touched = (digitalRead(PIN_TOUCH) == HIGH);
  uint32_t now = millis();
  
  if (touched && !lastTouchState) {
    lastTouchState = true;
    touchPressTimeMs = now;
    longPressHandled = false;
  }
  
  if (!touched && lastTouchState) {
    lastTouchState = false;
    if (!longPressHandled && (now - touchPressTimeMs < LONG_PRESS_THRESHOLD_MS)) {
      handleShortTap();
    }
  }
  
  if (touched && lastTouchState && !longPressHandled && (now - touchPressTimeMs >= LONG_PRESS_THRESHOLD_MS)) {
    longPressHandled = true;
    handleLongPress();
  }
}

void runSlideshow() {
  uint32_t now = millis();
  
  // 1. Cycle scenes automatically every 8 seconds
  if (now - lastSceneCycleMs >= SCENE_CYCLE_INTERVAL_MS) {
    lastSceneCycleMs = now;
    
    if (currentScene == SCENE_BOOT) {
      currentScene = SCENE_DEFAULT;
    } else if (currentScene == SCENE_DEFAULT) {
      currentScene = SCENE_MENU;
      mainMenuItemSelected = 0;
    } else if (currentScene == SCENE_MENU) {
      currentScene = SCENE_SUBMENU_SETTINGS;
      settingsMenuItemSelected = 0;
    } else if (currentScene == SCENE_SUBMENU_SETTINGS) {
      currentScene = SCENE_HEART_BEAT;
    } else if (currentScene == SCENE_HEART_BEAT) {
      currentScene = SCENE_BOOT;
      sceneTimerMs = now + 3000; // Boot screen timer
    }
    
    Serial.print(F("Auto Slideshow -> Switched Scene: "));
    Serial.println((int)currentScene);
  }

  // 2. Cycle menu selections automatically every 2 seconds
  if (now - lastMenuCursorCycleMs >= MENU_CURSOR_CYCLE_INTERVAL_MS) {
    lastMenuCursorCycleMs = now;
    
    if (currentScene == SCENE_MENU) {
      mainMenuItemSelected = (mainMenuItemSelected + 1) % mainMenuCount;
    } else if (currentScene == SCENE_SUBMENU_SETTINGS) {
      settingsMenuItemSelected = (settingsMenuItemSelected + 1) % settingsMenuCount;
    }
  }
}

// ---------------- Helpers ----------------
const char* getMoodName(int m) {
  switch (m) {
    case 0: return "Normal/Neutral";
    case 1: return "Happy/Curved";
    case 2: return "Closed/Sleeping";
    case 3: return "Angry/Focused";
    case 4: return "Sad/Tired";
    case 5: return "Suspicious/Wide";
    default: return "Unknown";
  }
}

void printHelp() {
  Serial.println(F("\n====== PICAIO ROBOT EYES & MENU TEST Suite (U8G2) ======"));
  Serial.println(F("Controls via Serial Monitor (115200 baud):"));
  Serial.println(F("  't'       -> Simulate Touch Short Tap (navigates items / cycles scenes)"));
  Serial.println(F("  'k'       -> Simulate Touch Long Press (selects/enters options)"));
  Serial.println(F("  'a'       -> Toggle Auto-Cycle Gaze (on default face screen)"));
  Serial.println(F("  'm'       -> Cycle eye moods (0-5)"));
  Serial.println(F("  '0'..'5'  -> Set eye mood directly"));
  Serial.println(F("  'l'       -> Look Left  (decreases pupil position)"));
  Serial.println(F("  'r'       -> Look Right (increases pupil position)"));
  Serial.println(F("  'c'       -> Center pupils (xp = 16)"));
  Serial.println(F("  '?'       -> Print this menu"));
  Serial.println(F("========================================================="));
}

void printCodeExport() {
  Serial.println(F("\n--- Gaze State Export ---"));
  int pos = (xp < 6) ? 1 : ((xp < 26) ? 0 : 2);
  Serial.print(F("// Eye Mood: ")); Serial.println(getMoodName(mood));
  Serial.print(F("// Direction xp: ")); Serial.println(xp);
  Serial.println(F("-------------------------"));
}

void handleBlinks() {
  uint32_t now = millis();
  if (isBlinking) {
    if (now >= blinkEndMs) {
      isBlinking = false;
      nextBlinkMs = now + random(2500, 7000);
    }
  } else {
    if (now >= nextBlinkMs && mood != 2) {
      isBlinking = true;
      blinkEndMs = now + random(100, 200);
    }
  }
}

void updateAutoCycle() {
  if (!autoMode) return;

  uint32_t now = millis();
  if (now - lastCycleMs >= CYCLE_INTERVAL_MS) {
    lastCycleMs = now;
    mood = (mood + 1) % 6;
    
    int randDir = random(0, 3);
    if (randDir == 0) xp = 2;
    else if (randDir == 1) xp = 16;
    else xp = 30;
  }
}

void handleSerialCommand() {
  if (!Serial.available()) return;

  char c = Serial.read();
  if (c == '\r' || c == '\n' || c == ' ') return;

  switch (c) {
    case '?':
      printHelp();
      break;

    case 't':
      Serial.println(F("Serial Command -> Simulating Touch Tap"));
      handleShortTap();
      break;

    case 'k':
      Serial.println(F("Serial Command -> Simulating Touch Long Press"));
      handleLongPress();
      break;

    case 'a':
      autoMode = !autoMode;
      Serial.print(F("Auto-Cycle Gaze: "));
      Serial.println(autoMode ? F("ON") : F("OFF"));
      break;

    case 'm':
      autoMode = false;
      mood = (mood + 1) % 6;
      Serial.print(F("Mood changed to: "));
      Serial.println(getMoodName(mood));
      printCodeExport();
      break;

    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
      autoMode = false;
      mood = c - '0';
      Serial.print(F("Mood set to: "));
      Serial.println(getMoodName(mood));
      printCodeExport();
      break;

    case 'l':
      autoMode = false;
      xp = (xp <= 4) ? 0 : xp - 6;
      Serial.print(F("Look Left -> xp: "));
      Serial.println(xp);
      printCodeExport();
      break;

    case 'r':
      autoMode = false;
      xp = (xp >= 28) ? 32 : xp + 6;
      Serial.print(F("Look Right -> xp: "));
      Serial.println(xp);
      printCodeExport();
      break;

    case 'c':
      autoMode = false;
      xp = 16;
      Serial.println(F("Pupils centered"));
      printCodeExport();
      break;

    default:
      Serial.print(F("Unknown command: "));
      Serial.println(c);
      break;
  }
}

// ---------------- Setup and Loop ----------------
void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println(F("Booting Picaio Robot Test Suite (SH1106)..."));

  pinMode(PIN_TOUCH, INPUT);

  u8g2.begin();
  u8g2.setPowerSave(0);

  nextBlinkMs = millis() + 3000;
  lastCycleMs = millis();
  sceneTimerMs = millis() + 3000; // 3 seconds on boot screen
  lastSceneCycleMs = millis();
  lastMenuCursorCycleMs = millis();

  printHelp();
}

void loop() {
  handleSerialCommand();
  updateTouch();
  handleBlinks();
  updateAutoCycle();
  handleGreetings();
  runSlideshow();

  uint32_t now = millis();
  if (now - lastDrawMs >= DRAW_INTERVAL_MS) {
    lastDrawMs = now;

    // Jitter pupil drift slightly to make it organic (Picaio's loop logic)
    int n = random(0, 10);
    if (n < 4) xd--;
    if (n > 6) xd++;
    if (xd < -4) xd = -3;
    if (xd > 4) xd = 3;

    u8g2.clearBuffer();

    if (currentScene == SCENE_BOOT) {
      // Boot screen: Hello, I am GEM, your smart buddy
      u8g2.drawRFrame(2, 2, 124, 60, 8);
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr(12, 20, "Hello,");
      u8g2.setFont(u8g2_font_7x14_tf);
      u8g2.drawStr(12, 36, "I am GEM,");
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr(12, 50, "your smart buddy");
      
      // Auto transition after timer
      if (millis() > sceneTimerMs) {
        currentScene = SCENE_DEFAULT;
        resetSlideshowTimer();
      }
    }
    else if (currentScene == SCENE_DEFAULT) {
      // Default screen: Center eyes (bigger), small time top-left, status icons, speech bubble every 5s
      
      // Move eyes to the center horizontally, drawn at y = 12
      int base_x1 = 16;
      int base_x2 = 80;
      int shift = (xp - 16) / 4; // Scale pupil movement to +/- 4 pixels
      int x1 = base_x1 + xd + shift;
      int x2 = base_x2 + xd + shift;

      // Clamp coordinates to prevent side wrap-around glitches
      if (x1 < 0) x1 = 0;
      if (x1 > 48) x1 = 48;
      if (x2 < 48) x2 = 48;
      if (x2 > 96) x2 = 96;

      // Draw the eyes centered (y = 12)
      if (isBlinking) {
        u8g2.drawBitmap(x1, 12, 4, 32, eye0);
        u8g2.drawBitmap(x2, 12, 4, 32, eye0);
      } else {
        if (xp < 6) {
          u8g2.drawBitmap(x1, 12, 4, 32, peyes[mood][1][0]);
          u8g2.drawBitmap(x2, 12, 4, 32, peyes[mood][1][1]);
        } else if (xp < 26) {
          u8g2.drawBitmap(x1, 12, 4, 32, peyes[mood][0][0]);
          u8g2.drawBitmap(x2, 12, 4, 32, peyes[mood][0][1]);
        } else {
          u8g2.drawBitmap(x1, 12, 4, 32, peyes[mood][2][0]);
          u8g2.drawBitmap(x2, 12, 4, 32, peyes[mood][2][1]);
        }
      }

      // Small clock on top-left
      updateClock();
      char timeStr[10];
      snprintf(timeStr, sizeof(timeStr), "%02d:%02d IST", hours, minutes);
      u8g2.setFont(u8g2_font_4x6_tr); // Very small, clean font
      u8g2.drawStr(4, 8, timeStr);

      // Draw WiFi symbol on the right corner (at x = 114, y = 7)
      u8g2.drawDisc(114, 8, 1);
      u8g2.drawCircle(114, 8, 3, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);
      u8g2.drawCircle(114, 8, 5, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);

      // Draw Lock symbol next to WiFi (at x = 120, y = 2)
      u8g2.drawBox(120, 5, 5, 4);
      u8g2.drawCircle(122, 5, 2, U8G2_DRAW_UPPER_RIGHT | U8G2_DRAW_UPPER_LEFT);

      // Greeting speech bubble at the bottom - only shown when greeting is active
      if (greetingActive) {
        u8g2.drawRFrame(2, 46, 124, 18, 3);
        u8g2.setFont(u8g2_font_5x7_tr);
        // Draw speech bubble tip pointing up to the left eye
        u8g2.drawTriangle(30, 46, 34, 42, 38, 46);
        u8g2.setDrawColor(0);
        u8g2.drawLine(31, 46, 37, 46);
        u8g2.setDrawColor(1);
        
        u8g2.drawStr(8, 57, "What's up, Shovin!");
      }
    }
    else if (currentScene == SCENE_MENU) {
      // Main menu: Carousel-style
      // Center header
      u8g2.setFont(u8g2_font_6x10_tf);
      int16_t headerW = u8g2.getStrWidth("GEM Menu");
      u8g2.drawStr((128 - headerW) / 2, 11, "GEM Menu");
      u8g2.drawLine(2, 14, 126, 14);

      // Draw rounded card frame in the center
      u8g2.drawRFrame(16, 24, 96, 24, 4);

      // Center the active menu item text inside the card
      u8g2.setFont(u8g2_font_7x14_tf); // Slightly larger font for the active menu item
      const char* activeItemText = mainMenu[mainMenuItemSelected];
      int16_t itemW = u8g2.getStrWidth(activeItemText);
      u8g2.drawStr((128 - itemW) / 2, 40, activeItemText);

      // Draw left and right pointing arrows next to the card
      // Left arrow: <
      u8g2.drawTriangle(6, 36, 10, 32, 10, 40);
      // Right arrow: >
      u8g2.drawTriangle(122, 36, 118, 32, 118, 40);
    }
    else if (currentScene == SCENE_SUBMENU_SETTINGS) {
      // Settings sub-menu: Carousel-style
      // Center header
      u8g2.setFont(u8g2_font_6x10_tf);
      int16_t headerW = u8g2.getStrWidth("Settings");
      u8g2.drawStr((128 - headerW) / 2, 11, "Settings");
      u8g2.drawLine(2, 14, 126, 14);

      // Draw rounded card frame in the center
      u8g2.drawRFrame(16, 24, 96, 24, 4);

      // Center the active settings item text inside the card
      u8g2.setFont(u8g2_font_7x14_tf);
      const char* activeItemText = settingsMenu[settingsMenuItemSelected];
      int16_t itemW = u8g2.getStrWidth(activeItemText);
      u8g2.drawStr((128 - itemW) / 2, 40, activeItemText);

      // Draw left and right pointing arrows next to the card
      // Left arrow
      u8g2.drawTriangle(6, 36, 10, 32, 10, 40);
      // Right arrow
      u8g2.drawTriangle(122, 36, 118, 32, 118, 40);
    }
    else if (currentScene == SCENE_HEART_BEAT) {
      // Heart beat screen: Beating heart animation
      u8g2.drawRFrame(2, 2, 124, 60, 6);
      
      // Pulse scale calculation (thump-thump heartbeat)
      int t = millis() % 800;
      float scale = 1.0;
      if (t < 150) scale = 1.4;
      else if (t >= 200 && t < 350) scale = 1.25;

      // Draw beating heart in the center of the left side
      int cx = 40;
      int cy = 26;
      int r = 5 * scale;
      int ox = 5 * scale;
      int oy = 12 * scale;
      u8g2.drawDisc(cx - ox, cy, r);
      u8g2.drawDisc(cx + ox, cy, r);
      u8g2.drawTriangle(cx - ox - r, cy, cx + ox + r, cy, cx, cy + oy);

      // Text readouts
      u8g2.setFont(u8g2_font_7x14_tf);
      char bpmText[16];
      snprintf(bpmText, sizeof(bpmText), "%d BPM", simBPM);
      u8g2.drawStr(74, 30, bpmText);
      
      u8g2.setFont(u8g2_font_4x6_tr);
      u8g2.drawStr(74, 42, "Pulse Check");
      
      u8g2.drawFrame(2, 48, 124, 14);
      u8g2.setFont(u8g2_font_5x7_tr);
      u8g2.drawStr(8, 58, "Hold touch to exit");
    }
    else if (currentScene == SCENE_ACTION_CONFIRM) {
      // Temporary confirmation overlay
      u8g2.drawRFrame(8, 14, 112, 36, 4);
      u8g2.setFont(u8g2_font_6x10_tf);
      
      // Center the message text
      int16_t w = u8g2.getStrWidth(actionConfirmMsg);
      u8g2.drawStr((128 - w) / 2, 36, actionConfirmMsg);

      if (millis() > actionConfirmEndMs) {
        currentScene = nextSceneAfterConfirm;
        resetSlideshowTimer();
      }
    }

    u8g2.sendBuffer();
  }
}
