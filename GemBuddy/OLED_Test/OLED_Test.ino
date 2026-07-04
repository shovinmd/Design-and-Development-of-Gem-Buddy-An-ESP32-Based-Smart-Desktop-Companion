#include <Arduino.h>
#include <U8g2lib.h>
#include "../GemBuddyConfig.h"

// ---------------- Display Initializer ----------------
// For SH1106 OLED screens (fixes the 2-pixel shift/glitch line on the left side)
U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);
// For SSD1306 OLED screens (uncomment if using SSD1306)
// U8G2_SSD1306_128X64_NONAME_F_SW_I2C u8g2(U8G2_R0, PIN_OLED_SCL, PIN_OLED_SDA, U8X8_PIN_NONE);

// ---------------- Test Scenes ----------------
enum TestScene : uint8_t {
  SCENE_EYES = 0,
  SCENE_WELCOME,
  SCENE_LOADING,
  SCENE_STATUS,
  SCENE_PROTOTYPE,
  SCENE_MODE1,
  SCENE_MODE2,
  SCENE_MODE3,
  SCENE_MODE4,
  SCENE_MODE5,
  SCENE_MODE6,
  SCENE_COUNT
};

// ---------------- Eye Frame Struct ----------------
struct EyeFrame {
  const char* label;
  const char* detail;
  uint8_t contrast;
  uint8_t eyeW;
  uint8_t eyeH;
  int8_t leftPupilX;
  int8_t leftPupilY;
  int8_t rightPupilX;
  int8_t rightPupilY;
  uint8_t lidTop;
  uint8_t lidBottom;
  bool brows;
  bool glasses;
  bool tears;
  bool blank;
  bool word;
  const char* wordText;
};

// ---------------- Original 30 Eye Frames ----------------
enum FrameId : uint8_t {
  FRAME_EYES_FRONT = 0,
  FRAME_EYES_MIDDLE,
  FRAME_EYES_NARROW,
  FRAME_EYES_WIDE,
  FRAME_EYES_CROSSED,
  FRAME_EYES_DOWN,
  FRAME_EYES_UP,
  FRAME_EYES_RIGHT,
  FRAME_EYES_RIGHT_DOWN,
  FRAME_EYES_RIGHT_UP,
  FRAME_EYES_LEFT,
  FRAME_EYES_LEFT_DOWN,
  FRAME_EYES_LEFT_UP,
  FRAME_CONFUSED_1,
  FRAME_CONFUSED_2,
  FRAME_EYES_CRY,
  FRAME_EYES_DISTRESSED,
  FRAME_EYES_GLARE,
  FRAME_EYES_MAD,
  FRAME_EYES_GLASSES,
  FRAME_EYES_SLEEP,
  FRAME_BLINK_UPPER,
  FRAME_EYES_TIRED,
  FRAME_EYES_NIGHT,
  FRAME_UPPER_LIDS,
  FRAME_LOWER_LIDS,
  FRAME_EYES_BLANK,
  FRAME_WORD_HELLO,
  FRAME_WORD_BYE,
  FRAME_WORD_WHAT,
  FRAME_COUNT
};

