/*
 * GEM v2 Pro - Smart Desktop Companion + Biometric Health Telemetry
 * AWIE LABS (https://awie.in)
 * 
 * Hardware Features:
 * - 32-bit Dual-Core ESP32 Microcontroller
 * - 0.96" High-Contrast I2C OLED (128x64) Expression Display
 * - Touch Capacitive Sensor (GPIO 15)
 * - IR Distance / Proximity Motion Monitoring Sensor (GPIO 34)
 * - MAX30102 PPG Pulse Oximeter & Heart Rate Sensor (I2C 0x57)
 * - Real-time Biometric Pulse Monitoring & Companion App Telemetry
 * - WS2812B Addressable RGB LED Hair Ring (GPIO 4)
 * - Wi-Fi 2.4GHz & Low-Latency Bluetooth Sync
 * - LiPo Battery Power Management
 */

#ifndef GEM_V2_CONFIG_H
#define GEM_V2_CONFIG_H

#define GEM_VERSION "2.0.0"
#define GEM_MODEL "GEM_v2_Pro_Biometric"

// Pin Definitions
#define OLED_SDA 21
#define OLED_SCL 22
#define MAX30102_SDA 21
#define MAX30102_SCL 22
#define TOUCH_SENSOR_PIN 15
#define IR_PROXIMITY_PIN 34
#define RGB_LED_PIN 4
#define NUM_RGB_LEDS 8

// Feature Flags
#define ENABLE_IR_PROXIMITY true
#define ENABLE_PULSE_SENSOR true
#define ENABLE_TOUCH_SENSOR true
#define ENABLE_RGB_MOOD_LIGHTS true
#define ENABLE_WIFI_SYNC true
#define ENABLE_BIOMETRIC_TELEMETRY true

#endif // GEM_V2_CONFIG_H
