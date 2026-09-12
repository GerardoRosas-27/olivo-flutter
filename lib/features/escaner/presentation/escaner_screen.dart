import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/device_id.dart';
import '../../../core/utils/message.dart';

class EscanerScreen extends ConsumerStatefulWidget {
  const EscanerScreen({super.key});

  @override
  ConsumerState<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends ConsumerState<EscanerScreen> {
  final _manual = TextEditingController();
  DoorScanResult? _last;
  bool _busy = false;
  bool _useCamera = !kIsWeb;
  String? _lastRaw;

  @override
  void dispose() {
    _manual.dispose();
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
              onPressed: () => setState(() => _useCamera = !_useCamera),
              icon: Icon(_useCamera ? Icons.keyboard : Icons.camera_alt),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_useCamera && !kIsWeb)
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue;
                    if (raw != null) _scanToken(raw);
                  },
                ),
              ),
            )
          else ...[
            const Text(
              'En web (o sin cámara): pega el token o la URL /i/…',
              style: TextStyle(color: OlivoColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
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
                FilledButton(
                  onPressed: _busy ? null : () => _scanToken(_manual.text),
                  child: const Text('Validar'),
                ),
              ],
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_last != null) ...[
            const SizedBox(height: 16),
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
                        style: const TextStyle(color: OlivoColors.muted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Últimos eventos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
                        style: const TextStyle(fontSize: 11, color: OlivoColors.subtle),
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
