'use strict';

const express = require('express');
const fs = require('fs');
const path = require('path');
const { createStore } = require('./store');

const app = express();
const PORT = Number(process.env.PORT) || 8080;
const publicDir = path.join(__dirname, 'public');
const downloadsDir = path.join(__dirname, 'downloads');

app.use(express.json({ limit: '2mb' }));

// CORS open for app origins (mobile APK + web)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Host-User-Id, X-Host-Email',
  );
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  next();
});

function sendDownload(res, filePath, contentType, filename) {
  if (!fs.existsSync(filePath)) {
    res.status(404).type('text/plain').send('Archivo no disponible en este despliegue.');
    return;
  }
  res.setHeader('Content-Type', contentType);
  res.setHeader('Content-Disposition', 'attachment; filename="' + filename + '"');
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.sendFile(filePath);
}

function hostFromReq(req) {
  const auth = req.get('Authorization') || '';
  const bearer = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  const userId =
    bearer ||
    req.get('X-Host-User-Id') ||
    (req.body && (req.body.hostUserId || req.body.userId)) ||
    '';
  const email =
    req.get('X-Host-Email') ||
    (req.body && req.body.email) ||
    '';
  return { userId: String(userId || '').trim(), email: String(email || '').trim() };
}

async function main() {
  const store = await createStore();

  app.get('/api/health', (_req, res) => {
    res.json({ ok: true, service: 'olivo', version: '1.1.0' });
  });

  /** Upsert wedding + guests for a host. Auth: Bearer <hostUserId>. */
  async function handleHostSync(req, res) {
    try {
      const { userId, email } = hostFromReq(req);
      if (!userId) {
        res.status(401).json({ ok: false, error: 'missing_host' });
        return;
      }
      const wedding = req.body?.wedding || null;
      const guests = req.body?.guests || [];
      if (wedding && wedding.userId && wedding.userId !== userId) {
        res.status(403).json({ ok: false, error: 'wedding_user_mismatch' });
        return;
      }
      const result = await store.syncHost({
        userId,
        email,
        wedding,
        guests: Array.isArray(guests) ? guests : [],
      });
      res.json({ ok: true, ...result });
    } catch (e) {
      console.error('host sync', e);
      res.status(500).json({ ok: false, error: 'sync_failed', message: String(e.message || e) });
    }
  }

  app.put('/api/host/sync', handleHostSync);
  app.post('/api/host/sync', handleHostSync);

  app.get('/api/public/invitation/:token', async (req, res) => {
    try {
      const token = decodeURIComponent(req.params.token || '').trim();
      if (!token) {
        res.status(404).json({ ok: false, reason: 'missing' });
        return;
      }
      const open = String(req.query.open || '') === '1';
      const deviceId = String(req.query.deviceId || req.get('X-Device-Id') || '');
      let data;
      if (open && deviceId) {
        data = await store.openInvitation(token, deviceId);
      } else {
        data = await store.publicInvitation(token);
      }
      if (!data) {
        res.status(404).json({ ok: false, reason: 'missing' });
        return;
      }
      if (data.reason === 'discarded') {
        res.status(410).json({ ok: false, reason: 'discarded' });
        return;
      }
      if (data.ok === false) {
        const code = data.reason === 'cloned' ? 409 : 404;
        res.status(code).json(data);
        return;
      }
      res.json(data);
    } catch (e) {
      console.error('public invitation', e);
      res.status(500).json({ ok: false, error: 'server' });
    }
  });

  app.post('/api/public/rsvp', async (req, res) => {
    try {
      const token = String(req.body?.token || '').trim();
      const response = String(req.body?.response || req.body?.rsvp || '').trim();
      const deviceId = String(req.body?.deviceId || '').trim();
      if (!token) {
        res.status(400).json({ ok: false, reason: 'missing' });
        return;
      }
      const data = await store.submitRsvp(token, response, deviceId);
      if (!data || data.ok === false) {
        const reason = data?.reason || 'missing';
        const code = reason === 'cloned' ? 409 : reason === 'discarded' ? 410 : 404;
        res.status(code).json({ ok: false, reason });
        return;
      }
      res.json(data);
    } catch (e) {
      console.error('rsvp', e);
      res.status(500).json({ ok: false, error: 'server' });
    }
  });

  app.post('/api/door/scan', async (req, res) => {
    try {
      const token = String(req.body?.token || '').trim();
      const hostUserId = String(
        req.body?.hostUserId || hostFromReq(req).userId || '',
      ).trim();
      const deviceId = String(req.body?.deviceId || '').trim();
      if (!token) {
        res.status(400).json({ outcome: 'missing' });
        return;
      }
      const result = await store.doorScan({ token, hostUserId, deviceId });
      res.json(result);
    } catch (e) {
      console.error('door scan', e);
      res.status(500).json({ outcome: 'missing', error: 'server' });
    }
  });

  app.get('/downloads/olivo.apk', (req, res) => {
    sendDownload(
      res,
      path.join(downloadsDir, 'olivo.apk'),
      'application/vnd.android.package-archive',
      'olivo.apk',
    );
  });

  app.get('/downloads/olivo-android.zip', (req, res) => {
    sendDownload(
      res,
      path.join(downloadsDir, 'olivo-android.zip'),
      'application/zip',
      'olivo-android.zip',
    );
  });

  app.get('/downloads/olivo-ios.zip', (req, res) => {
    sendDownload(
      res,
      path.join(downloadsDir, 'olivo-ios.zip'),
      'application/zip',
      'olivo-ios.zip',
    );
  });

  if (fs.existsSync(publicDir)) {
    app.use(express.static(publicDir, { index: 'index.html' }));
    app.get('*', (req, res, next) => {
      if (req.path.startsWith('/api/')) {
        next();
        return;
      }
      res.sendFile(path.join(publicDir, 'index.html'));
    });
  } else {
    app.get('/', (_req, res) => {
      res.type('text/plain').send('olivo-flutter API (no SPA build in this image yet)');
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log('olivo-flutter listening on 0.0.0.0:' + PORT);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
