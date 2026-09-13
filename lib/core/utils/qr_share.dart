import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

Future<Uint8List?> renderQrPng(String data, {double size = 512}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: OlivoColors.fg,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: OlivoColors.fg,
    ),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = OlivoColors.bg,
  );
  painter.paint(canvas, Size(size, size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}

/// Result of sharing an invitation (QR image + template text).
enum ShareInvitationResult {
  /// System share sheet opened with image + text (ideal for WhatsApp).
  imageAndText,
  /// Only the QR image was shared; caller should offer copying the text.
  imageOnly,
  /// Text-only share (no QR file available).
  textOnly,
}

/// Share invitation: QR PNG encoding [url] plus [text] via the system share sheet.
/// Prefer image+text together so the user can pick WhatsApp and send both.
/// `wa.me` cannot attach images — this uses Android/iOS share intents instead.
Future<ShareInvitationResult> shareInvitation({
  required String text,
  required String url,
  String? subject,
}) async {
  final bytes = await renderQrPng(url);
  if (bytes == null) {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return ShareInvitationResult.textOnly;
  }

  XFile file;
  if (kIsWeb) {
    file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'invitacion-qr.png',
    );
  } else {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/olivo-qr-${url.hashCode.abs()}.png';
    final disk = File(path);
    await disk.writeAsBytes(bytes, flush: true);
    file = XFile(path, mimeType: 'image/png', name: 'invitacion-qr.png');
  }

  // Primary: image + text in one share (WhatsApp receives both when supported).
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: [file],
      ),
    );
    return ShareInvitationResult.imageAndText;
  } catch (_) {
    // Secondary: share image alone, then let caller offer copying the text.
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: subject,
          files: [file],
        ),
      );
      return ShareInvitationResult.imageOnly;
    } catch (_) {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return ShareInvitationResult.textOnly;
    }
  }
}

/// After an image-only share, offer to copy the WhatsApp template text.
Future<void> offerCopyInvitationText(
  BuildContext context, {
  required String text,
}) async {
  if (!context.mounted) return;
  final copy = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Texto de la invitación'),
      content: const Text(
        'La imagen del QR se compartió. En algunas apps el texto no viaja junto '
        'con la imagen. ¿Copiar el mensaje con el enlace para pegarlo en WhatsApp?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Copiar texto'),
        ),
      ],
    ),
  );
  if (copy == true) {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje copiado. Pégalo en WhatsApp.')),
    );
  }
}