static const EyeFrame FRAMES[FRAME_COUNT] = {
  { "01 EYES_FRONT", "neutral", OLED_CONTRAST_DAY, 18, 28, 0, 0, 0, 0, 0, 0, false, false, false, false, false, nullptr },
  { "02 EYES_MIDDLE", "centered", OLED_CONTRAST_DAY, 18, 28, 0, 0, 0, 0, 0, 0, false, false, false, false, false, nullptr },
  { "03 EYES_NARROW", "squint", OLED_CONTRAST_DAY, 18, 18, 0, 0, 0, 0, 4, 4, false, false, false, false, false, nullptr },
  { "04 EYES_WIDE", "alert", OLED_CONTRAST_DAY, 20, 34, 0, 0, 0, 0, 0, 0, false, false, false, false, false, nullptr },
  { "05 EYES_CROSSED", "crossed", OLED_CONTRAST_DAY, 18, 28, 4, 0, -4, 0, 0, 0, false, false, false, false, false, nullptr },
  { "06 EYES_DOWN", "looking down", OLED_CONTRAST_DAY, 18, 28, 0, 5, 0, 5, 0, 0, false, false, false, false, false, nullptr },
  { "07 EYES_UP", "looking up", OLED_CONTRAST_DAY, 18, 28, 0, -5, 0, -5, 0, 0, false, false, false, false, false, nullptr },
  { "08 EYES_RIGHT", "looking right", OLED_CONTRAST_DAY, 18, 28, 5, 0, 5, 0, 0, 0, false, false, false, false, false, nullptr },
  { "09 EYES_RIGHT_DOWN", "diag", OLED_CONTRAST_DAY, 18, 28, 5, 4, 5, 4, 0, 0, false, false, false, false, false, nullptr },
  { "10 EYES_RIGHT_UP", "diag", OLED_CONTRAST_DAY, 18, 28, 5, -4, 5, -4, 0, 0, false, false, false, false, false, nullptr },
  { "11 EYES_LEFT", "looking left", OLED_CONTRAST_DAY, 18, 28, -5, 0, -5, 0, 0, 0, false, false, false, false, false, nullptr },
  { "12 EYES_LEFT_DOWN", "diag", OLED_CONTRAST_DAY, 18, 28, -5, 4, -5, 4, 0, 0, false, false, false, false, false, nullptr },
  { "13 EYES_LEFT_UP", "diag", OLED_CONTRAST_DAY, 18, 28, -5, -4, -5, -4, 0, 0, false, false, false, false, false, nullptr },
  { "14 CONFUSED_1", "mixed", OLED_CONTRAST_DAY, 18, 28, -3, -1, 5, 1, 1, 1, true, false, false, false, false, nullptr },
  { "15 CONFUSED_2", "mixed", OLED_CONTRAST_DAY, 18, 28, 5, 1, -3, -1, 1, 1, true, false, false, false, false, nullptr },
  { "16 EYES_CRY", "tears", OLED_CONTRAST_EVENING, 18, 28, 0, 0, 0, 0, 0, 0, false, false, true, false, false, nullptr },
  { "17 EYES_DISTRESSED", "worried", OLED_CONTRAST_EVENING, 18, 22, -2, 2, 2, 2, 3, 4, true, false, false, false, false, nullptr },
  { "18 EYES_GLARE", "squint", OLED_CONTRAST_EVENING, 18, 14, 0, 0, 0, 0, 7, 7, true, false, false, false, false, nullptr },
  { "19 EYES_MAD", "angry", OLED_CONTRAST_DAY, 18, 22, 0, 0, 0, 0, 5, 5, true, false, false, false, false, nullptr },
  { "20 EYES_GLASSES", "frames", OLED_CONTRAST_DAY, 18, 28, 0, 0, 0, 0, 0, 0, false, true, false, false, false, nullptr },
  { "21 EYES_SLEEP", "sleeping", OLED_CONTRAST_NIGHT, 18, 10, 0, 0, 0, 0, 9, 9, false, false, false, false, false, nullptr },
  { "22 BLINK_UPPER", "blink", OLED_CONTRAST_DAY, 18, 28, 0, 0, 0, 0, 16, 16, false, false, false, false, false, nullptr },
  { "23 EYES_TIRED", "tired", OLED_CONTRAST_EVENING, 18, 16, 0, 2, 0, 2, 8, 5, true, false, false, false, false, nullptr },
  { "24 EYES_NIGHT", "night", OLED_CONTRAST_NIGHT, 18, 14, 0, 0, 0, 0, 11, 11, false, false, false, false, false, nullptr },
  { "25 UPPER_LIDS", "lid up", OLED_CONTRAST_EVENING, 18, 28, 0, 0, 0, 0, 14, 0, false, false, false, false, false, nullptr },
  { "26 LOWER_LIDS", "lid low", OLED_CONTRAST_EVENING, 18, 28, 0, 0, 0, 0, 0, 14, false, false, false, false, false, nullptr },
  { "27 EYES_BLANK", "blank", OLED_CONTRAST_DAY, 18, 28, 0, 0, 0, 0, 0, 0, false, false, false, true, false, nullptr },
  { "W01 WORD_HELLO", "word", OLED_CONTRAST_DAY, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false, true, "HELLO" },
  { "W02 WORD_BYE", "word", OLED_CONTRAST_DAY, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false, true, "BYE" },
  { "W03 WORD_WHAT", "word", OLED_CONTRAST_DAY, 0, 0, 0, 0, 0, 0, 0, 0, false, false, false, false, true, "WHAT?" },
};

// ---------------- Global State Variables ----------------
TestScene currentScene = SCENE_EYES;
uint8_t currentFrameIndex = 0;
bool autoCycleEyes = true;
uint32_t lastFrameSwitchMs = 0;
const uint32_t FRAME_HOLD_MS = 1400;

// Welcome scene variables
uint8_t welcomeStage = 0;
uint32_t lastWelcomeStepMs = 0;
const uint16_t WELCOME_STEP_MS = 2500;

// Spaceship loading variables
uint8_t loadingStage = 0;
uint32_t lastLoadingStepMs = 0;
const uint16_t LOADING_STEP_MS = 2000;

// Screen refresh timers
uint32_t lastDrawMs = 0;
const uint32_t DRAW_INTERVAL_MS = 33; // ~30 fps for smooth animations

// ---------------- Custom Bitmap Assets ----------------

// Reset Device Welcome Icon (13x16)
static const unsigned char img_device_reset_bits[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x20,0x1f,0x18,0x07,0x04,0x07,0x02,0x09,0x02,0x09,0x01,0x10,
  0x01,0x10,0x01,0x10,0x02,0x08,0x02,0x08,0x04,0x04,0x18,0x03,0xe0,0x00,0x00,0x00
};

// Spaceship Loading Assets
static const unsigned char img_arrow_bits[] PROGMEM = { 0x04,0x0e,0x1f }; // (5x3)
static const unsigned char img_arrow_1_bits[] PROGMEM = { 0x1f,0x0e,0x04 }; // (5x3)
static const unsigned char img_arrow_2_bits[] PROGMEM = { 0x01,0x03,0x07,0x03,0x01 }; // (3x5)

// Spaceship loading container outline (65x18)
static const unsigned char img_Space_bits[] PROGMEM = {
  0xf8,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0x00,0x06,0x00,0x00,0x00,0x00,0x00,0x00,
  0x80,0x00,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,
  0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x80,0x01,0xfe,0xff,0xff,0xff,0xff,0xff,0xff,
  0xff,0x00,0xfc,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0x00
};

// Spaceship Loading Fills
static const unsigned char img_loading_0_10_bits[] PROGMEM = {
  0x00,0x00,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,
  0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,
  0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,0xfe,0xff,0x00,
  0x00,0x00,0x00
}; // (17x17)

static const unsigned char img_loading_10_45_bits[] PROGMEM = {
  0x00,0x00,0x00,0x00,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,
  0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,
  0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,
  0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,0xfe,0xff,0xff,0x01,
  0x00,0x00,0x00,0x00
}; // (26x17)

static const unsigned char img_loading_45_75_bits[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x00,0x00,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,
  0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,
  0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,
  0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,
  0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,
  0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,0xfe,0xff,0xff,0xff,0xff,0x7f,
  0x00,0x00,0x00,0x00,0x00,0x00
}; // (48x17)

