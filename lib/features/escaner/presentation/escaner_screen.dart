import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/device_id.dart';
import '../../../core/utils/message.dart';
import '../../../core/widgets/form_gap.dart';

class EscanerScreen extends ConsumerStatefulWidget {
  const EscanerScreen({super.key});

  @override
  ConsumerState<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends ConsumerState<EscanerScreen>
    with WidgetsBindingObserver {
  final _manual = TextEditingController();
  MobileScannerController? _controller;
  StreamSubscription<BarcodeCapture>? _subscription;
  DoorScanResult? _last;
  bool _busy = false;
  bool _useCamera = !kIsWeb;
  bool _cameraReady = false;
  String? _cameraError;
  String? _lastRaw;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_useCamera && !kIsWeb) {
      unawaited(_startCamera());
    }
  }

  Future<void> _startCamera() async {
    await _stopCamera();
    if (!mounted || kIsWeb) return;

    final controller = MobileScannerController(
      autoStart: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
    );

    setState(() {
      _controller = controller;
      _cameraError = null;
      _cameraReady = false;
    });

    _subscription = controller.barcodes.listen(_onBarcode);

    try {
      // Requests CAMERA permission at runtime on Android/iOS.
      await controller.start();
      if (!mounted) return;
      setState(() {
        _cameraReady = controller.value.hasCameraPermission;
        if (!controller.value.hasCameraPermission) {
          _cameraError =
              'Permiso de cámara denegado. Usa la entrada manual o actívalo en Ajustes.';
          _useCamera = false;
        }
      });
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = e.errorDetails?.message ?? e.errorCode.message;
        _useCamera = false;
        _cameraReady = false;
      });
      await _stopCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = '$e';
        _useCamera = false;
        _cameraReady = false;
      });
      await _stopCamera();
    }
  }

  Future<void> _stopCamera() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        await c.stop();
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
    }
    _cameraReady = false;
  }

  void _onBarcode(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw != null) unawaited(_scanToken(raw));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !_useCamera || kIsWeb) return;
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _subscription ??= controller.barcodes.listen(_onBarcode);
        unawaited(controller.start());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  Future<void> _toggleCamera(bool enable) async {
    setState(() {
      _useCamera = enable;
      _cameraError = null;
    });
    if (enable && !kIsWeb) {
      await _startCamera();
    } else {
      await _stopCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manual.dispose();
    unawaited(_stopCamera());
    super.dispose();
  }

  Future<void> _scanToken(String raw) async {
    final token = tokenFromScan(raw);
    if (token.isEmpty || token == _lastRaw) return;
    _lastRaw = token;
    final auth = ref.read(authProvider).user;
    if (auth == null) return;
    setState(() => _busy = true);
    try {
      final id = await deviceId();
      final result =
          await ref.read(olivoRepoProvider).scanDoor(auth.userId, token, id);
      setState(() => _last = result);
      ref.invalidate(guestsProvider);
      ref.invalidate(statsProvider);
      ref.invalidate(scansProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
      Future.delayed(const Duration(seconds: 2), () => _lastRaw = null);
    }
  }

  Color _outcomeColor(String o) {
    return switch (o) {
      'checked_in' => OlivoColors.olive,
      'already_in' => OlivoColors.warn,
      'cloned' || 'discarded' || 'missing' => OlivoColors.danger,
      _ => OlivoColors.muted,
    };
  }

  String _outcomeLabel(String o) {
    return switch (o) {
      'checked_in' => 'Entrada registrada',
      'already_in' => 'Ya había entrado',
      'cloned' => 'Enlace clonado',
      'discarded' => 'Invitación descartada',
      'missing' => 'Token no encontrado',
      _ => o,
    };
  }

  Widget _manualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pega el token o la URL /i/… (también funciona si la cámara no está disponible)',
          style: TextStyle(color: OlivoColors.muted, fontSize: 13),
        ),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _manual,
                decoration: const InputDecoration(
                  labelText: 'Token o URL',
                  hintText: 'demo-ana o https://…/i/demo-ana',
                ),
                onSubmitted: _scanToken,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton(
                onPressed: _busy ? null : () => _scanToken(_manual.text),
                child: const Text('Validar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cameraPreview() {
    final controller = _controller;
    if (controller == null) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              fit: BoxFit.cover,
              errorBuilder: (context, error, child) {
                return ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error.errorDetails?.message ?? error.errorCode.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!_cameraReady)
              const ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                'Apunta al código QR de la invitación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scansAsync = ref.watch(scansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner'),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: _useCamera ? 'Entrada manual' : 'Cámara',
              onPressed: () => _toggleCamera(!_useCamera),
              icon: Icon(_useCamera ? Icons.keyboard : Icons.camera_alt),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_cameraError != null) ...[
            Card(
              color: OlivoColors.warn.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _cameraError!,
                  style: const TextStyle(color: OlivoColors.warn, fontSize: 13),
                ),
              ),
            ),
            const FormGap(),
          ],
          if (_useCamera && !kIsWeb) ...[
            _cameraPreview(),
            const FormGap(height: 16),
          ],
          _manualEntry(),
          if (_busy) ...[
            const FormGap(),
            const LinearProgressIndicator(),
          ],
          if (_last != null) ...[
            const FormGap(height: 16),
            Card(
              color: _outcomeColor(_last!.outcome).withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _outcomeLabel(_last!.outcome),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _outcomeColor(_last!.outcome),
                      ),
                    ),
                    if (_last!.guest != null) ...[
                      const SizedBox(height: 4),
                      Text(_last!.guest!.name),
                      Text(
                        'Grupo: ${_last!.guest!.groupName.isEmpty ? '—' : _last!.guest!.groupName} · x${_last!.guest!.partySize}',
                        style: const TextStyle(
                            color: OlivoColors.muted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Últimos eventos',
              style: Theme.of(context).textTheme.titleMedium),
          const FormGap(height: 8),
          scansAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (events) {
              if (events.isEmpty) {
                return const Text('Sin escaneos aún',
                    style: TextStyle(color: OlivoColors.subtle));
              }
              return Column(
                children: [
                  for (final e in events)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        e.kind == 'door' ? Icons.door_front_door : Icons.link,
                        size: 20,
                        color: OlivoColors.olive,
                      ),
                      title: Text(e.guestName),
                      subtitle: Text('${e.kind} · ${e.outcome}'),
                      trailing: Text(
                        e.createdAt.length > 16
                            ? e.createdAt.substring(11, 16)
                            : e.createdAt,
                        style: const TextStyle(
                            fontSize: 11, color: OlivoColors.subtle),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
