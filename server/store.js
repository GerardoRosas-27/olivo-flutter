'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function dataDir() {
  if (process.env.OLIVO_DATA_DIR) return process.env.OLIVO_DATA_DIR;
  if (fs.existsSync('/data') && canWrite('/data')) return '/data';
  return path.join(__dirname, 'data');
}

function canWrite(dir) {
  try {
    fs.accessSync(dir, fs.constants.W_OK);
    return true;
  } catch {
    return false;
  }
}

function nowIso() {
  return new Date().toISOString();
}

function emptyState() {
  return {
    users: {},
    weddings: {},
    guests: {},
    scan_events: [],
  };
}

/** JSON file store (default when no DATABASE_URL). */
class JsonStore {
  constructor(filePath) {
    this.filePath = filePath;
    this.state = emptyState();
  }

  async init() {
    const dir = path.dirname(this.filePath);
    fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(this.filePath)) {
      try {
        this.state = { ...emptyState(), ...JSON.parse(fs.readFileSync(this.filePath, 'utf8')) };
        this.state.users = this.state.users || {};
        this.state.weddings = this.state.weddings || {};
        this.state.guests = this.state.guests || {};
        this.state.scan_events = this.state.scan_events || [];
      } catch (e) {
        console.warn('olivo store: corrupt JSON, starting fresh', e.message);
        this.state = emptyState();
      }
    } else {
      this._persist();
    }
    console.log('olivo store: JSON at', this.filePath);
  }

  _persist() {
    const tmp = this.filePath + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(this.state, null, 0));
    fs.renameSync(tmp, this.filePath);
  }

  async upsertHost(userId, email) {
    this.state.users[userId] = {
      id: userId,
      email: email || this.state.users[userId]?.email || '',
      updatedAt: nowIso(),
    };
    this._persist();
  }

  async syncHost({ userId, email, wedding, guests }) {
    await this.upsertHost(userId, email);
    if (wedding) {
      const w = { ...wedding, userId };
      this.state.weddings[w.id] = w;
      // ensure one wedding per user: drop other weddings for same user
      for (const [id, existing] of Object.entries(this.state.weddings)) {
        if (existing.userId === userId && id !== w.id) {
          delete this.state.weddings[id];
        }
      }
    }
    if (Array.isArray(guests)) {
      const weddingId = wedding?.id;
      const keepIds = new Set(guests.map((g) => g.id));
      for (const [id, g] of Object.entries(this.state.guests)) {
        if (g.userId === userId || (weddingId && g.weddingId === weddingId)) {
          if (!keepIds.has(id)) delete this.state.guests[id];
        }
      }
      for (const g of guests) {
        this.state.guests[g.id] = { ...g, userId, weddingId: g.weddingId || weddingId };
      }
    }
    this._persist();
    return { ok: true, guests: guests?.length ?? 0 };
  }

  async getGuestByToken(token) {
    return Object.values(this.state.guests).find((g) => g.token === token) || null;
  }

  async getWedding(id) {
    return this.state.weddings[id] || null;
  }

  async publicInvitation(token) {
    const guest = await this.getGuestByToken(token);
    if (!guest) return null;
    if (guest.discardedAt) return { reason: 'discarded' };
    const wedding = await this.getWedding(guest.weddingId);
    if (!wedding) return null;
    const partySize = Number(guest.partySize) || 1;
    const checkedInCount = Number(guest.checkedInCount) || 0;
    return {
      ok: true,
      guestName: guest.name,
      partySize,
      remaining: Math.max(0, partySize - checkedInCount),
      rsvp: guest.rsvp || 'unknown',
      discarded: false,
      cloned: !!guest.cloneFlaggedAt,
      checkedIn: checkedInCount > 0 || !!guest.checkedInAt,
      checkedInCount,
      wedding: publicWedding(wedding),
      guest: publicGuest(guest),
    };
  }

  async openInvitation(token, deviceId) {
    const guest = await this.getGuestByToken(token);
    if (!guest) return { ok: false, reason: 'missing' };
    if (guest.discardedAt) return { ok: false, reason: 'discarded' };
    const now = nowIso();
    let cloned = !!guest.cloneFlaggedAt;
    if (guest.boundDeviceId && guest.boundDeviceId !== deviceId) {
      cloned = true;
      guest.cloneFlaggedAt = guest.cloneFlaggedAt || now;
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
    } else {
      guest.boundDeviceId = guest.boundDeviceId || deviceId;
      guest.firstViewedAt = guest.firstViewedAt || now;
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
    }
    this.state.guests[guest.id] = guest;
    this._addScan({
      guestId: guest.id,
      guestName: guest.name,
      kind: 'invite',
      deviceId: deviceId || '',
      outcome: cloned ? 'cloned' : 'viewed',
    });
    this._persist();
    if (cloned) return { ok: false, reason: 'cloned' };
    return this.publicInvitation(token);
  }

  async submitRsvp(token, response, deviceId) {
    const opened = await this.openInvitation(token, deviceId || 'rsvp');
    if (!opened || opened.ok !== true) return opened || { ok: false, reason: 'missing' };
    const guest = await this.getGuestByToken(token);
    if (!guest || guest.discardedAt || guest.cloneFlaggedAt) {
      return { ok: false, reason: guest?.cloneFlaggedAt ? 'cloned' : 'missing' };
    }
    const rsvp = response === 'yes' || response === 'no' ? response : 'unknown';
    guest.rsvp = rsvp;
    guest.rsvpAt = nowIso();
    this.state.guests[guest.id] = guest;
    this._persist();
    const pub = await this.publicInvitation(token);
    return { ...pub, rsvp };
  }

  async doorScan({ token, hostUserId, deviceId }) {
    const guest = await this.getGuestByToken(token);
    if (!guest) return { outcome: 'missing' };
    if (hostUserId && guest.userId && guest.userId !== hostUserId) {
      return { outcome: 'missing' };
    }
    const now = nowIso();
    let outcome;
    if (guest.discardedAt) {
      outcome = 'discarded';
    } else if (guest.cloneFlaggedAt) {
      outcome = 'cloned';
    } else if ((Number(guest.checkedInCount) || 0) >= (Number(guest.partySize) || 1)) {
      outcome = 'full';
    } else {
      guest.checkedInCount = (Number(guest.checkedInCount) || 0) + 1;
      guest.checkedInAt = guest.checkedInAt || now;
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
      this.state.guests[guest.id] = guest;
      outcome = 'checked_in';
    }
    this._addScan({
      guestId: guest.id,
      guestName: guest.name,
      kind: 'door',
      deviceId: deviceId || '',
      outcome,
    });
    this._persist();
    return {
      outcome,
      guest: publicGuest(guest),
    };
  }

  _addScan(partial) {
    const ev = {
      id: 'sc_' + crypto.randomBytes(8).toString('hex'),
      guestId: partial.guestId,
      guestName: partial.guestName || '',
      kind: partial.kind,
      deviceId: partial.deviceId || '',
      outcome: partial.outcome,
      createdAt: nowIso(),
    };
    this.state.scan_events.unshift(ev);
    if (this.state.scan_events.length > 500) {
      this.state.scan_events = this.state.scan_events.slice(0, 500);
    }
  }
}