static const unsigned char img_loading_75_100_bits[] PROGMEM = {
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f,
  0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x7f
}; // (63x17)

static const unsigned char img_menu_tools_bits[] PROGMEM = {
  0x01,0x07,0x83,0x06,0x42,0x01,0x44,0x31,0xc8,0x30,0x50,0x2d,0x60,0x12,0xa0,0x0f,
  0xd0,0x00,0x28,0x07,0x94,0x0d,0x0a,0x1b,0x05,0x36,0x03,0x2c,0x00,0x38,0x00,0x00
}; // (14x16)

// Robot Prototype Image (89x8)
static const unsigned char img_robot_bits[] PROGMEM = {
  0x0e,0xf0,0x01,0x11,0x00,0x04,0x00,0x01,0x3c,0x00,0x40,0x00,0x11,0x10,0x00,0x1b,
  0x00,0x04,0x80,0x02,0x44,0x00,0x70,0x00,0x01,0x10,0x00,0x15,0x00,0x04,0x80,0x02,
  0x44,0x00,0x40,0x00,0x01,0xf0,0x00,0x15,0x00,0x04,0x40,0x04,0x3c,0x00,0x40,0x00,
  0x19,0x10,0x00,0x11,0x00,0x04,0x40,0x04,0x44,0x80,0x43,0x00,0x11,0x10,0x00,0x11,
  0x00,0x04,0xc0,0x07,0x44,0x00,0x40,0x00,0x11,0x10,0x00,0x11,0x00,0x04,0x40,0x04,
  0x44,0x00,0x40,0x00,0x0e,0xf0,0x01,0x11,0x00,0x7c,0x40,0x04,0x44,0x00,0xf0,0x01
};

// Network and Sync Assets
static const unsigned char img_wifi_full_bits[] PROGMEM = {
  0x80,0x0f,0x00,0xe0,0x3f,0x00,0x78,0xf0,0x00,0x9c,0xcf,0x01,0xee,0xbf,0x03,0xf7,
  0x78,0x07,0x3a,0xe7,0x02,0xdc,0xdf,0x01,0xe8,0xb8,0x00,0x70,0x77,0x00,0xa0,0x2f,
  0x00,0xc0,0x1d,0x00,0x80,0x0a,0x00,0x00,0x07,0x00,0x00,0x02,0x00
}; // (19x15)

static const unsigned char img_net_label_1[] PROGMEM = {
  0x49,0xc4,0x47,0x49,0x44,0x40,0x49,0x44,0x40,0x49,0xc4,0x43,0x49,0x44,0x40,0x49,
  0x44,0x40,0x36,0x44,0x40
}; // (23x7)

static const unsigned char img_net_label_2[] PROGMEM = {
  0x0e,0x00,0x00,0x00,0x09,0x00,0x00,0x00,0x11,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x81,0x39,0xc7,0x98,0xeb,0x38,0x00,0x00,0x41,0x4a,0x29,0x25,0x29,0x25,0x00,0x00,
  0x41,0x4a,0xe9,0x05,0x29,0x25,0x00,0x00,0x51,0x4a,0x29,0x24,0x29,0x25,0x00,0x00,
  0x8e,0x49,0xc9,0x18,0x29,0xb9,0xaa,0x02,0x00,0x00,0x00,0x00,0x00,0x20,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x18,0x00,0x00
}; // (58x9)

static const unsigned char img_arrow_down_filled[] PROGMEM = {
  0xf8,0x07,0x08,0x04,0xe8,0x05,0x68,0x05,0xa8,0x05,0x68,0x05,0xa8,0x05,0x6f,0x3d,
  0xa1,0x21,0xfa,0x17,0xf4,0x0b,0xe8,0x05,0xd0,0x02,0x20,0x01,0xc0,0x00
}; // (14x15)

static const unsigned char img_api_label_1[] PROGMEM = {
  0xce,0x17,0x54,0x14,0x00,0x0e,0x0f,0x01,0x51,0x30,0x56,0x14,0x00,0x11,0x11,0x01,
  0x41,0x50,0xd5,0x14,0x00,0x11,0x11,0x01,0xd9,0x93,0x54,0x15,0x1f,0x1f,0x0f,0x01,
  0x51,0x10,0x54,0x16,0x00,0x11,0x01,0x01,0x51,0x10,0x54,0x14,0x00,0x11,0x01,0x01,
  0xce,0x17,0x54,0x14,0x00,0x11,0x01,0x01
}; // (57x7)

static const unsigned char img_api_label_2[] PROGMEM = {
  0xe2,0xe3,0x01,0x00,0x23,0x20,0x02,0x00,0xe2,0x21,0x3a,0x03,0x02,0xe2,0x89,0x04,
  0x02,0x22,0x88,0x04,0x22,0x22,0x88,0x04,0xca,0x21,0x08,0x03
}; // (27x7)

static const unsigned char img_api_label_3[] PROGMEM = {
  0x0e,0x00,0x00,0x00,0x09,0x00,0x00,0x11,0x00,0x00,0x00,0x01,0x00,0x00,0x81,0x39,
  0xc7,0x98,0xeb,0x38,0x00,0x41,0x4a,0x29,0x25,0x29,0x25,0x00,0x41,0x4a,0xe9,0x05,
  0x29,0x25,0x00,0x51,0x4a,0x29,0x24,0x29,0x25,0x00,0x8e,0x49,0xc9,0x18,0x29,0xb9,
  0x2a,0x00,0x00,0x00,0x00,0x00,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x00
}; // (54x9)

