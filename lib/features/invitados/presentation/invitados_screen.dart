import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/message.dart';
import '../../../core/widgets/form_gap.dart';

class InvitadosScreen extends ConsumerStatefulWidget {
  const InvitadosScreen({super.key});

  @override
  ConsumerState<InvitadosScreen> createState() => _InvitadosScreenState();
}

class _InvitadosScreenState extends ConsumerState<InvitadosScreen> {
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
                    decoration: const InputDecoration(labelText: 'Nombre')),
                const FormGap(),
                TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Teléfono')),
                const FormGap(),
                TextField(
                  controller: party,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Aforo / party size'),
                ),
                const FormGap(),
                TextField(
                    controller: group,
                    decoration: const InputDecoration(labelText: 'Grupo')),
                const FormGap(),
                TextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Notas')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final auth = ref.read(authProvider).user!;
    final repo = ref.read(olivoRepoProvider);
    final size = int.tryParse(party.text) ?? 1;
    if (guest == null) {
      await repo.addGuest(
        auth.userId,
        name: name.text,
        phone: phone.text,
        partySize: size,
        groupName: group.text,
        notes: notes.text,
      );
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
    }
    ref.invalidate(guestsProvider);
    ref.invalidate(statsProvider);
  }

  Future<void> _showQr(Guest guest, String origin) async {
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
                  width: 220,
                  height: 220,
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
            },
            child: const Text('Copiar enlace'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(guestsProvider);
    final originAsync = ref.watch(publicBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitados'),
        actions: [
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
          if (guests.isEmpty) {
            return const Center(child: Text('Sin invitados aún'));
          }
          final origin = originAsync.valueOrNull ?? 'http://localhost:8080';
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: guests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final g = guests[i];
              final badges = <String>[];
              if (g.rsvp == 'yes') badges.add('RSVP sí');
              if (g.rsvp == 'no') badges.add('RSVP no');
              if (g.sentAt != null) badges.add('enviado');
              if (g.firstViewedAt != null) badges.add('visto');
              if (g.isCheckedIn) badges.add('entrada');
              if (g.isCloned) badges.add('clon');
              if (g.isDiscarded) badges.add('descartado');

              return Card(
                child: ListTile(
                  title: Text(g.name),
                  subtitle: Text(
                    [
                      if (g.groupName.isNotEmpty) g.groupName,
                      'x${g.partySize}',
                      if (badges.isNotEmpty) badges.join(' · '),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: OlivoColors.muted),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      final auth = ref.read(authProvider).user!;
                      final repo = ref.read(olivoRepoProvider);
                      switch (v) {
                        case 'edit':
                          await _showGuestForm(guest: g);
                        case 'qr':
                          await _showQr(g, origin);
                        case 'sent':
                          await repo.markGuestsSent(auth.userId, [g.id]);
                          ref.invalidate(guestsProvider);
                          ref.invalidate(statsProvider);
                        case 'checkin':
                          await repo.markAttendance(auth.userId, g.id);
                          ref.invalidate(guestsProvider);
                          ref.invalidate(statsProvider);
                        case 'regen':
                          await repo.regenerateToken(auth.userId, g.id);
                          ref.invalidate(guestsProvider);
                        case 'discard':
                          await repo.discardGuest(auth.userId, g.id);
                          ref.invalidate(guestsProvider);
                          ref.invalidate(statsProvider);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'qr', child: Text('QR / enlace')),
                      PopupMenuItem(value: 'sent', child: Text('Marcar enviado')),
                      PopupMenuItem(
                          value: 'checkin', child: Text('Marcar entrada')),
                      PopupMenuItem(
                          value: 'regen', child: Text('Regenerar token')),
                      PopupMenuItem(value: 'discard', child: Text('Descartar')),
                    ],
                  ),
                  onTap: () => _showQr(g, origin),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
