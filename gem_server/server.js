const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

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
  const battery = parseInt(body.battery, 10) || 100;
  const ldr     = parseInt(body.ldr,     10) || 2048;
  const now     = Date.now();

  if (source === 'device' || source === 'app') {
    lastSeen[source] = now;
  }

  console.log(`[Ping] ${source.toUpperCase()} | device=${device} bat=${battery}% ldr=${ldr} guardMode=${guardModeActive}`);

  // Build ack payload
  const ack = {
    event:         'ping_ack',
    source,
    device,
    battery,
    ldr,
    guardMode:     guardModeActive,
    deviceOnline:  isOnline('device'),
    appOnline:     isOnline('app'),
    timestamp:     new Date(now).toISOString(),
  };

  // Log the ping if guard mode is on
  if (guardModeActive) {
    addLog({
      timestamp:   ack.timestamp,
      event:       `${source}-ping`,
      device,
      battery,
      ldr,
      guardActive: true,
    });
  }

  // Broadcast ack to all WebSocket clients (app sees device is alive, and vice-versa)
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
  console.log(`[Guard] Toggled → ${guardModeActive ? 'ACTIVE' : 'INACTIVE'}`);

  const entry = {
    timestamp:   new Date().toISOString(),
    event:       guardModeActive ? 'guard-enabled' : 'guard-disabled',
    device:      req.body.device || 'app',
    battery:     100,
    ldr:         0,
    guardActive: guardModeActive,
  };
  addLog(entry);

  broadcast({ event: 'guard_toggle', active: guardModeActive });
  res.json({ success: true, active: guardModeActive });
});

// ── REST: Guard logs ───────────────────────────────────────────────────────────
app.get('/api/guard/logs', (req, res) => res.json(guardLogs));

app.post('/api/guard/clear', (req, res) => {
  guardLogs.length = 0;
  console.log('[Guard] Logs cleared.');
  res.json({ success: true });
});

// ── REST: Webhook (ESP32 security events) ─────────────────────────────────────
app.post('/webhook', (req, res) => {
  const device  = req.body.device  || 'GEM';
  const user    = req.body.user    || 'Friend';
  const event   = req.body.reason  || req.body.event || 'general-alert';
  const battery = req.body.battery || '100';
  const ldr     = req.body.ldr     || '2048';

  console.log(`[Webhook] device=${device} event=${event} ldr=${ldr} bat=${battery}%`);

  // Update device last-seen on any webhook too
  lastSeen.device = Date.now();

  const isSecurityAlert = ['shadow-detected','flash-detected','touch-down','long-touch','alarm'].includes(event);
  const logEntry = {
    timestamp:   new Date().toISOString(),
    event,
    device,
    user,
    battery:     parseInt(battery, 10) || 100,
    ldr:         parseInt(ldr,     10) || 2048,
    guardActive: guardModeActive,
  };

  if (guardModeActive || isSecurityAlert) addLog(logEntry);

  const payload = {
    event:       'alert',
    reason:      event,
    device,
    battery:     parseInt(battery, 10) || 100,
    ldr:         parseInt(ldr,     10) || 2048,
    guardActive: guardModeActive,
    deviceOnline: true,
    timestamp:   logEntry.timestamp,
  };

  const count = broadcast(payload);
  console.log(`[Broadcast] Sent alert to ${count} client(s).`);
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
