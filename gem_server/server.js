const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

// Enable CORS
app.use(cors());

// Support JSON and URL-encoded bodies
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Create HTTP server
const server = http.createServer(app);

// Initialize WebSocket server instance
const wss = new WebSocket.Server({ server });

// Track connected clients
const clients = new Set();

// Guard Mode state and persistent memory logs
let guardModeActive = false;
const guardLogs = [];

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[WebSocket] Client connected from ${ip}`);
  clients.add(ws);

  // Send a welcome message to confirm connection & current status
  ws.send(JSON.stringify({ 
    event: 'info', 
    message: 'Connected to GEM Notification Broker Server',
    guardMode: guardModeActive
  }));

  ws.on('close', () => {
    console.log(`[WebSocket] Client disconnected (${ip})`);
    clients.delete(ws);
  });

  ws.on('error', (error) => {
    console.error(`[WebSocket] Error: ${error.message}`);
    clients.delete(ws);
  });
});

// Broadcast helper
function broadcast(payload) {
  let count = 0;
  clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(payload));
      count++;
    }
  });
  return count;
}

// HTTP REST endpoints
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    clients: clients.size,
    guardModeActive,
    totalLogs: guardLogs.length 
  });
});

// Guard Mode status check
app.get('/api/guard/status', (req, res) => {
  res.json({ active: guardModeActive });
});

// Guard Mode toggle
app.post('/api/guard/toggle', (req, res) => {
  const { active } = req.body;
  if (typeof active === 'boolean') {
    guardModeActive = active;
  } else {
    guardModeActive = !guardModeActive;
  }

  console.log(`[Guard Mode] Toggled to ${guardModeActive ? 'ACTIVE' : 'INACTIVE'}`);

  // Broadcast state change to all clients (ESP32 and Flutter App)
  broadcast({
    event: 'guard_toggle',
    active: guardModeActive
  });

  res.json({ success: true, active: guardModeActive });
});

// Fetch Desk Guard Logs
app.get('/api/guard/logs', (req, res) => {
  res.json(guardLogs);
});

// Clear Desk Guard Logs
app.post('/api/guard/clear', (req, res) => {
  guardLogs.length = 0;
  console.log('[Guard Mode] Security logs cleared.');
  res.json({ success: true });
});

// Webhook that the ESP32 triggers
app.post('/webhook', (req, res) => {
  console.log('--- RECEIVED WEBHOOK ALERT FROM GEM ---');
  console.log('Headers:', req.headers);
  console.log('Body:', req.body);

  const device = req.body.device || 'GEM';
  const user = req.body.user || 'Friend';
  const event = req.body.reason || req.body.event || 'general-alert';
  const battery = req.body.battery || '100';
  const ldr = req.body.ldr || '2048';

  console.log(`[Event] Device: ${device} | Event: ${event} | LDR: ${ldr} | Battery: ${battery}%`);

  // Log event if Guard Mode is active (or generally for records)
  const isSecurityAlert = ['shadow-detected', 'flash-detected', 'touch-down', 'long-touch', 'alarm'].includes(event);
  
  const logEntry = {
    timestamp: new Date().toISOString(),
    event,
    device,
    user,
    battery: parseInt(battery, 10) || 100,
    ldr: parseInt(ldr, 10) || 2048,
    guardActive: guardModeActive
  };
  
  if (guardModeActive || isSecurityAlert) {
    guardLogs.unshift(logEntry); // Add to beginning of logs array
    if (guardLogs.length > 50) {
      guardLogs.pop(); // Keep last 50 entries
    }
  }

  // Construct message to forward to Flutter app
  const payload = {
    event: 'alert',
    reason: event,
    device: device,
    battery: parseInt(battery, 10) || 100,
    ldr: parseInt(ldr, 10) || 2048,
    guardActive: guardModeActive,
    timestamp: logEntry.timestamp
  };

  // Broadcast to all connected WebSockets
  const broadcastCount = broadcast(payload);

  console.log(`[Broadcast] Forwarded alert payload to ${broadcastCount} app clients.`);
  console.log('----------------------------------------');

  res.status(200).send('Alert received and broadcasted successfully.');
});

// Start the server
server.listen(port, '0.0.0.0', () => {
  console.log(`==================================================`);
  console.log(`🚀 GEM Webhook Security Broker running on port ${port}`);
  console.log(`👉 Webhook URL for ESP32: http://<YOUR_COMPUTER_IP>:${port}/webhook`);
  console.log(`👉 WebSocket URL for App: ws://<YOUR_COMPUTER_IP>:${port}`);
  console.log(`==================================================`);
});