function publicWedding(w) {
  return {
    id: w.id,
    userId: w.userId,
    partnerOne: w.partnerOne || '',
    partnerTwo: w.partnerTwo || '',
    weddingDate: w.weddingDate || null,
    weddingTime: w.weddingTime || '',
    venueName: w.venueName || '',
    venueAddress: w.venueAddress || '',
    venueMapsUrl: w.venueMapsUrl || '',
    dressCode: w.dressCode || '',
    story: w.story || '',
    welcomeNote: w.welcomeNote || '',
    schedule: Array.isArray(w.schedule) ? w.schedule : [],
    whatsappTemplate: w.whatsappTemplate || '',
    rsvpDeadline: w.rsvpDeadline || null,
  };
}

function publicGuest(g) {
  return {
    id: g.id,
    weddingId: g.weddingId,
    name: g.name || '',
    phone: g.phone || '',
    partySize: Number(g.partySize) || 1,
    groupName: g.groupName || '',
    notes: g.notes || '',
    token: g.token,
    rsvp: g.rsvp || 'unknown',
    rsvpAt: g.rsvpAt || null,
    sentAt: g.sentAt || null,
    firstViewedAt: g.firstViewedAt || null,
    boundDeviceId: g.boundDeviceId || null,
    checkedInAt: g.checkedInAt || null,
    cloneFlaggedAt: g.cloneFlaggedAt || null,
    discardedAt: g.discardedAt || null,
    scanCount: Number(g.scanCount) || 0,
    checkedInCount: Number(g.checkedInCount) || 0,
    createdAt: g.createdAt || '',
  };
}