static const unsigned char img_battery_full[] PROGMEM = {
  0xf0,0xff,0x7f,0x08,0x00,0x80,0xa8,0xaa,0xaa,0x8e,0xaa,0xaa,0xa1,0xaa,0xaa,0x81,
  0xaa,0xaa,0xa1,0xaa,0xaa,0x81,0xaa,0xaa,0xa1,0xaa,0xaa,0x8e,0xaa,0xaa,0xa8,0xaa,
  0xaa,0x08,0x00,0x80,0xf0,0xff,0x7f
}; // (24x13)

static const unsigned char img_cloud_sync[] PROGMEM = {
  0xe0,0x03,0x00,0x10,0x04,0x00,0x08,0x08,0x00,0x0c,0x10,0x00,0x02,0x70,0x00,0x01,
  0x80,0x00,0x41,0x04,0x01,0xe2,0x04,0x01,0xf4,0xf5,0x00,0x40,0x04,0x00,0x40,0x1f,
  0x00,0x40,0x0e,0x00,0x40,0x04,0x00
}; // (17x13)

static const unsigned char img_wifi[] PROGMEM = {
  0x80,0x0f,0x00,0x60,0x30,0x00,0x18,0xc0,0x00,0x84,0x0f,0x01,0x62,0x30,0x02,0x11,
  0x40,0x04,0x08,0x87,0x00,0xc4,0x18,0x01,0x20,0x20,0x00,0x10,0x42,0x00,0x80,0x0d,
  0x00,0x40,0x10,0x00,0x00,0x02,0x00,0x00,0x05,0x00,0x00,0x02,0x00
}; // (19x15)

static const unsigned char img_weather_temp[] PROGMEM = {
  0x38,0x00,0x44,0x40,0xd4,0xa0,0x54,0x40,0xd4,0x1c,0x54,0x06,0xd4,0x02,0x54,0x02,
  0x54,0x06,0x92,0x1c,0x39,0x01,0x75,0x01,0x7d,0x01,0x39,0x01,0x82,0x00,0x7c,0x00
}; // (16x16)

static const unsigned char img_status_label_1[] PROGMEM = {
  0x0e,0x1f,0x0e,0x1f,0x11,0x0e,0x11,0x04,0x11,0x04,0x11,0x11,0x01,0x04,0x11,0x04,
  0x11,0x01,0x0e,0x04,0x1f,0x04,0x11,0x0e,0x10,0x04,0x11,0x04,0x11,0x10,0x11,0x04,
  0x11,0x04,0x11,0x11,0x0e,0x04,0x11,0x04,0x0e,0x0e
}; // (45x7)

static const unsigned char img_status_val_1[] PROGMEM = {
  0x20,0x24,0x05,0x02,0x35,0x37,0x27,0x22,0x75,0x72
}; // (15x5)

static const unsigned char img_status_val_2[] PROGMEM = {
  0x07,0x00,0x22,0x35,0x52,0x57,0x32,0x35,0x62,0x15,0x00,0x10
}; // (15x6)

static const unsigned char img_status_val_3[] PROGMEM = {
  0x32,0x07,0x55,0x02,0x37,0x02,0x15,0x02,0x15,0x07
}; // (11x5)

static const unsigned char img_status_val_4[] PROGMEM = {
  0x03,0x22,0x00,0x00,0x65,0x77,0x52,0x05,0x53,0x22,0x35,0x05,0x55,0x22,0x13,0x06,
  0x63,0x44,0x16,0x04,0x00,0x00,0x00,0x03
}; // (27x6)

// ---------------- Helpers ----------------

void drawCentered(int y, const char* text, const uint8_t* font) {
  u8g2.setFont(font);
  int16_t w = u8g2.getStrWidth(text);
  u8g2.drawStr((128 - w) / 2, y, text);
}

void printHelp() {
  Serial.println(F("\n====== OLED TEST MONITOR HELP ======"));
  Serial.println(F("Press keys to select scenes, modes, and frames:"));
  Serial.println(F("  'e' : EYE ANIMATIONS MODE (Default)"));
  Serial.println(F("        '+' or 'n' -> Next eye frame      '-' or 'p' -> Previous eye frame"));
  Serial.println(F("        'a'        -> Toggle Auto-Cycle   'c'        -> Enable Auto-Cycle"));
  Serial.println(F("  'w' : Welcome Booting Sequence"));
  Serial.println(F("  'g' : Spaceship Loading Sequence"));
  Serial.println(F("  's' : System Network Dashboard"));
  Serial.println(F("  'p' : Robot Prototype Screen"));
  Serial.println(F("  '1'-'6' : Select Mode Menu (1 to 6)"));
  Serial.println(F("  '?' : Print this help menu again"));
  Serial.println(F("====================================="));
}

void printCodeExport() {
  Serial.println(F("\n--- C++ Code for current state ---"));
  if (currentScene == SCENE_EYES) {
    const EyeFrame& frame = FRAMES[currentFrameIndex];
    if (frame.word) {
      Serial.print(F("drawWord(\""));
      Serial.print(frame.wordText);
      Serial.println(F("\");"));
    } else {
      Serial.print(F("drawEyes("));
      Serial.print(F("w=")); Serial.print(frame.eyeW);
      Serial.print(F(", h=")); Serial.print(frame.eyeH);
      Serial.print(F(", pupilL_x=")); Serial.print(frame.leftPupilX);
      Serial.print(F(", pupilL_y=")); Serial.print(frame.leftPupilY);
      Serial.print(F(", pupilR_x=")); Serial.print(frame.rightPupilX);
      Serial.print(F(", pupilR_y=")); Serial.print(frame.rightPupilY);
      Serial.print(F(", lidTop=")); Serial.print(frame.lidTop);
      Serial.print(F(", lidBottom=")); Serial.print(frame.lidBottom);
      Serial.print(F(", glasses=")); Serial.print(frame.glasses ? "true" : "false");
      Serial.print(F(", tears=")); Serial.print(frame.tears ? "true" : "false");
      Serial.print(F(", brows=")); Serial.print(frame.brows ? "true" : "false");
      Serial.println(F(");"));
    }
  } else {
    Serial.print(F("drawScene("));
    Serial.print(currentScene);
    Serial.println(F(");"));
  }
  Serial.println(F("----------------------------------"));
}

