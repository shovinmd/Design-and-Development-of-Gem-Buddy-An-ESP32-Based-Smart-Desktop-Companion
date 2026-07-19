const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// ── Firebase Admin SDK Initialization ──────────────────────────────────────────
let admin = null;
const serviceAccountPath = path.join(__dirname, 'service-account.json');
if (fs.existsSync(serviceAccountPath)) {
  try {
    admin = require('firebase-admin');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('[FCM] Firebase Admin SDK initialized successfully.');
  } catch (e) {
    console.error('[FCM] Failed to initialize Firebase Admin:', e.message);
  }
} else {
  console.log('[FCM] service-account.json not found. Push notifications will be skipped.');
}

const fcmTokens = new Set();

async function sendPushNotification(title, body) {
  if (!admin || fcmTokens.size === 0) {
    console.log(`[FCM] Push skipped: adminInit=${!!admin}, tokensRegistered=${fcmTokens.size}`);
    return;
  }
  
  const tokens = Array.from(fcmTokens);
  const message = {
    notification: { title, body },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[FCM] Sent: ${response.successCount} succeeded; ${response.failureCount} failed.`);
  } catch (error) {
    console.error('[FCM] Error sending push notification:', error);
  }
}

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// ── Tracked state ──────────────────────────────────────────────────────────────
const clients = new Set();
let guardModeActive = false;
const guardLogs = [];

// Last-seen timestamps (epoch ms)
const lastSeen = {
  device: 0,   // last ping from ESP32
  app:    0,   // last ping from Flutter app
};

// ── WebSocket connections ──────────────────────────────────────────────────────
wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  console.log(`[WS] Client connected from ${ip}`);
  clients.add(ws);

  // Welcome: include current guard state + last-seen info
  ws.send(JSON.stringify({
    event:         'info',
    message:       'Connected to GEM Security Broker',
    guardMode:     guardModeActive,
    deviceOnline:  isOnline('device'),
    appOnline:     isOnline('app'),
    lastSeenDevice: lastSeen.device,
    lastSeenApp:    lastSeen.app,
  }));

  ws.on('close', () => {
    console.log(`[WS] Client disconnected (${ip})`);
    clients.delete(ws);
  });

  ws.on('error', (err) => {
    console.error(`[WS] Error: ${err.message}`);
    clients.delete(ws);
  });
});

// ── Helpers ────────────────────────────────────────────────────────────────────
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

/** Returns true if the given source pinged within the last 90 seconds */
function isOnline(source) {
  return lastSeen[source] > 0 && (Date.now() - lastSeen[source]) < 90_000;
}

function addLog(entry) {
  guardLogs.unshift(entry);
  if (guardLogs.length > 100) guardLogs.pop();
}

// ── REST: Health ───────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    clients: clients.size,
    guardModeActive,
    totalLogs: guardLogs.length,
    deviceOnline: isOnline('device'),
    appOnline:    isOnline('app'),
    lastSeenDevice: lastSeen.device ? new Date(lastSeen.device).toISOString() : null,
    lastSeenApp:    lastSeen.app    ? new Date(lastSeen.app).toISOString()    : null,
  });
});

// ── REST: Ping (device or app keepalive) ───────────────────────────────────────
// POST /api/ping  { source: "device"|"app", device?, battery?, ldr? }
// GET  /api/ping?source=device  (for ESP32 which uses GET easier)
function handlePing(req, res) {
  const body    = { ...req.query, ...req.body };
  const source  = (body.source || 'device').toLowerCase();
  const device  = body.device  || 'GEM';
  const ldr     = parseInt(body.ldr, 10) || 0;
  const now     = Date.now();

  if (source === 'device' || source === 'app') {
    lastSeen[source] = now;
  }

  console.log(`[Ping] ${source.toUpperCase()} | device=${device} ldr=${ldr} guardMode=${guardModeActive}`);

  // Build ack payload — no battery field
  const ack = {
    event:         'ping_ack',
    source,
    device,
    ldr,
    guardMode:     guardModeActive,
    deviceOnline:  isOnline('device'),
    appOnline:     isOnline('app'),
    timestamp:     new Date(now).toISOString(),
  };

  // Broadcast ack to all WebSocket clients
  broadcast(ack);

  res.json({ ok: true, guardMode: guardModeActive, ack });
}

app.get('/api/ping',  handlePing);
app.post('/api/ping', handlePing);

// ── REST: Guard status ─────────────────────────────────────────────────────────
app.get('/api/guard/status', (req, res) => {
  res.json({
    active:        guardModeActive,
    deviceOnline:  isOnline('device'),
    appOnline:     isOnline('app'),
    lastSeenDevice: lastSeen.device,
    lastSeenApp:    lastSeen.app,
  });
});

// ── REST: Guard toggle ─────────────────────────────────────────────────────────
app.post('/api/guard/toggle', (req, res) => {
  const { active } = req.body;
  guardModeActive = (typeof active === 'boolean') ? active : !guardModeActive;
  const source = req.body.device || 'app';
  console.log(`[Guard] Toggled by ${source} → ${guardModeActive ? 'ACTIVE' : 'INACTIVE'}`);

  const entry = {
    timestamp:   new Date().toISOString(),
    event:       guardModeActive ? 'guard-enabled' : 'guard-disabled',
    device:      source,
    guardActive: guardModeActive,
  };
  addLog(entry);

  // Push to all WebSocket clients (app + any monitor)
  broadcast({ event: 'guard_toggle', active: guardModeActive, device: source });
  res.json({ success: true, active: guardModeActive });
});

// ── REST: Guard logs ───────────────────────────────────────────────────────────
app.get('/api/guard/logs', (req, res) => res.json(guardLogs));

app.post('/api/guard/clear', (req, res) => {
  guardLogs.length = 0;
  console.log('[Guard] Logs cleared.');
  res.json({ success: true });
});

// ── REST: FCM token registration ──────────────────────────────────────────────
app.post('/api/fcm/register', (req, res) => {
  const { token } = req.body;
  if (token) {
    fcmTokens.add(token);
    console.log(`[FCM] Registered token: ${token.substring(0, 10)}... (Total: ${fcmTokens.size})`);
  }
  res.json({ success: true });
});

// ── REST: Webhook (ESP32 security events) ─────────────────────────────────────
app.post('/webhook', (req, res) => {
  const device = req.body.device || 'GEM';
  const user   = req.body.user   || 'Friend';
  const event  = req.body.reason || req.body.event || 'general-alert';
  const ldr    = parseInt(req.body.ldr, 10) || 0;

  console.log(`[Webhook] device=${device} event=${event} ldr=${ldr}`);

  // Update device last-seen
  lastSeen.device = Date.now();

  const isSecurityAlert = ['shadow-detected', 'flash-detected', 'touch-down', 'long-touch', 'touch-detected'].includes(event);
  const isAlarmEvent = ['alarm', 'alarm-dismissed'].includes(event);

  const logEntry = {
    timestamp:   new Date().toISOString(),
    event,
    device,
    user,
    ldr,
    guardActive: guardModeActive,
  };

  const shouldLogAndBroadcast = (isSecurityAlert && guardModeActive) || isAlarmEvent;

  if (shouldLogAndBroadcast) {
    addLog(logEntry);

    // Broadcast alert to all WebSocket clients (app)
    const payload = {
      event:        'alert',
      reason:       event,
      device,
      ldr,
      guardActive:  guardModeActive,
      deviceOnline: true,
      timestamp:    logEntry.timestamp,
    };

    const count = broadcast(payload);
    console.log(`[Broadcast] Sent alert to ${count} client(s).`);

    // Send push notification
    let pushTitle = 'GEM Security Alert';
    let pushBody = `${device} triggered an event.`;
    if (event === 'shadow-detected') {
      pushTitle = '🚨 GEM Shadow Alert';
      pushBody = `Shadow detected! LDR reading: ${ldr}`;
    } else if (event === 'flash-detected') {
      pushTitle = '🚨 GEM Light Spike Alert';
      pushBody = `Unexpected flash/light spike! LDR reading: ${ldr}`;
    } else if (event === 'touch-down' || event === 'touch-detected') {
      pushTitle = '🚨 GEM Touch Alert';
      pushBody = `Physical touch detected on GEM!`;
    } else if (event === 'long-touch') {
      pushTitle = '🚨 GEM Long Touch Alert';
      pushBody = `Sustained touch detected on GEM!`;
    } else if (event === 'alarm') {
      pushTitle = '⏰ GEM Reminder';
      pushBody = `Your scheduled reminder/alarm is ringing!`;
    }
    
    sendPushNotification(pushTitle, pushBody);
  }

  res.status(200).send('OK');
});

// ── Server-side heartbeat: broadcast connectivity status every 30s ─────────────
setInterval(() => {
  if (clients.size > 0) {
    broadcast({
      event:        'status_update',
      guardMode:    guardModeActive,
      deviceOnline: isOnline('device'),
      appOnline:    isOnline('app'),
      timestamp:    new Date().toISOString(),
    });
  }
}, 30_000);

// ── Start ──────────────────────────────────────────────────────────────────────
server.listen(port, '0.0.0.0', () => {
  console.log(`==================================================`);
  console.log(`🚀 GEM Security Broker  →  port ${port}`);
  console.log(`   GET/POST /api/ping   — device / app keepalive`);
  console.log(`   POST /webhook        — ESP32 security events`);
  console.log(`   WS   ws://<host>:${port}   — Flutter app stream`);
  console.log(`==================================================`);
});