/** Postgres store when DATABASE_URL is set. */
class PgStore {
  constructor(pool) {
    this.pool = pool;
  }

  async init() {
    await this.pool.query(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS weddings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL UNIQUE,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS guests (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  wedding_id TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS guests_token_idx ON guests (token);
CREATE INDEX IF NOT EXISTS guests_user_idx ON guests (user_id);
CREATE TABLE IF NOT EXISTS scan_events (
  id TEXT PRIMARY KEY,
  guest_id TEXT NOT NULL,
  guest_name TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL,
  device_id TEXT NOT NULL DEFAULT '',
  outcome TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`);
    console.log('olivo store: Postgres via DATABASE_URL');
  }

  async upsertHost(userId, email) {
    await this.pool.query(
      `INSERT INTO users (id, email, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (id) DO UPDATE SET email = COALESCE(NULLIF($2, ''), users.email), updated_at = NOW()`,
      [userId, email || ''],
    );
  }

  async syncHost({ userId, email, wedding, guests }) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO users (id, email, updated_at) VALUES ($1, $2, NOW())
         ON CONFLICT (id) DO UPDATE SET email = COALESCE(NULLIF($2, ''), users.email), updated_at = NOW()`,
        [userId, email || ''],
      );
      if (wedding) {
        const w = { ...wedding, userId };
        await client.query(
          `INSERT INTO weddings (id, user_id, data, updated_at) VALUES ($1, $2, $3::jsonb, NOW())
           ON CONFLICT (id) DO UPDATE SET user_id = $2, data = $3::jsonb, updated_at = NOW()`,
          [w.id, userId, JSON.stringify(w)],
        );
        await client.query(
          `DELETE FROM weddings WHERE user_id = $1 AND id <> $2`,
          [userId, w.id],
        );
      }
      if (Array.isArray(guests)) {
        const weddingId = wedding?.id;
        const ids = guests.map((g) => g.id);
        if (ids.length === 0) {
          await client.query(`DELETE FROM guests WHERE user_id = $1`, [userId]);
        } else {
          await client.query(
            `DELETE FROM guests WHERE user_id = $1 AND NOT (id = ANY($2::text[]))`,
            [userId, ids],
          );
        }
        for (const g of guests) {
          const row = { ...g, userId, weddingId: g.weddingId || weddingId };
          await client.query(
            `INSERT INTO guests (id, user_id, wedding_id, token, data, updated_at)
             VALUES ($1, $2, $3, $4, $5::jsonb, NOW())
             ON CONFLICT (id) DO UPDATE SET
               user_id = $2, wedding_id = $3, token = $4, data = $5::jsonb, updated_at = NOW()`,
            [row.id, userId, row.weddingId, row.token, JSON.stringify(row)],
          );
        }
      }
      await client.query('COMMIT');
      return { ok: true, guests: guests?.length ?? 0 };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async _guestRow(token) {
    const r = await this.pool.query(
      `SELECT id, user_id, wedding_id, token, data FROM guests WHERE token = $1 LIMIT 1`,
      [token],
    );
    if (!r.rows.length) return null;
    const row = r.rows[0];
    return { ...row.data, id: row.id, userId: row.user_id, weddingId: row.wedding_id, token: row.token };
  }

  async _saveGuest(guest) {
    await this.pool.query(
      `UPDATE guests SET data = $2::jsonb, token = $3, wedding_id = $4, user_id = $5, updated_at = NOW()
       WHERE id = $1`,
      [guest.id, JSON.stringify(guest), guest.token, guest.weddingId, guest.userId],
    );
  }

  async getWedding(id) {
    const r = await this.pool.query(`SELECT data FROM weddings WHERE id = $1`, [id]);
    return r.rows[0]?.data || null;
  }

  async publicInvitation(token) {
    const guest = await this._guestRow(token);
    if (!guest) return null;
    if (guest.discardedAt) return { reason: 'discarded' };
    const wedding = await this.getWedding(guest.weddingId);
    if (!wedding) return null;
    const partySize = Number(guest.partySize) || 1;
    const checkedInCount = Number(guest.checkedInCount) || 0;
    return {
      ok: true,
      guestName: guest.name,
      partySize,
      remaining: Math.max(0, partySize - checkedInCount),
      rsvp: guest.rsvp || 'unknown',
      discarded: false,
      cloned: !!guest.cloneFlaggedAt,
      checkedIn: checkedInCount > 0 || !!guest.checkedInAt,
      checkedInCount,
      wedding: publicWedding(wedding),
      guest: publicGuest(guest),
    };
  }

  async _addScan(partial) {
    const id = 'sc_' + crypto.randomBytes(8).toString('hex');
    await this.pool.query(
      `INSERT INTO scan_events (id, guest_id, guest_name, kind, device_id, outcome, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
      [id, partial.guestId, partial.guestName || '', partial.kind, partial.deviceId || '', partial.outcome],
    );
  }

  async openInvitation(token, deviceId) {
    const guest = await this._guestRow(token);
    if (!guest) return { ok: false, reason: 'missing' };
    if (guest.discardedAt) return { ok: false, reason: 'discarded' };
    const now = nowIso();
    let cloned = !!guest.cloneFlaggedAt;
    if (guest.boundDeviceId && guest.boundDeviceId !== deviceId) {
      cloned = true;
      guest.cloneFlaggedAt = guest.cloneFlaggedAt || now;
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
    } else {
      guest.boundDeviceId = guest.boundDeviceId || deviceId;
      guest.firstViewedAt = guest.firstViewedAt || now;
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
    }
    await this._saveGuest(guest);
    await this._addScan({
      guestId: guest.id,
      guestName: guest.name,
      kind: 'invite',
      deviceId: deviceId || '',
      outcome: cloned ? 'cloned' : 'viewed',
    });
    if (cloned) return { ok: false, reason: 'cloned' };
    return this.publicInvitation(token);
  }

  async submitRsvp(token, response, deviceId) {
    const opened = await this.openInvitation(token, deviceId || 'rsvp');
    if (!opened || opened.ok !== true) return opened || { ok: false, reason: 'missing' };
    const guest = await this._guestRow(token);
    if (!guest || guest.discardedAt || guest.cloneFlaggedAt) {
      return { ok: false, reason: guest?.cloneFlaggedAt ? 'cloned' : 'missing' };
    }
    const rsvp = response === 'yes' || response === 'no' ? response : 'unknown';
    guest.rsvp = rsvp;
    guest.rsvpAt = nowIso();
    await this._saveGuest(guest);
    const pub = await this.publicInvitation(token);
    return { ...pub, rsvp };
  }

  async doorScan({ token, hostUserId, deviceId }) {
    const guest = await this._guestRow(token);
    if (!guest) return { outcome: 'missing' };
    if (hostUserId && guest.userId && guest.userId !== hostUserId) {
      return { outcome: 'missing' };
    }
    let outcome;
    if (guest.discardedAt) {
      outcome = 'discarded';
    } else if (guest.cloneFlaggedAt) {
      outcome = 'cloned';
    } else if ((Number(guest.checkedInCount) || 0) >= (Number(guest.partySize) || 1)) {
      outcome = 'full';
    } else {
      guest.checkedInCount = (Number(guest.checkedInCount) || 0) + 1;
      guest.checkedInAt = guest.checkedInAt || nowIso();
      guest.scanCount = (Number(guest.scanCount) || 0) + 1;
      await this._saveGuest(guest);
      outcome = 'checked_in';
    }
    await this._addScan({
      guestId: guest.id,
      guestName: guest.name,
      kind: 'door',
      deviceId: deviceId || '',
      outcome,
    });
    return { outcome, guest: publicGuest(guest) };
  }
}

async function createStore() {
  const url = process.env.DATABASE_URL;
  if (url) {
    const { Pool } = require('pg');
    const pool = new Pool({
      connectionString: url,
      ssl: url.includes('localhost') ? false : { rejectUnauthorized: false },
    });
    const store = new PgStore(pool);
    await store.init();
    return store;
  }
  const file = path.join(dataDir(), 'olivo.json');
  const store = new JsonStore(file);
  await store.init();
  return store;
}

module.exports = { createStore, publicWedding, publicGuest };
