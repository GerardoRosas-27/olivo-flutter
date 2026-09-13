import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../../utils/ids.dart';
import '../api/olivo_api.dart';

/// Persistencia local + sync a API Railway (invitaciones públicas / escáner).
/// Local: SQLite (móvil/escritorio) o SharedPreferences JSON (web).
/// Remoto: PUT /api/host/sync → GET /api/public/invitation/:token.
class OlivoRepository {
  OlivoRepository({OlivoApi? api}) : api = api ?? OlivoApi();

  final OlivoApi api;
  Database? _db;
  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    if (kIsWeb) {
      await _ensureWebSeed();
    } else {
      await _openDb();
    }
    _ready = true;
  }

  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'olivo.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  email TEXT NOT NULL,
  user_id TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE weddings (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL UNIQUE,
  partner_one TEXT NOT NULL DEFAULT '',
  partner_two TEXT NOT NULL DEFAULT '',
  wedding_date TEXT,
  wedding_time TEXT NOT NULL DEFAULT '',
  venue_name TEXT NOT NULL DEFAULT '',
  venue_address TEXT NOT NULL DEFAULT '',
  venue_maps_url TEXT NOT NULL DEFAULT '',
  dress_code TEXT NOT NULL DEFAULT '',
  story TEXT NOT NULL DEFAULT '',
  welcome_note TEXT NOT NULL DEFAULT '',
  schedule_json TEXT NOT NULL DEFAULT '[]',
  whatsapp_template TEXT NOT NULL DEFAULT '',
  rsvp_deadline TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''');
        await db.execute('''
CREATE TABLE guests (
  id TEXT PRIMARY KEY NOT NULL,
  wedding_id TEXT NOT NULL,
  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  party_size INTEGER NOT NULL DEFAULT 1,
  group_name TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  token TEXT NOT NULL UNIQUE,
  rsvp TEXT NOT NULL DEFAULT 'unknown',
  rsvp_at TEXT,
  sent_at TEXT,
  first_viewed_at TEXT,
  bound_device_id TEXT,
  checked_in_at TEXT,
  clone_flagged_at TEXT,
  discarded_at TEXT,
  scan_count INTEGER NOT NULL DEFAULT 0,
  checked_in_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)''');
        await db.execute(
            'CREATE INDEX guests_wedding_id_idx ON guests (wedding_id)');
        await db.execute('CREATE INDEX guests_token_idx ON guests (token)');
        await db.execute('''
CREATE TABLE scan_events (
  id TEXT PRIMARY KEY NOT NULL,
  guest_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  device_id TEXT NOT NULL DEFAULT '',
  outcome TEXT NOT NULL,
  created_at TEXT NOT NULL
)''');
        await _seedSqlite(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE guests ADD COLUMN checked_in_count INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE guests SET checked_in_count = 1 '
            'WHERE checked_in_at IS NOT NULL AND checked_in_count = 0',
          );
        }
      },
    );
    return _db!;
  }

  Future<void> _seedSqlite(Database db) async {
    final now = nowIso();
    final scheduleJson = jsonEncode(defaultSchedule.map((e) => e.toJson()).toList());
    await db.insert('weddings', {
      'id': 'wd_demo',
      'user_id': 'demo-seed',
      'partner_one': 'Ana',
      'partner_two': 'Mateo',
      'wedding_date': '2026-11-14',
      'wedding_time': '16:00',
      'venue_name': 'Hacienda San Gabriel',
      'venue_address': 'Tepoztlán, Morelos',
      'venue_maps_url':
          'https://maps.google.com/?q=Hacienda+San+Gabriel+Tepoztlan',
      'dress_code': 'Formal de jardín. Lino, paleta tierra, sin blanco.',
      'story':
          'Nos conocimos entre naranjos y decidimos volver a ellos. Esta vez, para siempre.',
      'welcome_note':
          'Con el corazón abierto, queremos que este día se sienta como casa.',
      'schedule_json': scheduleJson,
      'whatsapp_template': defaultTemplate,
      'rsvp_deadline': '2026-10-20',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('guests', {
      'id': 'g_demo_ana',
      'wedding_id': 'wd_demo',
      'name': 'Ana Ruiz',
      'phone': '7771234567',
      'party_size': 2,
      'group_name': 'Familia',
      'notes': 'Mesa 1',
      'token': 'demo-ana',
      'rsvp': 'unknown',
      'scan_count': 0,
      'checked_in_count': 0,
      'created_at': now,
    });
    await db.insert('guests', {
      'id': 'g_demo_clone',
      'wedding_id': 'wd_demo',
      'name': 'Invitado de prueba (clon)',
      'phone': '',
      'party_size': 1,
      'group_name': 'Prueba',
      'notes': '',
      'token': 'demo-clone',
      'rsvp': 'unknown',
      'scan_count': 0,
      'checked_in_count': 0,
      'created_at': now,
    });
  }

  // —— Web prefs ——
  static const _kWeddings = 'olivo_weddings_v1';
  static const _kGuests = 'olivo_guests_v1';
  static const _kScans = 'olivo_scans_v1';
  static const _kSession = 'olivo_session_v1';
  static const _kSeeded = 'olivo_seeded_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> _ensureWebSeed() async {
    final prefs = await _prefs;
    if (prefs.getBool(_kSeeded) == true) return;
    final now = nowIso();
    final wedding = Wedding(
      id: 'wd_demo',
      userId: 'demo-seed',
      partnerOne: 'Ana',
      partnerTwo: 'Mateo',
      weddingDate: '2026-11-14',
      weddingTime: '16:00',
      venueName: 'Hacienda San Gabriel',
      venueAddress: 'Tepoztlán, Morelos',
      venueMapsUrl: 'https://maps.google.com/?q=Hacienda+San+Gabriel+Tepoztlan',
      dressCode: 'Formal de jardín. Lino, paleta tierra, sin blanco.',
      story:
          'Nos conocimos entre naranjos y decidimos volver a ellos. Esta vez, para siempre.',
      welcomeNote:
          'Con el corazón abierto, queremos que este día se sienta como casa.',
      schedule: defaultSchedule,
      whatsappTemplate: defaultTemplate,
      rsvpDeadline: '2026-10-20',
    );
    final guests = [
      Guest(
        id: 'g_demo_ana',
        weddingId: 'wd_demo',
        name: 'Ana Ruiz',
        phone: '7771234567',
        partySize: 2,
        groupName: 'Familia',
        notes: 'Mesa 1',
        token: 'demo-ana',
        rsvp: 'unknown',
        scanCount: 0,
        checkedInCount: 0,
        createdAt: now,
      ),
      Guest(
        id: 'g_demo_clone',
        weddingId: 'wd_demo',
        name: 'Invitado de prueba (clon)',
        phone: '',
        partySize: 1,
        groupName: 'Prueba',
        notes: '',
        token: 'demo-clone',
        rsvp: 'unknown',
        scanCount: 0,
        checkedInCount: 0,
        createdAt: now,
      ),
    ];
    await prefs.setString(_kWeddings, jsonEncode([wedding.toJson()]));
    await prefs.setString(
        _kGuests, jsonEncode(guests.map((g) => g.toJson()).toList()));
    await prefs.setString(_kScans, '[]');
    await prefs.setBool(_kSeeded, true);
  }

  Future<List<Wedding>> _webWeddings() async {
    final raw = (await _prefs).getString(_kWeddings);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Wedding.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _saveWebWeddings(List<Wedding> list) async {
    await (await _prefs)
        .setString(_kWeddings, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<List<Guest>> _webGuests() async {
    final raw = (await _prefs).getString(_kGuests);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Guest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _saveWebGuests(List<Guest> list) async {
    await (await _prefs)
        .setString(_kGuests, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<List<ScanEvent>> _webScans() async {
    final raw = (await _prefs).getString(_kScans);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ScanEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _saveWebScans(List<ScanEvent> list) async {
    await (await _prefs)
        .setString(_kScans, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // —— Session (email-only) ——
  Future<SessionUser?> getSession() async {
    await ensureReady();
    if (kIsWeb) {
      final raw = (await _prefs).getString(_kSession);
      if (raw == null || raw.isEmpty) return null;
      try {
        return SessionUser.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        return null;
      }
    }
    final db = await _openDb();
    final rows = await db.query('sessions', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return SessionUser(
      email: rows.first['email'] as String,
      userId: rows.first['user_id'] as String,
    );
  }

  Future<SessionUser> signInEmail(String email) async {
    await ensureReady();
    final trimmed = email.trim().toLowerCase();
    if (!_validEmail(trimmed)) {
      throw ArgumentError('Correo inválido');
    }
    final userId = 'u_${trimmed.hashCode.abs().toRadixString(16)}';
    final session = SessionUser(email: trimmed, userId: userId);
    if (kIsWeb) {
      await (await _prefs).setString(_kSession, jsonEncode(session.toJson()));
    } else {
      final db = await _openDb();
      await db.insert(
        'sessions',
        {'id': 1, 'email': trimmed, 'user_id': userId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await ensureWedding(userId);
    return session;
  }

  Future<void> signOut() async {
    await ensureReady();
    if (kIsWeb) {
      await (await _prefs).remove(_kSession);
    } else {
      final db = await _openDb();
      await db.delete('sessions');
    }
  }

  bool _validEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  // —— Wedding ——
  Wedding _weddingFromRow(Map<String, Object?> row) {
    List<ScheduleItem> schedule = defaultSchedule;
    final raw = row['schedule_json'] as String? ?? '[]';
    try {
      final parsed = jsonDecode(raw) as List;
      schedule = parsed
          .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
    return Wedding(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      partnerOne: row['partner_one'] as String? ?? '',
      partnerTwo: row['partner_two'] as String? ?? '',
      weddingDate: row['wedding_date'] as String?,
      weddingTime: row['wedding_time'] as String? ?? '',
      venueName: row['venue_name'] as String? ?? '',
      venueAddress: row['venue_address'] as String? ?? '',
      venueMapsUrl: row['venue_maps_url'] as String? ?? '',
      dressCode: row['dress_code'] as String? ?? '',
      story: row['story'] as String? ?? '',
      welcomeNote: row['welcome_note'] as String? ?? '',
      schedule: schedule,
      whatsappTemplate: (row['whatsapp_template'] as String?)?.isNotEmpty == true
          ? row['whatsapp_template'] as String
          : defaultTemplate,
      rsvpDeadline: row['rsvp_deadline'] as String?,
    );
  }

  Future<Wedding> ensureWedding(String userId) async {
    await ensureReady();
    if (kIsWeb) {
      final list = await _webWeddings();
      final existing = list.where((w) => w.userId == userId).firstOrNull;
      if (existing != null) return existing;
      // Claim demo wedding for first login if still demo-seed
      final demo = list.where((w) => w.userId == 'demo-seed').firstOrNull;
      if (demo != null) {
        final claimed = Wedding(
          id: demo.id,
          userId: userId,
          partnerOne: demo.partnerOne,
          partnerTwo: demo.partnerTwo,
          weddingDate: demo.weddingDate,
          weddingTime: demo.weddingTime,
          venueName: demo.venueName,
          venueAddress: demo.venueAddress,
          venueMapsUrl: demo.venueMapsUrl,
          dressCode: demo.dressCode,
          story: demo.story,
          welcomeNote: demo.welcomeNote,
          schedule: demo.schedule,
          whatsappTemplate: demo.whatsappTemplate,
          rsvpDeadline: demo.rsvpDeadline,
        );
        final next = list.map((w) => w.id == demo.id ? claimed : w).toList();
        await _saveWebWeddings(next);
        return claimed;
      }
      final w = Wedding(
        id: newId('wd'),
        userId: userId,
        partnerOne: '',
        partnerTwo: '',
        weddingTime: '',
        venueName: '',
        venueAddress: '',
        venueMapsUrl: '',
        dressCode: '',
        story: '',
        welcomeNote: '',
        schedule: defaultSchedule,
        whatsappTemplate: defaultTemplate,
      );
      list.add(w);
      await _saveWebWeddings(list);
      return w;
    }
    final db = await _openDb();
    final rows =
        await db.query('weddings', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (rows.isNotEmpty) return _weddingFromRow(rows.first);
    // Claim demo
    final demo = await db.query('weddings',
        where: 'user_id = ?', whereArgs: ['demo-seed'], limit: 1);
    if (demo.isNotEmpty) {
      await db.update('weddings', {'user_id': userId, 'updated_at': nowIso()},
          where: 'id = ?', whereArgs: [demo.first['id']]);
      final updated = await db.query('weddings',
          where: 'user_id = ?', whereArgs: [userId], limit: 1);
      return _weddingFromRow(updated.first);
    }
    final id = newId('wd');
    final now = nowIso();
    await db.insert('weddings', {
      'id': id,
      'user_id': userId,
      'partner_one': '',
      'partner_two': '',
      'wedding_time': '',
      'venue_name': '',
      'venue_address': '',
      'venue_maps_url': '',
      'dress_code': '',
      'story': '',
      'welcome_note': '',
      'schedule_json': jsonEncode(defaultSchedule.map((e) => e.toJson()).toList()),
      'whatsapp_template': defaultTemplate,
      'created_at': now,
      'updated_at': now,
    });
    final created =
        await db.query('weddings', where: 'id = ?', whereArgs: [id], limit: 1);
    return _weddingFromRow(created.first);
  }

  Future<Wedding> saveWedding(String userId, Wedding data) async {
    await ensureReady();
    final current = await ensureWedding(userId);
    final w = Wedding(
      id: current.id,
      userId: userId,
      partnerOne: data.partnerOne.trim(),
      partnerTwo: data.partnerTwo.trim(),
      weddingDate: data.weddingDate,
      weddingTime: data.weddingTime.trim(),
      venueName: data.venueName.trim(),
      venueAddress: data.venueAddress.trim(),
      venueMapsUrl: data.venueMapsUrl.trim(),
      dressCode: data.dressCode.trim(),
      story: data.story.trim(),
      welcomeNote: data.welcomeNote.trim(),
      schedule: data.schedule,
      whatsappTemplate:
          data.whatsappTemplate.trim().isEmpty ? defaultTemplate : data.whatsappTemplate.trim(),
      rsvpDeadline: data.rsvpDeadline,
    );
    if (kIsWeb) {
      final list = await _webWeddings();
      final next = list.map((x) => x.id == w.id ? w : x).toList();
      await _saveWebWeddings(next);
      await _syncQuiet(userId);
      return w;
    }
    final db = await _openDb();
    await db.update(
      'weddings',
      {
        'partner_one': w.partnerOne,
        'partner_two': w.partnerTwo,
        'wedding_date': w.weddingDate,
        'wedding_time': w.weddingTime,
        'venue_name': w.venueName,
        'venue_address': w.venueAddress,
        'venue_maps_url': w.venueMapsUrl,
        'dress_code': w.dressCode,
        'story': w.story,
        'welcome_note': w.welcomeNote,
        'schedule_json': jsonEncode(w.schedule.map((e) => e.toJson()).toList()),
        'whatsapp_template': w.whatsappTemplate,
        'rsvp_deadline': w.rsvpDeadline,
        'updated_at': nowIso(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [current.id, userId],
    );
    await _syncQuiet(userId);
    return w;
  }

  Guest _guestFromRow(Map<String, Object?> row) {
    final rsvp = row['rsvp'] as String? ?? 'unknown';
    return Guest(
      id: row['id'] as String,
      weddingId: row['wedding_id'] as String,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      partySize: (row['party_size'] as num?)?.toInt() ?? 1,
      groupName: row['group_name'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      token: row['token'] as String? ?? '',
      rsvp: (rsvp == 'yes' || rsvp == 'no') ? rsvp : 'unknown',
      rsvpAt: row['rsvp_at'] as String?,
      sentAt: row['sent_at'] as String?,
      firstViewedAt: row['first_viewed_at'] as String?,
      boundDeviceId: row['bound_device_id'] as String?,
      checkedInAt: row['checked_in_at'] as String?,
      cloneFlaggedAt: row['clone_flagged_at'] as String?,
      discardedAt: row['discarded_at'] as String?,
      scanCount: (row['scan_count'] as num?)?.toInt() ?? 0,
      checkedInCount: (row['checked_in_count'] as num?)?.toInt() ??
          ((row['checked_in_at'] != null) ? 1 : 0),
      createdAt: row['created_at'] as String? ?? '',
    );
  }

  Future<List<Guest>> listGuests(String userId) async {
    final wedding = await ensureWedding(userId);
    if (kIsWeb) {
      final list = await _webGuests();
      return list.where((g) => g.weddingId == wedding.id).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final db = await _openDb();
    final rows = await db.query(
      'guests',
      where: 'wedding_id = ?',
      whereArgs: [wedding.id],
      orderBy: 'created_at ASC',
    );
    return rows.map(_guestFromRow).toList();
  }

  Future<AdminStats> adminStats(String userId) async {
    final guests = await listGuests(userId);
    int sent = 0, viewed = 0, confirmed = 0, declined = 0, checkedIn = 0, clones = 0, expected = 0;
    for (final g in guests) {
      if (g.sentAt != null) sent++;
      if (g.firstViewedAt != null) viewed++;
      if (g.rsvp == 'yes') confirmed++;
      if (g.rsvp == 'no') declined++;
      if (g.checkedInCount > 0 || g.checkedInAt != null) checkedIn++;
      if (g.cloneFlaggedAt != null) clones++;
      if (g.discardedAt == null) expected += g.partySize;
    }
    return AdminStats(
      guests: guests.length,
      sent: sent,
      viewed: viewed,
      confirmed: confirmed,
      declined: declined,
      checkedIn: checkedIn,
      clones: clones,
      expected: expected,
    );
  }

  Future<Guest> addGuest(
    String userId, {
    required String name,
    String phone = '',
    int partySize = 1,
    String groupName = '',
    String notes = '',
  }) async {
    final wedding = await ensureWedding(userId);
    final guest = Guest(
      id: newId('g'),
      weddingId: wedding.id,
      name: name.trim(),
      phone: phone.trim(),
      partySize: partySize.clamp(1, 20),
      groupName: groupName.trim(),
      notes: notes.trim(),
      token: newToken(),
      rsvp: 'unknown',
      scanCount: 0,
      checkedInCount: 0,
      createdAt: nowIso(),
    );
    if (kIsWeb) {
      final list = await _webGuests();
      list.add(guest);
      await _saveWebGuests(list);
      await _syncQuiet(userId);
      return guest;
    }
    final db = await _openDb();
    await db.insert('guests', {
      'id': guest.id,
      'wedding_id': guest.weddingId,
      'name': guest.name,
      'phone': guest.phone,
      'party_size': guest.partySize,
      'group_name': guest.groupName,
      'notes': guest.notes,
      'token': guest.token,
      'rsvp': guest.rsvp,
      'scan_count': 0,
      'checked_in_count': 0,
      'created_at': guest.createdAt,
    });
    await _syncQuiet(userId);
    return guest;
  }

  Future<Guest?> _ownedGuest(String userId, String guestId) async {
    final guests = await listGuests(userId);
    return guests.where((g) => g.id == guestId).firstOrNull;
  }

  Future<Guest> updateGuest(
    String userId, {
    required String id,
    required String name,
    String phone = '',
    int partySize = 1,
    String groupName = '',
    String notes = '',
  }) async {
    final existing = await _ownedGuest(userId, id);
    if (existing == null) throw StateError('Invitado no encontrado');
    final updated = existing.copyWith(
      name: name.trim(),
      phone: phone.trim(),
      partySize: partySize.clamp(1, 20),
      groupName: groupName.trim(),
      notes: notes.trim(),
    );
    await _persistGuest(updated);
    await _syncQuiet(userId);
    return updated;
  }

  Future<void> _persistGuest(Guest g) async {
    if (kIsWeb) {
      final list = await _webGuests();
      final next = list.map((x) => x.id == g.id ? g : x).toList();
      await _saveWebGuests(next);
      return;
    }
    final db = await _openDb();
    await db.update(
      'guests',
      {
        'name': g.name,
        'phone': g.phone,
        'party_size': g.partySize,
        'group_name': g.groupName,
        'notes': g.notes,
        'token': g.token,
        'rsvp': g.rsvp,
        'rsvp_at': g.rsvpAt,
        'sent_at': g.sentAt,
        'first_viewed_at': g.firstViewedAt,
        'bound_device_id': g.boundDeviceId,
        'checked_in_at': g.checkedInAt,
        'clone_flagged_at': g.cloneFlaggedAt,
        'discarded_at': g.discardedAt,
        'scan_count': g.scanCount,
        'checked_in_count': g.checkedInCount,
      },
      where: 'id = ?',
      whereArgs: [g.id],
    );
  }

  Future<void> markGuestsSent(String userId, List<String> ids) async {
    final now = nowIso();
    for (final id in ids) {
      final g = await _ownedGuest(userId, id);
      if (g == null) continue;
      if (g.sentAt != null) continue;
      await _persistGuest(g.copyWith(sentAt: now));
    }
    await _syncQuiet(userId);
  }

  Future<Guest> discardGuest(String userId, String id) async {
    final existing = await _ownedGuest(userId, id);
    if (existing == null) throw StateError('Invitado no encontrado');
    final now = nowIso();
    final updated = existing.copyWith(discardedAt: now);
    await _persistGuest(updated);
    await _addScan(ScanEvent(
      id: newId('sc'),
      guestId: id,
      guestName: existing.name,
      kind: 'discard',
      deviceId: 'admin',
      outcome: 'discarded',
      createdAt: now,
    ));
    await _syncQuiet(userId);
    return updated;
  }

  Future<Guest> regenerateToken(String userId, String id) async {
    final existing = await _ownedGuest(userId, id);
    if (existing == null) throw StateError('Invitado no encontrado');
    final updated = Guest(
      id: existing.id,
      weddingId: existing.weddingId,
      name: existing.name,
      phone: existing.phone,
      partySize: existing.partySize,
      groupName: existing.groupName,
      notes: existing.notes,
      token: newToken(),
      rsvp: existing.rsvp,
      rsvpAt: existing.rsvpAt,
      sentAt: existing.sentAt,
      firstViewedAt: null,
      boundDeviceId: null,
      checkedInAt: existing.checkedInAt,
      cloneFlaggedAt: null,
      discardedAt: null,
      scanCount: 0,
      checkedInCount: 0,
      createdAt: existing.createdAt,
    );
    await _persistGuest(updated);
    await _syncQuiet(userId);
    return updated;
  }

  Future<Guest> markAttendance(String userId, String id) async {
    final existing = await _ownedGuest(userId, id);
    if (existing == null) throw StateError('Invitado no encontrado');
    if (existing.isQuotaFull) return existing;
    final nextCount = existing.checkedInCount + 1;
    final updated = existing.copyWith(
      checkedInAt: existing.checkedInAt ?? nowIso(),
      checkedInCount: nextCount,
      scanCount: existing.scanCount + 1,
    );
    await _persistGuest(updated);
    await _syncQuiet(userId);
    return updated;
  }

  Future<void> _addScan(ScanEvent e) async {
    if (kIsWeb) {
      final list = await _webScans();
      list.insert(0, e);
      await _saveWebScans(list.take(200).toList());
      return;
    }
    final db = await _openDb();
    await db.insert('scan_events', {
      'id': e.id,
      'guest_id': e.guestId,
      'kind': e.kind,
      'device_id': e.deviceId,
      'outcome': e.outcome,
      'created_at': e.createdAt,
    });
  }

  Future<List<ScanEvent>> listScanEvents(String userId) async {
    final wedding = await ensureWedding(userId);
    if (kIsWeb) {
      final guests = await _webGuests();
      final ids = guests
          .where((g) => g.weddingId == wedding.id)
          .map((g) => g.id)
          .toSet();
      final scans = await _webScans();
      return scans.where((s) => ids.contains(s.guestId)).take(40).toList();
    }
    final db = await _openDb();
    final rows = await db.rawQuery('''
SELECT e.id, e.guest_id, g.name as guest_name, e.kind, e.device_id, e.outcome, e.created_at
FROM scan_events e
JOIN guests g ON g.id = e.guest_id
WHERE g.wedding_id = ?
ORDER BY e.created_at DESC
LIMIT 40
''', [wedding.id]);
    return rows
        .map((r) => ScanEvent(
              id: r['id'] as String,
              guestId: r['guest_id'] as String,
              guestName: r['guest_name'] as String? ?? '',
              kind: r['kind'] as String? ?? '',
              deviceId: r['device_id'] as String? ?? '',
              outcome: r['outcome'] as String? ?? '',
              createdAt: r['created_at'] as String? ?? '',
            ))
        .toList();
  }

  Future<Guest?> guestByToken(String token) async {
    await ensureReady();
    if (kIsWeb) {
      final list = await _webGuests();
      return list.where((g) => g.token == token).firstOrNull;
    }
    final db = await _openDb();
    final rows =
        await db.query('guests', where: 'token = ?', whereArgs: [token], limit: 1);
    if (rows.isEmpty) return null;
    return _guestFromRow(rows.first);
  }

  Future<Wedding?> weddingById(String id) async {
    await ensureReady();
    if (kIsWeb) {
      final list = await _webWeddings();
      return list.where((w) => w.id == id).firstOrNull;
    }
    final db = await _openDb();
    final rows =
        await db.query('weddings', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _weddingFromRow(rows.first);
  }

  /// Peek without binding device. Prefers Railway API so any phone can open /i/:token.
  Future<Map<String, dynamic>> peekInvitation(String token) async {
    await ensureApiBase();
    if (api.isConfigured) {
      final remote = await api.getPublicInvitation(token);
      // Remote hit (ok or definitive discarded/cloned) wins; missing → try local.
      if (remote != null &&
          (remote['ok'] == true ||
              remote['reason'] == 'discarded' ||
              remote['reason'] == 'cloned')) {
        return remote;
      }
    }
    final guest = await guestByToken(token);
    if (guest == null) return {'ok': false, 'reason': 'missing'};
    if (guest.isDiscarded) return {'ok': false, 'reason': 'discarded'};
    final wedding = await weddingById(guest.weddingId);
    if (wedding == null) return {'ok': false, 'reason': 'missing'};
    return {
      'ok': true,
      'guestName': guest.name,
      'partySize': guest.partySize,
      'rsvp': guest.rsvp,
      'discarded': false,
      'cloned': guest.isCloned,
      'checkedIn': guest.isCheckedIn,
      'wedding': wedding,
      'guest': guest,
    };
  }

  Future<Map<String, dynamic>> openInvitation(String token, String deviceId) async {
    await ensureApiBase();
    if (api.isConfigured) {
      final remote = await api.getPublicInvitation(
        token,
        open: true,
        deviceId: deviceId,
      );
      if (remote != null &&
          (remote['ok'] == true ||
              remote['reason'] == 'discarded' ||
              remote['reason'] == 'cloned')) {
        return remote;
      }
    }
    final guest = await guestByToken(token);
    if (guest == null) return {'ok': false, 'reason': 'missing'};
    if (guest.isDiscarded) return {'ok': false, 'reason': 'discarded'};

    var cloned = guest.isCloned;
    Guest next;
    final now = nowIso();
    if (guest.boundDeviceId != null && guest.boundDeviceId != deviceId) {
      cloned = true;
      next = guest.copyWith(
        cloneFlaggedAt: guest.cloneFlaggedAt ?? now,
        scanCount: guest.scanCount + 1,
      );
    } else {
      next = guest.copyWith(
        boundDeviceId: guest.boundDeviceId ?? deviceId,
        firstViewedAt: guest.firstViewedAt ?? now,
        scanCount: guest.scanCount + 1,
      );
    }
    await _persistGuest(next);
    await _addScan(ScanEvent(
      id: newId('sc'),
      guestId: guest.id,
      guestName: guest.name,
      kind: 'invite',
      deviceId: deviceId,
      outcome: cloned ? 'cloned' : 'viewed',
      createdAt: now,
    ));
    if (cloned) return {'ok': false, 'reason': 'cloned'};
    final wedding = await weddingById(guest.weddingId);
    if (wedding == null) return {'ok': false, 'reason': 'missing'};
    return {
      'ok': true,
      'guestName': next.name,
      'partySize': next.partySize,
      'rsvp': next.rsvp,
      'discarded': false,
      'cloned': false,
      'checkedIn': next.isCheckedIn,
      'wedding': wedding,
      'guest': next,
    };
  }

  Future<Map<String, dynamic>> submitRsvp(
      String token, String deviceId, String rsvp) async {
    await ensureApiBase();
    if (api.isConfigured) {
      final remote = await api.submitRsvp(
        token: token,
        response: rsvp,
        deviceId: deviceId,
      );
      if (remote != null &&
          (remote['ok'] == true ||
              remote['reason'] == 'discarded' ||
              remote['reason'] == 'cloned')) {
        return remote;
      }
    }
    final opened = await openInvitation(token, deviceId);
    if (opened['ok'] != true) return opened;
    final guest = await guestByToken(token);
    if (guest == null || guest.isDiscarded || guest.isCloned) {
      return {'ok': false, 'reason': guest?.isCloned == true ? 'cloned' : 'missing'};
    }
    final updated = guest.copyWith(rsvp: rsvp, rsvpAt: nowIso());
    await _persistGuest(updated);
    return {...opened, 'rsvp': rsvp, 'guest': updated};
  }

  Future<DoorScanResult> scanDoor(
      String userId, String token, String deviceId) async {
    await ensureApiBase();
    if (api.isConfigured) {
      final remote = await api.doorScan(
        token: token,
        hostUserId: userId,
        deviceId: deviceId,
      );
      if (remote != null && remote.outcome != 'missing') {
        if (remote.guest != null) {
          try {
            await _persistGuest(remote.guest!);
          } catch (_) {}
        }
        return remote;
      }
      // outcome missing or null → try local (offline demo / not yet synced)
    }
    final wedding = await ensureWedding(userId);
    final guest = await guestByToken(token);
    if (guest == null || guest.weddingId != wedding.id) {
      return const DoorScanResult(outcome: 'missing');
    }
    String outcome;
    Guest latest = guest;
    final now = nowIso();
    if (guest.isDiscarded) {
      outcome = 'discarded';
    } else if (guest.isCloned) {
      outcome = 'cloned';
    } else if (guest.isQuotaFull) {
      // Cupo agotado — QR vencido.
      outcome = 'full';
    } else {
      final nextCount = guest.checkedInCount + 1;
      latest = guest.copyWith(
        checkedInAt: guest.checkedInAt ?? now,
        checkedInCount: nextCount,
        scanCount: guest.scanCount + 1,
      );
      await _persistGuest(latest);
      outcome = 'checked_in';
    }
    await _addScan(ScanEvent(
      id: newId('sc'),
      guestId: guest.id,
      guestName: guest.name,
      kind: 'door',
      deviceId: deviceId,
      outcome: outcome,
      createdAt: now,
    ));
    return DoorScanResult(outcome: outcome, guest: latest);
  }


  /// Conteos locales del dispositivo (honestos: no son globales del servicio).
  Future<DeviceLocalStats> deviceLocalStats() async {
    await ensureReady();
    if (kIsWeb) {
      final weddings = await _webWeddings();
      final guests = await _webGuests();
      final users = weddings.map((w) => w.userId).toSet().length;
      return DeviceLocalStats(
        weddings: weddings.length,
        guests: guests.length,
        users: users,
      );
    }
    final db = await _openDb();
    final weddings =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM weddings')) ??
            0;
    final guests =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM guests')) ??
            0;
    final users = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(DISTINCT user_id) FROM weddings'),
        ) ??
        0;
    return DeviceLocalStats(weddings: weddings, guests: guests, users: users);
  }


  /// Resolve API base from stored public URL (or same origin on web).
  Future<void> ensureApiBase() async {
    var base = await getPublicBaseUrl();
    if ((base == null || base.isEmpty) && kIsWeb) {
      if (Uri.base.hasScheme &&
          (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
        base = '${Uri.base.scheme}://${Uri.base.host}'
            '${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
      }
    }
    api.setBaseUrl(base);
  }

  /// Push local wedding + guests to Railway so /i/{token} works on any phone.
  Future<bool> syncToServer(String userId, {String? email}) async {
    await ensureReady();
    await ensureApiBase();
    if (!api.isConfigured) return false;
    final wedding = await ensureWedding(userId);
    final guests = await listGuests(userId);
    return api.syncHost(
      hostUserId: userId,
      email: email,
      wedding: wedding,
      guests: guests,
    );
  }

  Future<void> _syncQuiet(String userId) async {
    try {
      await syncToServer(userId);
    } catch (e) {
      debugPrint('sync quiet: $e');
    }
  }

  Future<String?> getPublicBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('olivo.publicBaseUrl');
  }

  Future<void> setPublicBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('olivo.publicBaseUrl', url.trim());
  }
}
