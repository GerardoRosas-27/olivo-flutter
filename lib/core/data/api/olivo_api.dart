import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/models.dart';

/// Remote Olivo API on the same Railway host as the SPA.
class OlivoApi {
  OlivoApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String? _base;

  void setBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _base = null;
      return;
    }
    _base = url.trim().replaceAll(RegExp(r'/$'), '');
  }

  String? get baseUrl => _base;

  bool get isConfigured => _base != null && _base!.isNotEmpty;

  Uri _uri(String path, [Map<String, String>? query]) {
    final b = _base!;
    return Uri.parse('$b$path').replace(queryParameters: query);
  }

  Map<String, String> _hostHeaders(String hostUserId, {String? email}) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $hostUserId',
      'X-Host-User-Id': hostUserId,
      if (email != null && email.isNotEmpty) 'X-Host-Email': email,
    };
  }

  Future<Map<String, dynamic>?> getPublicInvitation(
    String token, {
    bool open = false,
    String? deviceId,
  }) async {
    if (!isConfigured) return null;
    try {
      final q = <String, String>{};
      if (open) q['open'] = '1';
      if (deviceId != null && deviceId.isNotEmpty) q['deviceId'] = deviceId;
      final res = await _client
          .get(_uri('/api/public/invitation/${Uri.encodeComponent(token)}', q))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 404) {
        return {'ok': false, 'reason': 'missing'};
      }
      if (res.statusCode == 410) {
        return {'ok': false, 'reason': 'discarded'};
      }
      if (res.statusCode == 409) {
        return {'ok': false, 'reason': 'cloned'};
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return _normalizeInvite(map);
    } catch (e) {
      debugPrint('OlivoApi.getPublicInvitation: $e');
      return null;
    }
  }

  Map<String, dynamic> _normalizeInvite(Map<String, dynamic> map) {
    if (map['ok'] == false) return map;
    final weddingRaw = map['wedding'];
    final guestRaw = map['guest'];
    Wedding? wedding;
    Guest? guest;
    if (weddingRaw is Map) {
      wedding = Wedding.fromJson(Map<String, dynamic>.from(weddingRaw));
    }
    if (guestRaw is Map) {
      guest = Guest.fromJson(Map<String, dynamic>.from(guestRaw));
    }
    return {
      ...map,
      'ok': true,
      'guestName': map['guestName'] ?? guest?.name ?? '',
      'partySize': (map['partySize'] as num?)?.toInt() ?? guest?.partySize ?? 1,
      'rsvp': map['rsvp'] ?? guest?.rsvp ?? 'unknown',
      'wedding': wedding,
      'guest': guest,
    };
  }

  Future<Map<String, dynamic>?> submitRsvp({
    required String token,
    required String response,
    required String deviceId,
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await _client
          .post(
            _uri('/api/public/rsvp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'response': response,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 404) return {'ok': false, 'reason': 'missing'};
      if (res.statusCode == 410) return {'ok': false, 'reason': 'discarded'};
      if (res.statusCode == 409) return {'ok': false, 'reason': 'cloned'};
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return _normalizeInvite(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map),
      );
    } catch (e) {
      debugPrint('OlivoApi.submitRsvp: $e');
      return null;
    }
  }

  Future<DoorScanResult?> doorScan({
    required String token,
    required String hostUserId,
    required String deviceId,
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await _client
          .post(
            _uri('/api/door/scan'),
            headers: _hostHeaders(hostUserId),
            body: jsonEncode({
              'token': token,
              'hostUserId': hostUserId,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final map = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      Guest? guest;
      final g = map['guest'];
      if (g is Map) {
        guest = Guest.fromJson(Map<String, dynamic>.from(g));
      }
      return DoorScanResult(
        outcome: map['outcome'] as String? ?? 'missing',
        guest: guest,
      );
    } catch (e) {
      debugPrint('OlivoApi.doorScan: $e');
      return null;
    }
  }

  Future<bool> syncHost({
    required String hostUserId,
    String? email,
    required Wedding wedding,
    required List<Guest> guests,
  }) async {
    if (!isConfigured) return false;
    try {
      final payload = {
        'userId': hostUserId,
        'email': email,
        'wedding': wedding.toJson(),
        'guests': guests.map((g) {
          final j = g.toJson();
          j['userId'] = hostUserId;
          return j;
        }).toList(),
      };
      final res = await _client
          .put(
            _uri('/api/host/sync'),
            headers: _hostHeaders(hostUserId, email: email),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('OlivoApi.syncHost status ${res.statusCode}: ${res.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('OlivoApi.syncHost: $e');
      return false;
    }
  }
}
