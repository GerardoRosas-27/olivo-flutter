import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _useCamera = true;
  bool _cameraReady = false;
  bool _permissionPermanentlyDenied = false;
  String? _cameraError;
  String? _lastRaw;

  /// Browser camera requires a secure context (HTTPS or localhost).
  bool get _webInsecureContext {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    if (uri.scheme == 'https') return false;
    final host = uri.host;
    return host != 'localhost' && host != '127.0.0.1' && host != '::1';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_useCamera) {
      unawaited(_startCamera());
    }
  }

  Future<bool> _ensureCameraPermission() async {
    // Web: browser prompts via getUserMedia inside mobile_scanner.
    // Desktop (macOS/linux/windows): OS dialogs / not permission_handler.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }

    var status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      _permissionPermanentlyDenied = false;
      return true;
    }

    if (status.isPermanentlyDenied) {
      _permissionPermanentlyDenied = true;
      return false;
    }

    status = await Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      _permissionPermanentlyDenied = false;
      return true;
    }

    _permissionPermanentlyDenied = status.isPermanentlyDenied;
    return false;
  }


  /// Never surface raw Java/Kotlin NPEs or obfuscated R8 frames to the user.
  String _friendlyCameraError([Object? error]) {
    if (kIsWeb) {
      return 'No se pudo abrir la cámara. Pega el enlace a mano.';
    }

    if (error is MobileScannerException) {
      if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
        return _permissionPermanentlyDenied
            ? 'Permiso de cámara denegado permanentemente. Ábrelo en Ajustes o usa la entrada manual.'
            : 'Permiso de cámara denegado. Usa «Reintentar permiso» o la entrada manual.';
      }
    }

    final raw = switch (error) {
      MobileScannerException e =>
        (e.errorDetails?.message ?? e.errorCode.message).trim(),
      _ => (error?.toString() ?? '').trim(),
    };
    final lower = raw.toLowerCase();

    if (lower.contains('permission') || lower.contains('denied')) {
      return _permissionPermanentlyDenied
          ? 'Permiso de cámara denegado permanentemente. Ábrelo en Ajustes o usa la entrada manual.'
          : 'Permiso de cámara denegado. Usa «Reintentar permiso» o la entrada manual.';
    }

    // Platform / R8 / ML Kit internals (e.g. "Attempt to invoke virtual method … on a null object reference")
    if (lower.contains('null object reference') ||
        lower.contains('nullpointer') ||
        lower.contains('attempt to invoke') ||
        lower.contains('platformexception') ||
        lower.contains('missingpluginexception') ||
        lower.contains('controllerdisposed') ||
        lower.contains('no camera') ||
        raw.contains('Exception') ||
        raw.contains('Error:')) {
      return 'No se pudo iniciar la cámara. Prueba «Reintentar permiso» o usa la entrada manual.';
    }

    if (raw.isNotEmpty &&
        raw.length <= 140 &&
        !raw.contains('\n') &&
        !RegExp(r'\b[a-z]\d+\.[a-z]').hasMatch(lower)) {
      return raw;
    }

    return 'No se pudo abrir la cámara. Prueba de nuevo o usa la entrada manual.';
  }

  Future<void> _startCamera() async {
    await _stopCamera();
    if (!mounted) return;

    if (_webInsecureContext) {
      setState(() {
        _cameraError =
            'No se pudo abrir la cámara. Pega el enlace a mano. (Se requiere HTTPS)';
        _cameraReady = false;
        _permissionPermanentlyDenied = false;
      });
      return;
    }

    final allowed = await _ensureCameraPermission();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _cameraError = _permissionPermanentlyDenied
            ? 'Permiso de cámara denegado permanentemente. Ábrelo en Ajustes o usa la entrada manual.'
            : 'Permiso de cámara denegado. Usa «Reintentar permiso» o la entrada manual.';
        _cameraReady = false;
      });
      return;
    }

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
      _permissionPermanentlyDenied = false;
    });

    _subscription = controller.barcodes.listen(_onBarcode);

    try {
      await controller.start();
      if (!mounted) return;
      // mobile_scanner swallows MobileScannerException into value.error (no throw).
      final startError = controller.value.error;
      if (startError != null) {
        setState(() {
          _cameraError = _friendlyCameraError(startError);
          _cameraReady = false;
        });
        await _stopCamera();
        return;
      }
      final hasPermission = controller.value.hasCameraPermission;
      setState(() {
        _cameraReady = hasPermission && controller.value.isRunning;
        if (!hasPermission) {
          _cameraError = _friendlyCameraError(
            MobileScannerException(
              errorCode: MobileScannerErrorCode.permissionDenied,
            ),
          );
        } else if (!controller.value.isRunning) {
          _cameraError = _friendlyCameraError();
        }
      });
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = _friendlyCameraError(e);
        _cameraReady = false;
      });
      await _stopCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = _friendlyCameraError(e);
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
    // Web: leave stream to the browser / mobile_scanner; avoid churn.
    if (kIsWeb) return;
    final controller = _controller;
    if (controller == null || !_useCamera) return;
    // Permission dialogs and failed starts leave the controller uninitialized
    // or with an error — do not churn start/stop in those states.
    if (!controller.value.isInitialized ||
        controller.value.error != null ||
        !controller.value.hasCameraPermission) {
      return;
    }

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
      _permissionPermanentlyDenied = false;
    });
    if (enable) {
      await _startCamera();
    } else {
      await _stopCamera();
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryPermission() async {
    setState(() {
      _cameraError = null;
      _permissionPermanentlyDenied = false;
      _useCamera = true;
    });
    await _startCamera();
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
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
      'already_in' || 'full' => OlivoColors.warn,
      'cloned' || 'discarded' || 'missing' => OlivoColors.danger,
      _ => OlivoColors.muted,
    };
  }

  String _outcomeLabel(String o) {
    return switch (o) {
      'checked_in' => 'Entrada registrada',
      'already_in' => 'Ya había entrado',
      'full' => 'Los cupos de esta invitación ya fueron escaneados',
      'cloned' => 'Enlace clonado',
      'discarded' => 'Invitación descartada',
      'missing' => 'Token no encontrado',
      _ => o,
    };
  }

  String? _outcomeDetail(String o) {
    return switch (o) {
      'full' => 'No se permite la entrada a más personas.',
      _ => null,
    };
  }

  String _eventKindLabel(String k) => switch (k) {
        'door' => 'Puerta',
        'invite' => 'Invitación',
        'discard' => 'Descarte',
        _ => k,
      };

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

  Widget _cameraErrorActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _retryPermission,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar permiso'),
        ),
        if (_permissionPermanentlyDenied && !kIsWeb)
          FilledButton.tonalIcon(
            onPressed: _openAppSettings,
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Abrir ajustes'),
          ),
        if (kIsWeb)
          Text(
            'Consejo: abre la app por HTTPS (o localhost) para usar la cámara.',
            style: TextStyle(
              color: OlivoColors.muted.withValues(alpha: 0.9),
              fontSize: 12,
            ),
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
        child: _cameraError != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off,
                        color: OlivoColors.warn.withValues(alpha: 0.9),
                        size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _cameraError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: OlivoColors.warn, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _cameraErrorActions(),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _friendlyCameraError(error),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _retryPermission,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reintentar permiso'),
                          ),
                        ],
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
    final guestsAsync = ref.watch(guestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner'),
        actions: [
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
          if (_cameraError != null && _useCamera && _controller != null) ...[
            Card(
              color: OlivoColors.warn.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cameraError!,
                      style: const TextStyle(
                          color: OlivoColors.warn, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _cameraErrorActions(),
                  ],
                ),
              ),
            ),
            const FormGap(),
          ],
          if (_useCamera) ...[
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
                        fontSize: 16,
                        color: _outcomeColor(_last!.outcome),
                      ),
                    ),
                    if (_outcomeDetail(_last!.outcome) != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _outcomeDetail(_last!.outcome)!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: _outcomeColor(_last!.outcome),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (_last!.guest != null) ...[
                      const SizedBox(height: 8),
                      Text(_last!.guest!.name),
                      Text(
                        'Grupo: ${_last!.guest!.groupName.isEmpty ? '—' : _last!.guest!.groupName}'
                        ' · cupo ${_last!.guest!.checkedInCount}/${_last!.guest!.partySize}',
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
          Text('Invitados en puerta',
              style: Theme.of(context).textTheme.titleMedium),
          const FormGap(height: 8),
          guestsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (guests) {
              final scanned = guests
                  .where((g) => !g.isDiscarded && g.checkedInCount > 0)
                  .toList()
                ..sort((a, b) =>
                    b.checkedInCount.compareTo(a.checkedInCount));
              if (scanned.isEmpty) {
                return const Text(
                  'Nadie ha entrado aún',
                  style: TextStyle(color: OlivoColors.subtle),
                );
              }
              return Column(
                children: [
                  for (final g in scanned)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        g.isQuotaFull
                            ? Icons.verified
                            : Icons.hourglass_bottom,
                        size: 20,
                        color: g.isQuotaFull
                            ? OlivoColors.olive
                            : OlivoColors.warn,
                      ),
                      title: Text(g.name),
                      subtitle: Text(
                        g.isQuotaFull
                            ? 'Cupos ya escaneados · sin entrada adicional'
                            : 'Parcial · ${g.checkedInCount} de ${g.partySize}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${g.checkedInCount}/${g.partySize}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: g.isQuotaFull
                              ? OlivoColors.olive
                              : OlivoColors.warn,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
                      subtitle: Text('${_eventKindLabel(e.kind)} · ${_outcomeLabel(e.outcome)}'),
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
