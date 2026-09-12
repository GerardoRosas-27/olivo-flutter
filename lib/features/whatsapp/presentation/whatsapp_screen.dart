import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_gap.dart';
import '../../../core/utils/message.dart';

class WhatsappScreen extends ConsumerStatefulWidget {
  const WhatsappScreen({super.key});

  @override
  ConsumerState<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends ConsumerState<WhatsappScreen> {
  final _tpl = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _tpl.dispose();
    super.dispose();
  }

  Future<void> _save(Wedding w) async {
    final auth = ref.read(authProvider).user;
    if (auth == null) return;
    setState(() => _saving = true);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingProvider);
    final guestsAsync = ref.watch(guestsProvider);
    final originAsync = ref.watch(publicBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp'),
        actions: [
          weddingAsync.maybeWhen(
            data: (w) => w == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: _saving ? null : () => _save(w),
                    child: const Text('Guardar'),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: weddingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (w) {
          if (w == null) return const SizedBox.shrink();
          if (!_hydrated) {
            _tpl.text = w.whatsappTemplate.isEmpty ? defaultTemplate : w.whatsappTemplate;
            _hydrated = true;
          }
          final guests = guestsAsync.valueOrNull ?? [];
          final origin = originAsync.valueOrNull ?? 'http://localhost:8080';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Placeholders: {nombre} {novios} {fecha} {lugar} {enlace}',
                style: TextStyle(color: OlivoColors.muted, fontSize: 12),
              ),
              const FormGap(),
              TextField(
                controller: _tpl,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Plantilla del mensaje',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              Text('Enviar a invitados', style: Theme.of(context).textTheme.titleMedium),
              const FormGap(),
              ...guests.where((g) => !g.isDiscarded).map((g) {
                final msg = buildGuestMessage(
                  w.copyWith(whatsappTemplate: _tpl.text),
                  g,
                  origin,
                );
                final canWa = g.phone.trim().isNotEmpty;
                return Card(
                  child: ListTile(
                    title: Text(g.name),
                    subtitle: Text(
                      g.phone.isEmpty ? 'Sin teléfono' : g.phone,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: 'Abrir WhatsApp',
                      onPressed: !canWa
                          ? null
                          : () async {
                              final href = whatsappHref(g.phone, msg);
                              await launchUrl(Uri.parse(href),
                                  mode: LaunchMode.externalApplication);
                              final auth = ref.read(authProvider).user!;
                              await ref
                                  .read(olivoRepoProvider)
                                  .markGuestsSent(auth.userId, [g.id]);
                              ref.invalidate(guestsProvider);
                              ref.invalidate(statsProvider);
                            },
                      icon: const Icon(Icons.chat, color: OlivoColors.olive),
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
