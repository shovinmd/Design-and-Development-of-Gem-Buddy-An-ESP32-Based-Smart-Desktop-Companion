/*
 * GEM v1 - Autonomous Desktop Companion Firmware Config
 * AWIE LABS (https://awie.in)
 * 
 * Hardware Features:
 * - 32-bit Dual-Core ESP32 Microcontroller
 * - 0.96" High-Contrast I2C OLED (128x64) Expression Display
 * - Touch Capacitive Sensor (GPIO 15)
 * - IR Distance / Proximity Motion Monitoring Sensor (GPIO 34)
 * - WS2812B Addressable RGB LED Hair Ring (GPIO 4)
 * - Wi-Fi 2.4GHz & Low-Latency Bluetooth Sync
 * - LiPo Battery Power Management
 * 
 * Note: GEM v1 does NOT include pulse heart-rate sensing.
 * For Heart Rate & Biometric Pulse monitoring, upgrade to GEM v2.
 */

#ifndef GEM_V1_CONFIG_H
#define GEM_V1_CONFIG_H

#define GEM_VERSION "1.0.0"
#define GEM_MODEL "GEM_v1_Standard"

// Pin Definitions
#define OLED_SDA 21
#define OLED_SCL 22
#define TOUCH_SENSOR_PIN 15
#define IR_PROXIMITY_PIN 34
#define RGB_LED_PIN 4
#define NUM_RGB_LEDS 8

// Feature Flags
#define ENABLE_IR_PROXIMITY true
#define ENABLE_PULSE_SENSOR false
#define ENABLE_TOUCH_SENSOR true
#define ENABLE_RGB_MOOD_LIGHTS true
#define ENABLE_WIFI_SYNC true

#endif // GEM_V1_CONFIG_H
