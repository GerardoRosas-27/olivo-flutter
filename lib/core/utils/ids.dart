import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId(String prefix) {
  final raw = _uuid.v4().replaceAll('-', '');
  return '${prefix}_${raw.substring(0, 16)}';
}

String newToken() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(36).padLeft(2, '0'));
  }
  final s = buf.toString();
  return s.length > 22 ? s.substring(0, 22) : s;
}

String nowIso() => DateTime.now().toUtc().toIso8601String();
