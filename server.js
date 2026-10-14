const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8085;
const BASE_DIR = __dirname;
const DB_FILE = path.join(BASE_DIR, 'driving_care_db.json');

// Ensure database exists
function getDb() {
  try {
    if (!fs.existsSync(DB_FILE)) {
      const initial = {
        drivers: [
          {
            key: 'DC-8921',
            name: 'Tariq Al-Harbi',
            phone: '+966 50 491 8821',
            city: 'Riyadh',
            status: 'active',
            daysLeft: 30,
            activeUntil: Date.now() + 30 * 24 * 60 * 60 * 1000,
            online: false,
            lastPing: null,
            ip: null,
            device: null
          },
          {
            key: 'BILAL-VIP',
            name: 'Bilal (Owner Admin)',
            phone: '+966 53 419 9549',
            city: 'Saudi Arabia',
            status: 'active',
            daysLeft: 365,
            activeUntil: Date.now() + 365 * 24 * 60 * 60 * 1000,
            online: false,
            lastPing: null,
            ip: null,
            device: null
          }
        ],
        logs: []
      };
      fs.writeFileSync(DB_FILE, JSON.stringify(initial, null, 2));
      return initial;
    }
    return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
  } catch (e) {
    console.error('DB Error:', e);
    return { drivers: [], logs: [] };
  }
}

function saveDb(data) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
  } catch (e) {
    console.error('Error saving DB:', e);
  }
}

const MIME_TYPES = {
  '.html': 'text/html; charset=UTF-8',
  '.css': 'text/css; charset=UTF-8',
  '.js': 'application/javascript; charset=UTF-8',
  '.json': 'application/json; charset=UTF-8',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.apk': 'application/vnd.android.package-archive'
};

