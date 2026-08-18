/*
 * GEM v1 - Autonomous Desktop Companion Firmware Config
 * AWIE LABS (https://awie.in)
 * 
 * Hardware Features:
 * - 32-bit Dual-Core ESP32 Microcontroller
 * - 0.96" High-Contrast I2C OLED (128x64) Expression Display
 * - Touch Capacitive Sensor (GPIO 15)
 * - 4 White LED Ambient Bulbs (GPIO 4) (Pure White Illumination)
 * - 1000mAh Rechargeable LiPo Battery via Type-C
 * - Wi-Fi 2.4GHz & Low-Latency Bluetooth Sync with GEM Mobile App
 * 
 * Note: GEM v1 does NOT include IR Motion sensing or MAX30102 Pulse heart-rate sensing.
 * For Heart Rate & IR Motion monitoring, upgrade to GEM v2 Pro.
 */

#ifndef GEM_V1_CONFIG_H
#define GEM_V1_CONFIG_H

#define GEM_VERSION "1.0.0"
#define GEM_MODEL "GEM_v1_Standard"

// Pin Definitions
#define OLED_SDA 21
#define OLED_SCL 22
#define TOUCH_SENSOR_PIN 15
#define WHITE_LEDS_PIN 4
#define NUM_WHITE_LEDS 4

// Battery Specs
#define BATTERY_CAPACITY_MAH 1000

// Feature Flags
#define ENABLE_IR_PROXIMITY false
#define ENABLE_PULSE_SENSOR false
#define ENABLE_TOUCH_SENSOR true
#define ENABLE_WHITE_LEDS true
#define ENABLE_RGB_MOOD_LIGHTS false
#define ENABLE_WIFI_SYNC true
#define ENABLE_GEM_APP_SUPPORT true

#endif // GEM_V1_CONFIG_H
