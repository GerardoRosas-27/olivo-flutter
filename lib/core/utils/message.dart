import 'package:intl/intl.dart';

import '../models/models.dart';

String invitationUrl(String origin, String token) {
  final base = origin.replaceAll(RegExp(r'/$'), '');
  return '$base/i/$token';
}

String formatWeddingDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final date = DateTime.parse('${iso}T12:00:00');
    return DateFormat('EEEE d \'de\' MMMM \'de\' y', 'es_MX').format(date);
  } catch (_) {
    return iso;
  }
}

String coupleNames(Wedding wedding) {
  return [wedding.partnerOne, wedding.partnerTwo]
      .where((e) => e.trim().isNotEmpty)
      .join(' & ');
}

final _templatePlaceholder = RegExp(
  r'\{nombre\}|\{novios\}|\{fecha\}|\{hora\}|\{lugar\}|\{direccion\}|\{enlace\}|\{cupo\}',
);

String buildGuestMessage(Wedding wedding, Guest guest, String origin) {
  final template =
      wedding.whatsappTemplate.isEmpty ? defaultTemplate : wedding.whatsappTemplate;
  final map = <String, String>{
    '{nombre}': guest.name,
    '{novios}': coupleNames(wedding),
    '{fecha}': formatWeddingDate(wedding.weddingDate),
    '{hora}': wedding.weddingTime,
    '{lugar}': wedding.venueName,
    '{direccion}': wedding.venueAddress,
    '{enlace}': invitationUrl(origin, guest.token),
    '{cupo}': '${guest.partySize}',
  };
  return template.replaceAllMapped(
    _templatePlaceholder,
    (m) => map[m.group(0)!] ?? m.group(0)!,
  );
}

String whatsappDigits(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '52$digits';
  return digits;
}

String whatsappHref(String phone, String text) {
  final digits = whatsappDigits(phone);
  if (digits.isEmpty) {
    return 'https://wa.me/?text=${Uri.encodeComponent(text)}';
  }
  return 'https://wa.me/$digits?text=${Uri.encodeComponent(text)}';
}

/// Generic WhatsApp share (no phone) — opens chat picker with prefilled text.
String whatsappShareHref(String text) {
  return 'https://wa.me/?text=${Uri.encodeComponent(text)}';
}

String tokenFromScan(String raw) {
  final trimmed = raw.trim();
  try {
    final url = Uri.parse(trimmed);
    final match = RegExp(r'/i/([^/]+)').firstMatch(url.path);
    if (match != null) return Uri.decodeComponent(match.group(1)!);
  } catch (_) {}
  final path = RegExp(r'/i/([^/?#]+)').firstMatch(trimmed);
  if (path != null) return Uri.decodeComponent(path.group(1)!);
  return trimmed;
}
