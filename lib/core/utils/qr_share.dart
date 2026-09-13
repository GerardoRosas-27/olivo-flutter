import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Share invitation text and, when possible, a QR PNG via the system share sheet.
Future<void> shareInvitation({
  required String text,
  required String url,
  String? subject,
}) async {
  final bytes = await renderQrPng(url);
  if (bytes != null && !kIsWeb) {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/olivo-qr-${url.hashCode.abs()}.png');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          files: [
            XFile(file.path, mimeType: 'image/png', name: 'invitacion-qr.png'),
          ],
        ),
      );
      return;
    } catch (_) {
      // Fall through to text-only share.
    }
  }
  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject),
  );
}
