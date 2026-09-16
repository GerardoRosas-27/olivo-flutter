import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    // Analytics open must not replace a successful peek with a legacy "cloned" error.
    if (mounted && opened['ok'] == true) {
      setState(() => _result = opened);
    }
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: OlivoColors.fg,
          ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: OlivoColors.border),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Abriendo tu invitación…',
            style: TextStyle(color: OlivoColors.muted),
          ),
        ),
      );
    }
    final result = _result!;
    if (result['ok'] != true) {
      return _Blocked(reason: result['reason'] as String? ?? 'missing');
    }
    final weddingRaw = result['wedding'];
    final Wedding wedding;
    if (weddingRaw is Wedding) {
      wedding = weddingRaw;
    } else if (weddingRaw is Map) {
      wedding = Wedding.fromJson(Map<String, dynamic>.from(weddingRaw));
    } else {
      return const _Blocked(reason: 'missing');
    }
    final guestName = result['guestName'] as String? ?? '';
    final partySize = (result['partySize'] as num?)?.toInt() ?? 1;
    final current = result['rsvp'] as String? ?? 'unknown';
    final couple = coupleNames(wedding);
    final date = formatWeddingDate(wedding.weddingDate);
    final when = [
      if (date.isNotEmpty) date,
      if (wedding.weddingTime.isNotEmpty) wedding.weddingTime,
    ].join(' · ');
    final origin = (Uri.base.hasScheme &&
            (Uri.base.scheme == 'http' || Uri.base.scheme == 'https'))
        ? '${Uri.base.scheme}://${Uri.base.host}'
            '${Uri.base.hasPort ? ':${Uri.base.port}' : ''}'
        : 'http://localhost:8080';
    final inviteUrl = invitationUrl(origin, widget.token);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 56),
            children: [
              Text(
                'ESTA ES TU INVITACIÓN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  letterSpacing: 2.5,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OlivoColors.olive,
                ),
              ),
              const SizedBox(height: 6),
              if (guestName.isNotEmpty)
                Text(
                  guestName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OlivoColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OlivoColors.border),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: inviteUrl,
                          version: QrVersions.auto,
                          backgroundColor: OlivoColors.bg,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: OlivoColors.fg,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: OlivoColors.fg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pase de entrada',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: OlivoColors.fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        partySize <= 1
                            ? 'Cupo: 1 persona'
                            : 'Cupo: $partySize personas',
                        style: const TextStyle(
                          fontSize: 13,
                          color: OlivoColors.olive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        partySize <= 1
                            ? 'Muéstralo en la puerta para registrar tu entrada.'
                            : 'Muéstralo en la puerta. Cada escaneo usa 1 de tus $partySize cupos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OlivoColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'CON ALEGRÍA TE INVITAMOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  letterSpacing: 2.5,
                  fontSize: 11,
                  color: OlivoColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                couple.isEmpty ? 'Nuestra boda' : couple,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.15,
                    ),
              ),
              const SizedBox(height: 16),
              if (when.isNotEmpty)
                Text(
                  when,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OlivoColors.olive,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 8),
              if (wedding.venueName.isNotEmpty)
                Text(
                  wedding.venueName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (wedding.venueAddress.isNotEmpty)
                Text(
                  wedding.venueAddress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: OlivoColors.subtle),
                ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
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
                      const SizedBox(height: 4),
                      Text(
                        partySize <= 1
                            ? 'Invitación para 1 persona'
                            : 'Invitación para $partySize personas',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OlivoColors.olive,
                        ),
                      ),
                      if (wedding.welcomeNote.isNotEmpty) ...[
                        const FormGap(height: 12),
                        Text(
                          wedding.welcomeNote,
                          style: const TextStyle(height: 1.45),
                        ),
                      ],
                      const FormGap(height: 18),
                      Text(
                        wedding.rsvpDeadline != null &&
                                wedding.rsvpDeadline!.isNotEmpty
                            ? 'Confirma tu asistencia'
                                ' (antes del ${formatWeddingDate(wedding.rsvpDeadline)})'
                            : 'Confirma tu asistencia',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const FormGap(height: 10),
                      if (current == 'unknown')
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    _rsvpBusy ? null : () => _rsvp('yes'),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('¡Allá estaré!'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _rsvpBusy ? null : () => _rsvp('no'),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('No podré'),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: OlivoColors.olive.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            current == 'yes'
                                ? 'Gracias. Te esperamos con ilusión.'
                                : 'Lamentamos que no puedas. Te llevamos en el corazón.',
                            style: const TextStyle(color: OlivoColors.olive),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (wedding.story.isNotEmpty) ...[
                const SizedBox(height: 32),
                _sectionTitle(context, 'Nuestra historia'),
                const SizedBox(height: 8),
                Text(
                  wedding.story,
                  style: const TextStyle(
                    color: OlivoColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
              if (wedding.schedule.isNotEmpty) ...[
                const SizedBox(height: 32),
                _sectionTitle(context, 'Itinerario'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < wedding.schedule.length; i++) ...[
                          if (i > 0) _divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    wedding.schedule[i].time,
                                    style: const TextStyle(
                                      color: OlivoColors.olive,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        wedding.schedule[i].title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (wedding
                                          .schedule[i].detail.isNotEmpty)
                                        Text(
                                          wedding.schedule[i].detail,
                                          style: const TextStyle(
                                            color: OlivoColors.subtle,
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (wedding.dressCode.isNotEmpty) ...[
                const SizedBox(height: 32),
                _sectionTitle(context, 'Vestimenta'),
                const SizedBox(height: 8),
                Text(
                  wedding.dressCode,
                  style: const TextStyle(
                    color: OlivoColors.muted,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _sectionTitle(context, 'Lugar'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wedding.venueName.isNotEmpty)
                        Text(
                          wedding.venueName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (wedding.venueAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          wedding.venueAddress,
                          style: const TextStyle(color: OlivoColors.muted),
                        ),
                      ],
                      if (wedding.venueMapsUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              launchUrl(Uri.parse(wedding.venueMapsUrl)),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Cómo llegar (mapa)'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Olivo · invitación digital',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: OlivoColors.subtle.withValues(alpha: 0.9),
                ),
              ),
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
          child: Text(
            copy,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OlivoColors.muted),
          ),
        ),
      ),
    );
  }
}