// ---------------- Draw Primitive Assets ----------------

void drawHeader(const EyeFrame& frame) {
  u8g2.setFont(u8g2_font_4x6_tr);
  u8g2.drawStr(4, 8, frame.label);
  char contrastText[12];
  snprintf(contrastText, sizeof(contrastText), "C:%u", frame.contrast);
  u8g2.drawStr(98, 8, contrastText);
}

void drawEyebrow(int x1, int y1, int x2, int y2, bool angry) {
  if (angry) {
    u8g2.drawLine(x1, y1 + 3, x2, y2 - 2);
  } else {
    u8g2.drawLine(x1, y1, x2, y2);
  }
}

void drawDrop(int x, int y) {
  u8g2.drawDisc(x, y, 2);
  u8g2.drawLine(x, y - 3, x, y + 3);
}

void drawEye(int cx, int cy, uint8_t w, uint8_t h, int8_t pupilX, int8_t pupilY,
            uint8_t lidTop, uint8_t lidBottom, bool blank, bool glasses,
            bool tears, bool angry, bool tired) {
  int x = cx - (int)w / 2;
  int y = cy - (int)h / 2;
  uint8_t radius = (w < h ? w : h) / 2;
  if (radius > 7) radius = 7;

  u8g2.setDrawColor(1);
  u8g2.drawRBox(x, y, w, h, radius);

  if (!blank) {
    int pupilW = tired ? 4 : 5;
    int pupilH = tired ? 4 : 5;
    if (glasses) {
      pupilW = 3;
      pupilH = 4;
    }
    u8g2.setDrawColor(0);
    u8g2.drawDisc(cx + pupilX, cy + pupilY, pupilW);
    u8g2.drawDisc(cx + pupilX - 1, cy + pupilY - 1, pupilH - 1);
    u8g2.setDrawColor(1);
  }

  if (lidTop > 0) {
    u8g2.setDrawColor(0);
    u8g2.drawBox(x, y, w, lidTop);
    u8g2.setDrawColor(1);
  }

  if (lidBottom > 0) {
    u8g2.setDrawColor(0);
    u8g2.drawBox(x, y + h - lidBottom, w, lidBottom);
    u8g2.setDrawColor(1);
  }

  if (glasses) {
    u8g2.drawFrame(x - 2, y - 2, w + 4, h + 4);
  }

  if (tears) {
    drawDrop(cx - w / 3, y + h + 3);
    drawDrop(cx + w / 3, y + h + 3);
  }

  if (angry) {
    drawEyebrow(x - 1, y - 5, x + w + 1, y - 9, true);
  } else if (tired) {
    drawEyebrow(x, y - 5, x + w - 2, y - 7, false);
  }
}

// ---------------- Scene Drawing Routines ----------------

