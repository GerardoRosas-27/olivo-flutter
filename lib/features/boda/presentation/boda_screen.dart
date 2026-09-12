import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

class BodaScreen extends ConsumerStatefulWidget {
  const BodaScreen({super.key});

  @override
  ConsumerState<BodaScreen> createState() => _BodaScreenState();
}

class _BodaScreenState extends ConsumerState<BodaScreen> {
  final _c = <String, TextEditingController>{};
  List<ScheduleItem> _schedule = [];
  bool _loaded = false;
  bool _saving = false;

  TextEditingController _f(String key, [String initial = '']) {
    return _c.putIfAbsent(key, () => TextEditingController(text: initial));
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(Wedding w) {
    if (_loaded) return;
    _f('partnerOne', w.partnerOne);
    _f('partnerTwo', w.partnerTwo);
    _f('weddingDate', w.weddingDate ?? '');
    _f('weddingTime', w.weddingTime);
    _f('venueName', w.venueName);
    _f('venueAddress', w.venueAddress);
    _f('venueMapsUrl', w.venueMapsUrl);
    _f('dressCode', w.dressCode);
    _f('story', w.story);
    _f('welcomeNote', w.welcomeNote);
    _f('rsvpDeadline', w.rsvpDeadline ?? '');
    _schedule = List.of(w.schedule);
    _loaded = true;
  }

  Future<void> _save(Wedding current) async {
    final auth = ref.read(authProvider).user;
    if (auth == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(olivoRepoProvider).saveWedding(
            auth.userId,
            current.copyWith(
              partnerOne: _f('partnerOne').text,
              partnerTwo: _f('partnerTwo').text,
              weddingDate: _f('weddingDate').text.isEmpty
                  ? null
                  : _f('weddingDate').text,
              weddingTime: _f('weddingTime').text,
              venueName: _f('venueName').text,
              venueAddress: _f('venueAddress').text,
              venueMapsUrl: _f('venueMapsUrl').text,
              dressCode: _f('dressCode').text,
              story: _f('story').text,
              welcomeNote: _f('welcomeNote').text,
              schedule: _schedule,
              rsvpDeadline: _f('rsvpDeadline').text.isEmpty
                  ? null
                  : _f('rsvpDeadline').text,
              whatsappTemplate: current.whatsappTemplate,
            ),
          );
      ref.invalidate(weddingProvider);
      ref.invalidate(statsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boda guardada')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(weddingProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boda'),
        actions: [
          weddingAsync.maybeWhen(
            data: (w) => w == null
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: _saving ? null : () => _save(w),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
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
          _hydrate(w);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _f('partnerOne'),
                      decoration: const InputDecoration(labelText: 'Novio/a 1'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _f('partnerTwo'),
                      decoration: const InputDecoration(labelText: 'Novio/a 2'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _f('weddingDate'),
                      decoration: const InputDecoration(
                        labelText: 'Fecha (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _f('weddingTime'),
                      decoration: const InputDecoration(labelText: 'Hora'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('venueName'),
                decoration: const InputDecoration(labelText: 'Lugar'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('venueAddress'),
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('venueMapsUrl'),
                decoration: const InputDecoration(labelText: 'URL de mapas'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('dressCode'),
                decoration: const InputDecoration(labelText: 'Código de vestimenta'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('welcomeNote'),
                decoration: const InputDecoration(labelText: 'Nota de bienvenida'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('story'),
                decoration: const InputDecoration(labelText: 'Historia de los novios'),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _f('rsvpDeadline'),
                decoration: const InputDecoration(
                  labelText: 'Límite RSVP (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('Itinerario',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _schedule = [
                          ..._schedule,
                          const ScheduleItem(time: '', title: '', detail: ''),
                        ];
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              ...List.generate(_schedule.length, (i) {
                final item = _schedule[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: item.time,
                                decoration:
                                    const InputDecoration(labelText: 'Hora'),
                                onChanged: (v) {
                                  _schedule[i] = ScheduleItem(
                                    time: v,
                                    title: _schedule[i].title,
                                    detail: _schedule[i].detail,
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _schedule = [..._schedule]..removeAt(i);
                              }),
                              icon: const Icon(Icons.delete_outline,
                                  color: OlivoColors.danger),
                            ),
                          ],
                        ),
                        TextFormField(
                          initialValue: item.title,
                          decoration: const InputDecoration(labelText: 'Título'),
                          onChanged: (v) {
                            _schedule[i] = ScheduleItem(
                              time: _schedule[i].time,
                              title: v,
                              detail: _schedule[i].detail,
                            );
                          },
                        ),
                        TextFormField(
                          initialValue: item.detail,
                          decoration: const InputDecoration(labelText: 'Detalle'),
                          onChanged: (v) {
                            _schedule[i] = ScheduleItem(
                              time: _schedule[i].time,
                              title: _schedule[i].title,
                              detail: v,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
