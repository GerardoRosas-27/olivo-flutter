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
  /// System share sheet opened with image + text in one shot (mobile/desktop).
  imageAndText,
  /// Two-step: QR image first, then template text + link (web, or mobile fallback).
  twoStep,
  /// Only the QR image was shared; caller should offer copying the text.
  imageOnly,
  /// Text-only share (no QR file available).
  textOnly,
}

Future<XFile> _qrFile(Uint8List bytes, String url) async {
  if (kIsWeb) {
    return XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: 'invitacion-qr.png',
    );
  }
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/olivo-qr-${url.hashCode.abs()}.png';
  final disk = File(path);
  await disk.writeAsBytes(bytes, flush: true);
  return XFile(path, mimeType: 'image/png', name: 'invitacion-qr.png');
}

/// Confirm between the two share steps (web / fallback).
Future<void> _confirmTwoStep(BuildContext? context) async {
  if (context == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Paso 1/2 listo'),
      content: const Text(
        'Paso 1/2: comparte el QR. Luego Paso 2/2: el mensaje con el enlace.\n\n'
        'Ahora se enviará el mensaje con el enlace.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}

/// Two-step share: (1) QR image only, (2) template text + public link.
Future<ShareInvitationResult> _shareTwoStep({
  required XFile file,
  required String text,
  String? subject,
  BuildContext? context,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      subject: subject,
      files: [file],
    ),
  );
  final ctx = context;
  if (ctx != null && ctx.mounted) {
    await _confirmTwoStep(ctx);
  }
  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject),
  );
  return ShareInvitationResult.twoStep;
}

/// Share invitation: QR PNG encoding [url] plus [text] via the system share sheet.
///
/// **Web (`kIsWeb`):** always two-step — image first, then text+link (WhatsApp
/// twice). Do not rely on a single image+text share.
///
/// **Mobile/desktop:** try image+text in one share; if that fails, same two-step
/// as web. `wa.me` cannot attach images — uses share intents instead.
Future<ShareInvitationResult> shareInvitation({
  required String text,
  required String url,
  String? subject,
  BuildContext? context,
}) async {
  final bytes = await renderQrPng(url);
  if (bytes == null) {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
    return ShareInvitationResult.textOnly;
  }

  final file = await _qrFile(bytes, url);

  // Web: always two-step (image, then text). Combined share is unreliable.
  if (kIsWeb) {
    try {
      final webCtx = context;
      return await _shareTwoStep(
        file: file,
        text: text,
        subject: subject,
        context: (webCtx != null && webCtx.mounted) ? webCtx : null,
      );
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(subject: subject, files: [file]),
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

  // Mobile/desktop: prefer image + text in one share.
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
    // Fallback: same two-step as web.
    try {
      final fbCtx = context;
      return await _shareTwoStep(
        file: file,
        text: text,
        subject: subject,
        context: (fbCtx != null && fbCtx.mounted) ? fbCtx : null,
      );
    } catch (_) {
      try {
        await SharePlus.instance.share(
          ShareParams(subject: subject, files: [file]),
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