void drawSceneEyes() {
  const EyeFrame& frame = FRAMES[currentFrameIndex];

  // Head float drift simulation
  uint32_t phase = millis() / 120;
  int8_t driftX = (int8_t)((phase % 5) - 2);
  int8_t driftY = (int8_t)(((phase / 2) % 5) - 2);

  u8g2.drawRFrame(2, 2, 124, 60, 8);
  drawHeader(frame);

  if (frame.word) {
    drawCentered(28, frame.wordText, u8g2_font_ncenB08_tr);
    drawCentered(46, "OLED EYES TEST", u8g2_font_5x7_tr);
    return;
  }

  int leftCx = 44;
  int rightCx = 84;
  int cy = 28;

  int8_t leftPupilX = frame.leftPupilX + driftX;
  int8_t leftPupilY = frame.leftPupilY + driftY;
  int8_t rightPupilX = frame.rightPupilX - driftX;
  int8_t rightPupilY = frame.rightPupilY - driftY;

  // Custom configurations for specific frame coordinates
  if (currentFrameIndex == FRAME_EYES_FRONT || currentFrameIndex == FRAME_EYES_MIDDLE) {
    leftPupilX = driftX / 2;
    rightPupilX = -driftX / 2;
    leftPupilY = driftY / 2;
    rightPupilY = -driftY / 2;
  }

  if (currentFrameIndex == FRAME_EYES_CROSSED) {
    leftPupilX = 4;
    rightPupilX = -4;
  }

  if (currentFrameIndex == FRAME_CONFUSED_1) {
    leftPupilX = -3;
    rightPupilX = 5;
  }

  if (currentFrameIndex == FRAME_CONFUSED_2) {
    leftPupilX = 5;
    rightPupilX = -3;
  }

  if (currentFrameIndex == FRAME_EYES_RIGHT || currentFrameIndex == FRAME_EYES_RIGHT_UP || currentFrameIndex == FRAME_EYES_RIGHT_DOWN) {
    leftPupilX = 5;
    rightPupilX = 5;
  }

  if (currentFrameIndex == FRAME_EYES_LEFT || currentFrameIndex == FRAME_EYES_LEFT_UP || currentFrameIndex == FRAME_EYES_LEFT_DOWN) {
    leftPupilX = -5;
    rightPupilX = -5;
  }

  if (currentFrameIndex == FRAME_EYES_UP || currentFrameIndex == FRAME_EYES_RIGHT_UP || currentFrameIndex == FRAME_EYES_LEFT_UP) {
    leftPupilY = -5;
    rightPupilY = -5;
  }

  if (currentFrameIndex == FRAME_EYES_DOWN || currentFrameIndex == FRAME_EYES_RIGHT_DOWN || currentFrameIndex == FRAME_EYES_LEFT_DOWN) {
    leftPupilY = 5;
    rightPupilY = 5;
  }

  if (currentFrameIndex == FRAME_EYES_CRY) {
    leftPupilY = 1;
    rightPupilY = 1;
  }

  if (currentFrameIndex == FRAME_EYES_GLARE) {
    leftPupilY = 0;
    rightPupilY = 0;
  }

  if (currentFrameIndex == FRAME_EYES_TIRED) {
    leftPupilY = 2;
    rightPupilY = 2;
  }

  // Draw both eyes
  drawEye(leftCx, cy, frame.eyeW, frame.eyeH, leftPupilX, leftPupilY,
          frame.lidTop, frame.lidBottom, frame.blank, frame.glasses,
          frame.tears, frame.brows || currentFrameIndex == FRAME_EYES_MAD,
          currentFrameIndex == FRAME_EYES_SLEEP || currentFrameIndex == FRAME_EYES_TIRED || currentFrameIndex == FRAME_EYES_NIGHT);

  drawEye(rightCx, cy, frame.eyeW, frame.eyeH, rightPupilX, rightPupilY,
          frame.lidTop, frame.lidBottom, frame.blank, frame.glasses,
          frame.tears, frame.brows || currentFrameIndex == FRAME_EYES_MAD,
          currentFrameIndex == FRAME_EYES_SLEEP || currentFrameIndex == FRAME_EYES_TIRED || currentFrameIndex == FRAME_EYES_NIGHT);

  // Extra draw assets for specific frames
  if (currentFrameIndex == FRAME_EYES_MAD) {
    drawEyebrow(28, 13, 52, 9, true);
    drawEyebrow(76, 9, 100, 13, true);
  }

  if (currentFrameIndex == FRAME_EYES_GLARE) {
    drawEyebrow(28, 15, 52, 15, true);
    drawEyebrow(76, 15, 100, 15, true);
  }

  if (currentFrameIndex == FRAME_EYES_SLEEP || currentFrameIndex == FRAME_EYES_NIGHT) {
    u8g2.setFont(u8g2_font_6x10_tr);
    u8g2.drawStr(94, 18, "z");
    u8g2.drawStr(100, 14, "z");
    u8g2.drawStr(106, 10, "z");
  }

  if (frame.glasses) {
    u8g2.setDrawColor(1);
    u8g2.drawLine(62, 28, 66, 28);
  }

  // Bottom text detail
  u8g2.setFont(u8g2_font_5x7_tr);
  if (currentFrameIndex == FRAME_EYES_CRY) {
    u8g2.drawStr(12, 56, "I am getting sleepy...");
  } else if (currentFrameIndex == FRAME_EYES_NIGHT) {
    u8g2.drawStr(14, 56, "Night mode");
  } else if (currentFrameIndex == FRAME_EYES_SLEEP) {
    u8g2.drawStr(14, 56, "Sleepy eyes");
  } else {
    u8g2.drawStr(16, 56, frame.detail);
  }
}

void drawSceneWelcome() {
  u8g2.drawRFrame(2, 2, 124, 60, 8);

  switch (welcomeStage) {
    case 0:
      u8g2.setFont(u8g2_font_haxrcorp4089_tr);
      u8g2.drawStr(37, 18, "W e l c o m e ");
      u8g2.drawStr(37, 37, "B o o t i n g ....");
      u8g2.drawXBM(53, 42, 13, 16, img_device_reset_bits);
      break;

    case 1:
      u8g2.setFont(u8g2_font_haxrcorp4089_tr);
      u8g2.drawStr(30, 21, "G E M    L A R - 1");
      u8g2.drawStr(29, 50, "P R O T O T Y P E");
      u8g2.drawBox(40, 28, 12, 12);
      u8g2.drawBox(72, 28, 12, 12);
      break;

    case 2:
      u8g2.setFont(u8g2_font_haxrcorp4089_tr);
      u8g2.drawStr(27, 46, "G E M I N I  1.5 PRO");
      u8g2.drawStr(37, 18, "P O W E R E D ");
      u8g2.drawStr(59, 32, "B Y");
      break;

    case 3:
      u8g2.setFont(u8g2_font_haxrcorp4089_tr);
      u8g2.drawStr(41, 48, "YOLO  3.3V");
      u8g2.drawStr(37, 18, "P O W E R E D ");
      u8g2.drawStr(59, 32, "B Y");
      break;

    case 4:
      u8g2.setFont(u8g2_font_haxrcorp4089_tr);
      u8g2.drawStr(35, 19, "C R E A T O R");
      u8g2.drawStr(40, 35, "S H O V I  N  ");
      break;
  }
}

