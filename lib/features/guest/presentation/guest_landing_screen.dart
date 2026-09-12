import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_gap.dart';
import '../../../core/utils/device_id.dart';
import '../../../core/utils/message.dart';

class GuestLandingScreen extends ConsumerStatefulWidget {
  const GuestLandingScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<GuestLandingScreen> createState() => _GuestLandingScreenState();
}

class _GuestLandingScreenState extends ConsumerState<GuestLandingScreen> {
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _rsvpBusy = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final repo = ref.read(olivoRepoProvider);
    final peek = await repo.peekInvitation(widget.token);
    if (!mounted) return;
    if (peek['ok'] != true) {
      setState(() {
        _result = peek;
        _loading = false;
      });
      return;
    }
    setState(() {
      _result = peek;
      _loading = false;
    });
    final id = await deviceId();
    final opened = await repo.openInvitation(widget.token, id);
    if (mounted) setState(() => _result = opened);
  }

  Future<void> _rsvp(String status) async {
    setState(() => _rsvpBusy = true);
    final id = await deviceId();
    final next =
        await ref.read(olivoRepoProvider).submitRsvp(widget.token, id, status);
    if (mounted) {
      setState(() {
        _result = next;
        _rsvpBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: Text('Abriendo tu invitación…', style: TextStyle(color: OlivoColors.muted))),
      );
    }
    final result = _result!;
    if (result['ok'] != true) {
      return _Blocked(reason: result['reason'] as String? ?? 'missing');
    }
    final wedding = result['wedding'] as Wedding;
    final guestName = result['guestName'] as String? ?? '';
    final current = result['rsvp'] as String? ?? 'unknown';
    final couple = coupleNames(wedding);
    final date = formatWeddingDate(wedding.weddingDate);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
            children: [
              Text(
                'CON ALEGRÍA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  letterSpacing: 3,
                  fontSize: 11,
                  color: OlivoColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                couple.isEmpty ? 'Nuestra boda' : couple,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                [
                  if (date.isNotEmpty) date,
                  if (wedding.weddingTime.isNotEmpty) wedding.weddingTime,
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: OlivoColors.muted),
              ),
              Text(wedding.venueName, textAlign: TextAlign.center),
              Text(
                wedding.venueAddress,
                textAlign: TextAlign.center,
                style: const TextStyle(color: OlivoColors.subtle),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PARA ${guestName.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: OlivoColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(wedding.welcomeNote),
                      const FormGap(height: 16),
                      if (current == 'unknown')
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _rsvpBusy ? null : () => _rsvp('yes'),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Confirmar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _rsvpBusy ? null : () => _rsvp('no'),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('No podré'),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          current == 'yes'
                              ? 'Gracias. Te esperamos.'
                              : 'Lamentamos que no puedas. Te llevamos en el corazón.',
                          style: const TextStyle(color: OlivoColors.olive),
                        ),
                    ],
                  ),
                ),
              ),
              if (wedding.story.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Los novios',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text(wedding.story, style: const TextStyle(color: OlivoColors.muted)),
              ],
              if (wedding.schedule.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Itinerario',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                ...wedding.schedule.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(item.time,
                              style: const TextStyle(color: OlivoColors.olive)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(item.detail,
                                  style: const TextStyle(
                                      color: OlivoColors.subtle, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (wedding.dressCode.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Vestimenta',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Text(wedding.dressCode, style: const TextStyle(color: OlivoColors.muted)),
              ],
              if (wedding.venueMapsUrl.isNotEmpty) ...[
                const SizedBox(height: 28),
                Center(
                  child: TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(wedding.venueMapsUrl)),
                    icon: const Icon(Icons.place_outlined, color: OlivoColors.olive),
                    label: const Text('Cómo llegar',
                        style: TextStyle(color: OlivoColors.olive)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final copy = switch (reason) {
      'discarded' => 'Esta invitación ya no es válida.',
      'cloned' =>
        'Este enlace parece compartido o clonado. Contacta a los anfitriones.',
      _ => 'Esta invitación no existe.',
    };
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(copy, textAlign: TextAlign.center,
              style: const TextStyle(color: OlivoColors.muted)),
        ),
      ),
    );
  }
}
