# GEM Webhook & WebSocket Broker Server

This Node.js server acts as an online bridge between your GEM (ESP32 device) and the GEM Flutter companion app.

When the ESP32 is in security mode and detects a motion/touch alert, it sends an HTTP POST request to this server's `/webhook` endpoint. The server then instantly broadcasts the alert to all connected Flutter app instances via WebSockets.

## Setup Instructions

### 1. Install Dependencies
Ensure you have [Node.js](https://nodejs.org/) installed. Run this command in this directory:
```bash
npm install
```

### 2. Start the Server
Start the server using:
```bash
npm start
```

It will print the URLs:
- **Webhook URL** (Save this in your ESP32 configuration settings as the webhook url: `http://<YOUR_COMPUTER_IP>:3000/webhook`)
- **WebSocket URL** (Enter this inside the Flutter companion app Settings screen under 'Security Webhook Broker': `<YOUR_COMPUTER_IP>`)

### 3. Verify Server Status
Open `http://localhost:3000/health` in your browser to check how many app clients are currently connected.
