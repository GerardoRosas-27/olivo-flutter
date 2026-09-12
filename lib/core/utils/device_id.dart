import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _key = 'olivo.device';

Future<String> deviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_key);
  if (existing != null && existing.isNotEmpty) return existing;
  final next = const Uuid().v4();
  await prefs.setString(_key, next);
  return next;
}
