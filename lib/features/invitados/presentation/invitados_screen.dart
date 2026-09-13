import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/message.dart';
import '../../../core/utils/qr_share.dart';
import '../../../core/widgets/form_gap.dart';

class InvitadosScreen extends ConsumerStatefulWidget {
  const InvitadosScreen({super.key});

  @override
  ConsumerState<InvitadosScreen> createState() => _InvitadosScreenState();
}

class _InvitadosScreenState extends ConsumerState<InvitadosScreen> {
  final _tpl = TextEditingController();
  bool _hydrated = false;
  bool _savingTpl = false;
  bool _templateExpanded = false;
  bool _sending = false;

  @override
  void dispose() {
    _tpl.dispose();
    super.dispose();
  }

  Wedding _weddingWithTpl(Wedding wedding) {
    return wedding.copyWith(
      whatsappTemplate:
          _tpl.text.isEmpty ? wedding.whatsappTemplate : _tpl.text,
    );
  }

  Future<void> _saveTemplate(Wedding w) async {
    final auth = ref.read(authProvider).user;
    if (auth == null) return;
    setState(() => _savingTpl = true);
    try {
      await ref.read(olivoRepoProvider).saveWedding(
            auth.userId,
            w.copyWith(whatsappTemplate: _tpl.text),
          );
      ref.invalidate(weddingProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantilla guardada')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTpl = false);
    }
  }

  /// Envía invitación: QR (PNG de /i/{token}) + texto de plantilla con enlace.
  /// En web es siempre en dos pasos (dos envíos a WhatsApp).
  Future<void> _enviarInvitacion(
    Guest guest,
    Wedding wedding,
    String origin,
  ) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final w = _weddingWithTpl(wedding);
      final msg = buildGuestMessage(w, guest, origin);
      final url = invitationUrl(origin, guest.token);
      final result = await shareInvitation(
        text: msg,
        url: url,
        subject: 'Invitación — ${coupleNames(wedding)}',
        context: context,
      );
      if (!mounted) return;
      if (result == ShareInvitationResult.imageOnly) {
        await offerCopyInvitationText(context, text: msg);
      }
      final auth = ref.read(authProvider).user!;
      await ref.read(olivoRepoProvider).markGuestsSent(auth.userId, [guest.id]);
      ref.invalidate(guestsProvider);
      ref.invalidate(statsProvider);
      if (!mounted) return;
      if (result == ShareInvitationResult.twoStep) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'En web: elige WhatsApp dos veces — 1) imagen QR, 2) mensaje con enlace',
            ),
          ),
        );
      } else if (result != ShareInvitationResult.imageOnly) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Elige WhatsApp en el menú para enviar imagen + mensaje',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _offerSendAfterAdd(
    Guest guest,
    Wedding? wedding,
    String origin,
  ) async {
    if (!mounted || wedding == null) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: kFormDialogInset,
        title: const Text('¿Enviar invitación?'),
        content: Text(
          kIsWeb
              ? 'Se generará el QR de ${guest.name} y el mensaje con el enlace '
                  'público. En web: elige WhatsApp dos veces (1 imagen QR, 2 mensaje).'
              : 'Se generará el QR de ${guest.name} y el mensaje con el enlace '
                  'público. Al compartir, elige WhatsApp para mandar la imagen y el texto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('Después'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'send'),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (!mounted || action != 'send') return;
    await _enviarInvitacion(guest, wedding, origin);
  }

  Future<void> _showGuestForm({Guest? guest}) async {
    final name = TextEditingController(text: guest?.name ?? '');
    final phone = TextEditingController(text: guest?.phone ?? '');
    final party = TextEditingController(text: '${guest?.partySize ?? 1}');
    final group = TextEditingController(text: guest?.groupName ?? '');
    final notes = TextEditingController(text: guest?.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: kFormDialogInset,
        title: Text(guest == null ? 'Nuevo invitado' : 'Editar invitado'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const FormGap(),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (WhatsApp)',
                    hintText: '10 dígitos MX o con lada',
                  ),
                ),
                const FormGap(),
                TextField(
                  controller: party,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cupo / aforo (party size)',
                    helperText: 'Personas que permite este QR en la puerta',
                  ),
                ),
                const FormGap(),
                TextField(
                  controller: group,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                ),
                const FormGap(),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = ref.read(authProvider).user!;
    final repo = ref.read(olivoRepoProvider);
    final size = int.tryParse(party.text) ?? 1;
    final origin =
        ref.read(publicBaseUrlProvider).valueOrNull ?? 'http://localhost:8080';
    final wedding = ref.read(weddingProvider).valueOrNull;
    if (guest == null) {
      final created = await repo.addGuest(
        auth.userId,
        name: name.text,
        phone: phone.text,
        partySize: size,
        groupName: group.text,
        notes: notes.text,
      );
      ref.invalidate(guestsProvider);
      ref.invalidate(statsProvider);
      await _offerSendAfterAdd(created, wedding, origin);
    } else {
      await repo.updateGuest(
        auth.userId,
        id: guest.id,
        name: name.text,
        phone: phone.text,
        partySize: size,
        groupName: group.text,
        notes: notes.text,
      );
      ref.invalidate(guestsProvider);
      ref.invalidate(statsProvider);
    }
  }

  Future<void> _previewGuest(
    Guest guest,
    Wedding? wedding,
    String origin,
  ) async {
    final url = invitationUrl(origin, guest.token);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: kFormDialogInset,
        title: Text(guest.name),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: url,
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
              ),
              const FormGap(),
              SelectableText(url, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                'Cupo: ${guest.checkedInCount}/${guest.partySize}'
                '${guest.isQuotaFull ? ' · vencido' : ''}',
                style: const TextStyle(fontSize: 12, color: OlivoColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (wedding != null)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _enviarInvitacion(guest, wedding, origin);
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Enviar invitación'),
            ),
        ],
      ),
    );
  }

  Future<void> _bulkEnviar(
    List<Guest> guests,
    Wedding wedding,
    String origin,
  ) async {
    final active = guests.where((g) => !g.isDiscarded).toList();
    if (active.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a todos'),
        content: Text(
          'Se abrirá el menú de compartir uno por uno (${active.length}). '
          'Elige WhatsApp en cada envío para mandar QR + mensaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    for (final g in active) {
      await _enviarInvitacion(g, wedding, origin);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Widget _templateCard(Wedding w) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _templateExpanded,
        onExpansionChanged: (v) => setState(() => _templateExpanded = v),
        leading: const Icon(Icons.chat_outlined, color: OlivoColors.olive),
        title: const Text('Plantilla del mensaje'),
        subtitle: const Text(
          'Se envía junto con la imagen QR al pulsar Enviar invitación',
          style: TextStyle(fontSize: 12, color: OlivoColors.muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Placeholders: {nombre} {novios} {fecha} {hora} {lugar} '
              '{direccion} {enlace} {cupo}',
              style: TextStyle(color: OlivoColors.muted, fontSize: 12),
            ),
          ),
          const FormGap(),
          TextField(
            controller: _tpl,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              alignLabelWithHint: true,
            ),
          ),
          const FormGap(),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _savingTpl ? null : () => _saveTemplate(w),
              child: Text(_savingTpl ? 'Guardando…' : 'Guardar plantilla'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(guestsProvider);
    final originAsync = ref.watch(publicBaseUrlProvider);
    final weddingAsync = ref.watch(weddingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitados'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar con Railway',
            onPressed: () async {
              final auth = ref.read(authProvider).user;
              if (auth == null) return;
              final ok = await ref.read(olivoRepoProvider).syncToServer(
                    auth.userId,
                    email: auth.email,
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Invitados sincronizados — los QR ya abren en cualquier teléfono'
                        : 'Sync falló. Guarda la URL pública en Cuenta.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
          weddingAsync.maybeWhen(
            data: (w) => w == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Enviar a todos',
                    onPressed: _sending
                        ? null
                        : () {
                            final guests = guestsAsync.valueOrNull ?? [];
                            final origin = originAsync.valueOrNull ??
                                'http://localhost:8080';
                            _bulkEnviar(guests, w, origin);
                          },
                    icon: const Icon(Icons.campaign_outlined),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Agregar',
            onPressed: () => _showGuestForm(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: guestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (guests) {
          final origin = originAsync.valueOrNull ?? 'http://localhost:8080';
          final wedding = weddingAsync.valueOrNull;
          if (wedding != null && !_hydrated) {
            _tpl.text = wedding.whatsappTemplate.isEmpty
                ? defaultTemplate
                : wedding.whatsappTemplate;
            _hydrated = true;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (wedding != null) ...[
                _templateCard(wedding),
                const SizedBox(height: 12),
              ],
              if (guests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Sin invitados aún')),
                )
              else
                ...guests.map((g) {
                  final badges = <String>[];
                  if (g.rsvp == 'yes') badges.add('RSVP sí');
                  if (g.rsvp == 'no') badges.add('RSVP no');
                  if (g.sentAt != null) badges.add('enviado');
                  if (g.firstViewedAt != null) badges.add('visto');
                  if (g.checkedInCount > 0) {
                    badges.add(
                      g.isQuotaFull
                          ? 'cupo completo'
                          : 'entrada ${g.checkedInCount}/${g.partySize}',
                    );
                  }
                  if (g.isCloned) badges.add('clon');
                  if (g.isDiscarded) badges.add('descartado');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text(g.name),
                        subtitle: Text(
                          [
                            if (g.groupName.isNotEmpty) g.groupName,
                            'cupo x${g.partySize}',
                            if (g.phone.isNotEmpty) g.phone,
                            if (badges.isNotEmpty) badges.join(' · '),
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: OlivoColors.muted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (wedding != null && !g.isDiscarded)
                              IconButton(
                                tooltip: 'Enviar invitación',
                                onPressed: _sending
                                    ? null
                                    : () => _enviarInvitacion(
                                          g,
                                          wedding,
                                          origin,
                                        ),
                                icon: const Icon(
                                  Icons.send_outlined,
                                  color: OlivoColors.olive,
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                final auth = ref.read(authProvider).user!;
                                final repo = ref.read(olivoRepoProvider);
                                switch (v) {
                                  case 'edit':
                                    await _showGuestForm(guest: g);
                                  case 'send':
                                    if (wedding != null) {
                                      await _enviarInvitacion(
                                        g,
                                        wedding,
                                        origin,
                                      );
                                    }
                                  case 'checkin':
                                    await repo.markAttendance(
                                      auth.userId,
                                      g.id,
                                    );
                                    ref.invalidate(guestsProvider);
                                    ref.invalidate(statsProvider);
                                  case 'regen':
                                    await repo.regenerateToken(
                                      auth.userId,
                                      g.id,
                                    );
                                    ref.invalidate(guestsProvider);
                                  case 'discard':
                                    await repo.discardGuest(auth.userId, g.id);
                                    ref.invalidate(guestsProvider);
                                    ref.invalidate(statsProvider);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                if (wedding != null && !g.isDiscarded)
                                  const PopupMenuItem(
                                    value: 'send',
                                    child: Text('Enviar invitación'),
                                  ),
                                const PopupMenuItem(
                                  value: 'checkin',
                                  child: Text('Registrar entrada (+1 cupo)'),
                                ),
                                const PopupMenuItem(
                                  value: 'regen',
                                  child: Text('Regenerar token'),
                                ),
                                const PopupMenuItem(
                                  value: 'discard',
                                  child: Text('Descartar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _previewGuest(g, wedding, origin),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