void drawSceneLoading() {
  // Arrow indicators at screen corners
  u8g2.drawXBM(120, 4, 5, 3, img_arrow_bits);
  u8g2.drawXBM(120, 56, 5, 3, img_arrow_1_bits);
  u8g2.drawXBM(4, 56, 5, 3, img_arrow_1_bits);
  u8g2.drawXBM(4, 4, 5, 3, img_arrow_bits);

  // Outer container boxes
  u8g2.drawRBox(108, 48, 16, 9, 1);
  u8g2.drawRBox(84, 48, 22, 9, 1);
  u8g2.drawRBox(64, 48, 18, 9, 1);
  
  u8g2.setDrawColor(2);
  u8g2.setFont(u8g2_font_4x6_tr);
  u8g2.drawStr(110, 55, "TFT");
  u8g2.drawStr(86, 55, "ADAF");
  u8g2.drawStr(66, 55, "U8G2");
  u8g2.setDrawColor(1);

  u8g2.drawStr(12, 55, "preview");
  u8g2.drawStr(12, 47, "Code");
  
  // Spaceship container
  u8g2.drawXBM(30, 18, 65, 18, img_Space_bits);
  
  // Progress segments
  switch (loadingStage) {
    case 0:
      u8g2.drawXBM(30, 18, 17, 17, img_loading_0_10_bits);
      drawCentered(10, "LOADING 0% - 10%", u8g2_font_4x6_tr);
      break;
    case 1:
      u8g2.drawXBM(30, 18, 26, 17, img_loading_10_45_bits);
      drawCentered(10, "LOADING 10% - 45%", u8g2_font_4x6_tr);
      break;
    case 2:
      u8g2.drawXBM(30, 18, 48, 17, img_loading_45_75_bits);
      drawCentered(10, "LOADING 45% - 75%", u8g2_font_4x6_tr);
      break;
    case 3:
      u8g2.drawXBM(31, 18, 63, 17, img_loading_75_100_bits);
      drawCentered(10, "LOAD COMPLETE 100%", u8g2_font_4x6_tr);
      break;
  }
}

void drawSceneStatus() {
  u8g2.drawXBM(91, 24, 24, 13, img_battery_full);
  u8g2.drawXBM(40, 25, 17, 13, img_cloud_sync);
  u8g2.drawXBM(12, 23, 19, 15, img_wifi);
  u8g2.drawXBM(66, 23, 16, 16, img_weather_temp);
  
  u8g2.drawXBM(43, 5, 45, 7, img_status_label_1);
  u8g2.drawXBM(14, 42, 15, 5, img_status_val_1);
  u8g2.drawXBM(63, 42, 15, 6, img_status_val_2);
  u8g2.drawXBM(42, 42, 11, 5, img_status_val_3);
  u8g2.drawXBM(91, 42, 27, 6, img_status_val_4);

  // Status boundary border
  u8g2.drawFrame(0, 0, 128, 64);
}

void drawScenePrototype() {
  u8g2.drawXBM(19, 17, 89, 8, img_robot_bits);
  u8g2.setFont(u8g2_font_profont12_tr);
  u8g2.drawStr(18, 44, "P r o t o t y p e");
  u8g2.drawFrame(0, 0, 128, 64);
}

void drawSceneModes(uint8_t modeNum) {
  u8g2.setFontMode(1);
  u8g2.setBitmapMode(1);

  if (modeNum == 0) {
    // Mode menu
    u8g2.setFont(u8g2_font_haxrcorp4089_tr);
    u8g2.drawStr(5, 12, " C H O O S E   THE  M O D E S");
    
    u8g2.setDrawColor(2);
    u8g2.setFont(u8g2_font_4x6_tr);
    u8g2.drawStr(8, 41, "M O D E - 2");
    
    u8g2.setDrawColor(1);
    u8g2.drawStr(5, 24, " M O D E - 1");
    u8g2.drawStr(9, 56, "M O D E - 3");
    u8g2.drawStr(77, 24, "M O D E - 4");
    u8g2.drawStr(77, 40, "M O D E - 5");
    u8g2.drawStr(78, 56, "M O D E - 6");
  } else {
    // Mode details
    u8g2.setFont(u8g2_font_helvB08_tr);
    char headerText[16];
    snprintf(headerText, sizeof(headerText), "M O D E - %d", modeNum);
    u8g2.drawStr(36, 16, headerText);

    u8g2.setFont(u8g2_font_haxrcorp4089_tr);
    switch (modeNum) {
      case 1:
        u8g2.setFont(u8g2_font_helvB08_tr);
        u8g2.drawStr(31, 45, "A U T O B O T");
        break;
      case 2:
        u8g2.setFont(u8g2_font_helvB08_tr);
        u8g2.drawStr(13, 43, "C O N T R O L- B O T");
        break;
      case 3:
        u8g2.setFont(u8g2_font_helvB08_tr);
        u8g2.drawStr(10, 35, "G E M I N I -V O I C E");
        u8g2.drawStr(52, 52, "B O T");
        break;
      case 4:
        u8g2.setFont(u8g2_font_helvB08_tr);
        u8g2.drawStr(10, 35, "G E M I N I -V O I C E");
        u8g2.drawStr(52, 52, "B O T");
        break;
      case 5:
        u8g2.drawStr(32, 30, "O B J  E  C T ");
        u8g2.drawStr(19, 45, " D E T E C T I O N");
        u8g2.drawStr(50, 59, " B O T");
        break;
      case 6:
        u8g2.setFont(u8g2_font_haxrcorp4089_tr);
        u8g2.drawStr(14, 33, "S  U  R  V E  I  L L A  N  C E");
        u8g2.setFont(u8g2_font_helvB08_tr);
        u8g2.drawStr(50, 48, " B O T");
        break;
    }
  }
}

// ---------------- Interactive Loop Handling ----------------