const server = http.createServer((req, res) => {
  // CORS Headers so any mobile device or cloudflare tunnel can connect
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
  const urlParts = req.url.split('?');
  const pathname = decodeURI(urlParts[0]);

  // --- API 1: VERIFY KEY / LOGIN ---
  if (req.method === 'POST' && pathname === '/api/login') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const key = (payload.key || '').trim().toUpperCase();
        const device = payload.device || 'Android Device';
        const db = getDb();

        const driver = db.drivers.find(d => d.key === key);
        if (driver) {
          driver.online = true;
          driver.lastPing = new Date().toISOString();
          driver.ip = clientIp;
          driver.device = device;
          
          db.logs.unshift({
            event: 'Driver Logged In',
            name: driver.name,
            key: driver.key,
            device: device,
            ip: clientIp,
            timestamp: new Date().toLocaleTimeString()
          });
          if (db.logs.length > 50) db.logs.pop();
          saveDb(db);

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: true,
            driver: {
              name: driver.name,
              key: driver.key,
              daysLeft: driver.daysLeft,
              city: driver.city,
              status: driver.status
            }
          }));
        } else {
          // Log failed login
          db.logs.unshift({
            event: 'Failed Login Attempt',
            name: 'Unknown',
            key: key,
            device: device,
            ip: clientIp,
            timestamp: new Date().toLocaleTimeString()
          });
          if (db.logs.length > 50) db.logs.pop();
          saveDb(db);

          res.writeHead(403, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, message: 'Invalid or Expired License Key' }));
        }
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Bad Request' }));
      }
    });
    return;
  }

  // --- API 2: HEARTBEAT / PING ---
  if (req.method === 'POST' && pathname === '/api/ping') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const key = (payload.key || '').trim().toUpperCase();
        const db = getDb();
        const driver = db.drivers.find(d => d.key === key);
        if (driver) {
          driver.online = true;
          driver.lastPing = new Date().toISOString();
          driver.ip = clientIp;
          saveDb(db);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: true, status: driver.status, daysLeft: driver.daysLeft }));
        } else {
          res.writeHead(404, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false }));
        }
      } catch (e) {
        res.writeHead(400); res.end();
      }
    });
    return;
  }

  // --- API 2B: TRIAL ACTIVATION ---
  if (req.method === 'POST' && pathname === '/api/trial') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const device = payload.device || 'Android Device';
        const db = getDb();
        const trialKey = `TRIAL-${Math.floor(1000 + Math.random() * 9000)}`;
        const driver = {
          key: trialKey,
          name: payload.name || `Trial User (${device.substring(0, 15)})`,
          phone: payload.phone || '+966 50 Trial',
          city: payload.city || 'Riyadh',
          status: 'trial',
          daysLeft: 2,
          activeUntil: Date.now() + 2 * 24 * 60 * 60 * 1000,
          online: true,
          lastPing: new Date().toISOString(),
          ip: clientIp,
          device: device
        };
        db.drivers.push(driver);
        db.logs.unshift({
          event: '2-Day Trial Activated',
          name: driver.name,
          key: driver.key,
          device: device,
          ip: clientIp,
          timestamp: new Date().toLocaleTimeString()
        });
        if (db.logs.length > 50) db.logs.pop();
        saveDb(db);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: true,
          driver: {
            name: driver.name,
            key: driver.key,
            daysLeft: driver.daysLeft,
            city: driver.city,
            status: driver.status
          }
        }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Bad Request' }));
      }
    });
    return;
  }

  // --- API 2C: APPLY SETTINGS SYNC ---
  if (req.method === 'POST' && pathname === '/api/settings') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const key = (payload.key || '').trim().toUpperCase();
        const db = getDb();
        const driver = db.drivers.find(d => d.key === key);
        if (driver) {
          driver.settings = payload.settings;
          driver.lastPing = new Date().toISOString();
          driver.ip = clientIp;
        }
        db.logs.unshift({
          event: 'Settings Applied',
          name: driver ? driver.name : 'Saudi Driver',
          key: key || 'ACTIVE',
          device: payload.device || 'Android Device',
          ip: clientIp,
          timestamp: new Date().toLocaleTimeString()
        });
        if (db.logs.length > 50) db.logs.pop();
        saveDb(db);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, message: 'Settings saved' }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false }));
      }
    });
    return;
  }

  // --- API 3: GET ADMIN DASHBOARD DATA ---
  if (req.method === 'GET' && pathname === '/api/admin/drivers') {
    const db = getDb();
    // Auto offline if no ping in 60 seconds
    const now = Date.now();
    db.drivers.forEach(d => {
      if (d.lastPing) {
        const last = new Date(d.lastPing).getTime();
        if (now - last > 60000) d.online = false;
      } else {
        d.online = false;
      }
    });
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      drivers: db.drivers,
      logs: db.logs,
      serverTime: new Date().toISOString()
    }));
    return;
  }

  // --- API 4: ADMIN CREATE KEY ---
  if (req.method === 'POST' && pathname === '/api/admin/create-key') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const db = getDb();
        const newKey = payload.key || `DC-${Math.floor(1000 + Math.random() * 9000)}`;
        const driver = {
          key: newKey.toUpperCase(),
          name: payload.name || 'New Saudi Driver',
          phone: payload.phone || '+966 50 000 0000',
          city: payload.city || 'Riyadh',
          status: 'active',
          daysLeft: parseInt(payload.days || 30, 10),
          activeUntil: Date.now() + parseInt(payload.days || 30, 10) * 24 * 60 * 60 * 1000,
          online: false,
          lastPing: null,
          ip: null,
          device: null
        };
        db.drivers.push(driver);
        db.logs.unshift({
          event: 'New Key Created',
          name: driver.name,
          key: driver.key,
          device: 'Admin',
          ip: clientIp,
          timestamp: new Date().toLocaleTimeString()
        });
        saveDb(db);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, driver }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Could not create key' }));
      }
    });
    return;
  }

  // --- STATIC FILE SERVING ---
  let reqUrl = pathname;
  if (reqUrl === '/') reqUrl = '/driving-care-portal/index.html';

  const filePath = path.join(BASE_DIR, reqUrl);
  if (!filePath.startsWith(BASE_DIR)) {
    res.writeHead(403); res.end('Forbidden'); return;
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('404 Not Found');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-cache' });
    fs.createReadStream(filePath).pipe(res);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`   DRIVING CARE MASTER SERVER (LOCAL & CLOUD TUNNEL)   `);
  console.log(`=======================================================`);
  console.log(`Local Access:   http://127.0.0.1:${PORT}/driving-care-portal/index.html`);
  console.log(`Network Access: http://192.168.1.2:${PORT}/driving-care-portal/index.html`);
  console.log(`API Status:     LIVE (Listening on 0.0.0.0:${PORT})`);
  console.log(`=======================================================`);
});