void updateSequences() {
  uint32_t now = millis();

  // Welcome sequence runner
  if (currentScene == SCENE_WELCOME) {
    if (now - lastWelcomeStepMs >= WELCOME_STEP_MS) {
      lastWelcomeStepMs = now;
      welcomeStage = (welcomeStage + 1) % 5;
    }
  }

  // Loading progress runner
  if (currentScene == SCENE_LOADING) {
    if (now - lastLoadingStepMs >= LOADING_STEP_MS) {
      lastLoadingStepMs = now;
      loadingStage = (loadingStage + 1) % 4;
    }
  }

  // Eye frame auto cycle runner
  if (currentScene == SCENE_EYES && autoCycleEyes) {
    if (now - lastFrameSwitchMs >= FRAME_HOLD_MS) {
      lastFrameSwitchMs = now;
      currentFrameIndex = (uint8_t)((currentFrameIndex + 1) % FRAME_COUNT);
    }
  }
}

void handleSerialCommand() {
  if (!Serial.available()) return;

  char c = Serial.read();
  // Filter newlines and whitespace
  if (c == '\r' || c == '\n' || c == ' ') return;

  switch (c) {
    case '?':
      printHelp();
      break;

    case 'e':
      currentScene = SCENE_EYES;
      autoCycleEyes = true;
      lastFrameSwitchMs = millis();
      Serial.println(F("Scene: EYE ANIMATIONS (Auto-cycling)"));
      printCodeExport();
      break;

    case 'a':
      if (currentScene == SCENE_EYES) {
        autoCycleEyes = !autoCycleEyes;
        Serial.print(F("Toggle Auto-Cycle: "));
        Serial.println(autoCycleEyes ? F("ON") : F("OFF"));
      }
      break;

    case 'c':
      if (currentScene == SCENE_EYES) {
        autoCycleEyes = true;
        Serial.println(F("Auto-Cycle forced: ON"));
      }
      break;

    case '+':
    case 'n':
      if (currentScene == SCENE_EYES) {
        autoCycleEyes = false;
        currentFrameIndex = (uint8_t)((currentFrameIndex + 1) % FRAME_COUNT);
        Serial.print(F("Manual Next Frame: "));
        Serial.println(FRAMES[currentFrameIndex].label);
        printCodeExport();
      }
      break;

    case '-':
    case 'p':
      if (currentScene == SCENE_EYES) {
        autoCycleEyes = false;
        if (currentFrameIndex == 0) {
          currentFrameIndex = FRAME_COUNT - 1;
        } else {
          currentFrameIndex = currentFrameIndex - 1;
        }
        Serial.print(F("Manual Prev Frame: "));
        Serial.println(FRAMES[currentFrameIndex].label);
        printCodeExport();
      }
      break;

    case 'w':
      currentScene = SCENE_WELCOME;
      welcomeStage = 0;
      lastWelcomeStepMs = millis();
      Serial.println(F("Scene: Welcome Booting Sequence"));
      break;

    case 'g':
      currentScene = SCENE_LOADING;
      loadingStage = 0;
      lastLoadingStepMs = millis();
      Serial.println(F("Scene: Spaceship Loading Sequence"));
      break;

    case 's':
      currentScene = SCENE_STATUS;
      Serial.println(F("Scene: Network & Sync Status Dashboard"));
      break;

    case 'r':
      currentScene = SCENE_PROTOTYPE;
      Serial.println(F("Scene: Robot Prototype Graphic Layout"));
      break;

    case '1': currentScene = SCENE_MODE1; Serial.println(F("Scene: Mode 1 AutoBot")); break;
    case '2': currentScene = SCENE_MODE2; Serial.println(F("Scene: Mode 2 ControlBot")); break;
    case '3': currentScene = SCENE_MODE3; Serial.println(F("Scene: Mode 3 GeminiVoice")); break;
    case '4': currentScene = SCENE_MODE4; Serial.println(F("Scene: Mode 4 VoiceBot")); break;
    case '5': currentScene = SCENE_MODE5; Serial.println(F("Scene: Mode 5 Object Detection")); break;
    case '6': currentScene = SCENE_MODE6; Serial.println(F("Scene: Mode 6 Surveillance")); break;

    default:
      Serial.print(F("Unknown command: "));
      Serial.println(c);
      break;
  }
}

// ---------------- Setup and Loop ----------------

void setup() {
  Serial.begin(115200);
  
  pinMode(PIN_OLED_SDA, OUTPUT);
  pinMode(PIN_OLED_SCL, OUTPUT);
  
  u8g2.begin();
  u8g2.setPowerSave(0);

  // Initialize timers
  lastFrameSwitchMs = millis();

  printHelp();
  printCodeExport();
}

void loop() {
  // Read interactive commands from Serial Monitor
  handleSerialCommand();

  // Run sequence and auto-cycle timers
  updateSequences();

  // Render to physical display
  uint32_t now = millis();
  if (now - lastDrawMs >= DRAW_INTERVAL_MS) {
    lastDrawMs = now;
    
    // Select contrast defined by current frame
    if (currentScene == SCENE_EYES) {
      u8g2.setContrast(FRAMES[currentFrameIndex].contrast);
    } else {
      u8g2.setContrast(OLED_CONTRAST_DAY);
    }
    
    u8g2.clearBuffer();

    switch (currentScene) {
      case SCENE_EYES:
        drawSceneEyes();
        break;
      case SCENE_WELCOME:
        drawSceneWelcome();
        break;
      case SCENE_LOADING:
        drawSceneLoading();
        break;
      case SCENE_STATUS:
        drawSceneStatus();
        break;
      case SCENE_PROTOTYPE:
        drawScenePrototype();
        break;
      case SCENE_MODE1: drawSceneModes(1); break;
      case SCENE_MODE2: drawSceneModes(2); break;
      case SCENE_MODE3: drawSceneModes(3); break;
      case SCENE_MODE4: drawSceneModes(4); break;
      case SCENE_MODE5: drawSceneModes(5); break;
      case SCENE_MODE6: drawSceneModes(6); break;
      default:
        break;
    }

    u8g2.sendBuffer();
  }
}
